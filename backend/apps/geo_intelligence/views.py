import logging
import requests
from django.conf import settings
from django.core.cache import cache
from django.http import HttpResponse
from rest_framework import viewsets, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import State, District, Block, Panchayat, Village, Infrastructure
from .serializers import (
    VillageSerializer, VillageGeoJSONSerializer, PanchayatSerializer,
    InfrastructureSerializer, InfrastructureGeoJSONSerializer,
)
from apps.community.models import Report, ReportCluster
from apps.projects.models import Project

logger = logging.getLogger(__name__)


class VillageViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = VillageSerializer
    filterset_fields = ['panchayat', 'panchayat__block', 'panchayat__block__district']
    search_fields = ['name', 'lgd_code']

    def get_queryset(self):
        return Village.objects.select_related(
            'panchayat__block__district__state'
        )


class PanchayatViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = PanchayatSerializer
    filterset_fields = ['block', 'block__district']
    search_fields = ['name', 'lgd_code']

    def get_queryset(self):
        return Panchayat.objects.select_related('block__district__state')


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def map_layers(request):
    """Returns GeoJSON FeatureCollections for each requested layer."""
    village_id = request.query_params.get('village')
    layers = request.query_params.get('layers', 'reports,satellite,infra,heatmap,projects').split(',')

    if not village_id:
        return Response({'error': 'village parameter required'}, status=400)

    result = {}

    if 'reports' in layers:
        reports = Report.objects.filter(village_id=village_id, location__isnull=False)
        features = []
        for r in reports:
            features.append({
                'type': 'Feature',
                'geometry': {'type': 'Point', 'coordinates': [r.location.x, r.location.y]},
                'properties': {
                    'id': r.id, 'category': r.category, 'status': r.status,
                    'urgency': r.urgency, 'vote_count': r.vote_count,
                    'description': r.description_text[:100],
                },
            })
        result['reports'] = {'type': 'FeatureCollection', 'features': features}

    if 'infra' in layers:
        infra = Infrastructure.objects.filter(village_id=village_id)
        features = InfrastructureGeoJSONSerializer(infra, many=True).data
        result['infrastructure'] = {'type': 'FeatureCollection', 'features': features}

    if 'projects' in layers:
        projects = Project.objects.filter(village_id=village_id, location__isnull=False)
        features = []
        for p in projects:
            features.append({
                'type': 'Feature',
                'geometry': {'type': 'Point', 'coordinates': [p.location.x, p.location.y]},
                'properties': {
                    'id': p.id, 'title': p.title, 'status': p.status,
                    'category': p.category, 'estimated_cost_inr': p.estimated_cost_inr,
                },
            })
        result['projects'] = {'type': 'FeatureCollection', 'features': features}

    if 'heatmap' in layers:
        # Gap analysis: areas with high population but low infrastructure
        village = Village.objects.get(id=village_id)
        clusters = ReportCluster.objects.filter(village_id=village_id)
        features = []
        for c in clusters:
            features.append({
                'type': 'Feature',
                'geometry': {'type': 'Point', 'coordinates': [c.centroid.x, c.centroid.y]},
                'properties': {
                    'weight': c.community_priority_score or 0,
                    'category': c.category,
                    'report_count': c.report_count,
                },
            })
        result['heatmap'] = {'type': 'FeatureCollection', 'features': features}

    if 'satellite' in layers:
        village = Village.objects.get(id=village_id)
        result['satellite'] = {
            'ndvi_score': village.ndvi_score,
            'ndvi_updated_at': str(village.ndvi_updated_at) if village.ndvi_updated_at else None,
            'tile_url': f'/api/v1/map/tiles/{{z}}/{{x}}/{{y}}.png?village={village_id}&type=ndvi',
        }

    if 'demographics' in layers:
        village = Village.objects.get(id=village_id)
        result['demographics'] = {
            'population': village.population,
            'households': village.households,
            'agricultural_households': village.agricultural_households,
            'groundwater_depth_m': village.groundwater_depth_m,
        }

    if 'fund_status' in layers:
        try:
            panchayat = Village.objects.get(id=village_id).panchayat
            result['fund_status'] = {
                'fund_available_inr': panchayat.fund_available_inr,
                'panchayat_name': panchayat.name,
            }
        except Village.DoesNotExist:
            result['fund_status'] = {}

    return Response(result)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def tile_proxy(request, z, x, y):
    """Proxy to Bhuvan WMS with Redis caching."""
    village_id = request.query_params.get('village')
    tile_type = request.query_params.get('type', 'ndvi')

    cache_key = f'tile:{tile_type}:{z}:{x}:{y}:{village_id}'
    cached = cache.get(cache_key)
    if cached:
        return HttpResponse(cached, content_type='image/png')

    # Build Bhuvan WMS URL
    # Tile to bbox conversion for WMS
    import math
    n = 2 ** int(z)
    west = int(x) / n * 360.0 - 180.0
    north = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * int(y) / n))))
    east = (int(x) + 1) / n * 360.0 - 180.0
    south = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * (int(y) + 1) / n))))

    wms_url = (
        f'https://bhuvan-vec1.nrsc.gov.in/bhuvan/wms?'
        f'SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap'
        f'&LAYERS=lulc50k_1516'
        f'&BBOX={west},{south},{east},{north}'
        f'&WIDTH=256&HEIGHT=256&FORMAT=image/png'
        f'&SRS=EPSG:4326'
    )

    if settings.BHUVAN_TOKEN:
        wms_url += f'&token={settings.BHUVAN_TOKEN}'

    try:
        resp = requests.get(wms_url, timeout=10)
        if resp.status_code == 200:
            cache.set(cache_key, resp.content, 7 * 86400)  # 7 days TTL
            return HttpResponse(resp.content, content_type='image/png')
    except requests.RequestException as e:
        logger.warning(f"Bhuvan WMS request failed: {e}")

    # Return transparent 1x1 PNG as fallback
    return HttpResponse(
        b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06'
        b'\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05'
        b'\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82',
        content_type='image/png',
    )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def village_boundary(request, village_id):
    """Return village boundary as GeoJSON."""
    try:
        village = Village.objects.get(id=village_id)
    except Village.DoesNotExist:
        return Response({'error': 'Village not found'}, status=404)

    feature = {
        'type': 'Feature',
        'geometry': None,
        'properties': {
            'id': village.id,
            'name': village.name,
            'lgd_code': village.lgd_code,
        },
    }
    if village.boundary:
        feature['geometry'] = {
            'type': 'MultiPolygon',
            'coordinates': village.boundary.coords,
        }
    elif village.location:
        feature['geometry'] = {
            'type': 'Point',
            'coordinates': [village.location.x, village.location.y],
        }

    return Response(feature)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def infrastructure_bbox(request):
    """Get infrastructure within bounding box."""
    bbox = request.query_params.get('bbox')
    if not bbox:
        return Response({'error': 'bbox parameter required (minlng,minlat,maxlng,maxlat)'}, status=400)

    try:
        coords = [float(c) for c in bbox.split(',')]
        minlng, minlat, maxlng, maxlat = coords
    except (ValueError, IndexError):
        return Response({'error': 'Invalid bbox format'}, status=400)

    from django.contrib.gis.geos import Polygon
    bbox_poly = Polygon.from_bbox((minlng, minlat, maxlng, maxlat))

    infra = Infrastructure.objects.filter(location__within=bbox_poly)
    features = InfrastructureGeoJSONSerializer(infra, many=True).data
    return Response({
        'type': 'FeatureCollection',
        'features': features,
    })
