import logging
import requests
from django.conf import settings
from django.core.cache import cache
from django.http import HttpResponse
from rest_framework import viewsets, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response

from .models import State, District, Block, Panchayat, Village, Infrastructure
from .serializers import (
    StateSerializer, DistrictSerializer,
    VillageSerializer, VillageGeoJSONSerializer, PanchayatSerializer,
    InfrastructureSerializer, InfrastructureGeoJSONSerializer,
)
from apps.community.models import Report, ReportCluster
from apps.projects.models import Project

logger = logging.getLogger(__name__)


class StateViewSet(viewsets.ReadOnlyModelViewSet):
    """List all Indian states/UTs in the database."""
    permission_classes = [AllowAny]
    serializer_class = StateSerializer
    pagination_class = None  # return all states in a single call

    def get_queryset(self):
        return State.objects.all().order_by('name')


class DistrictViewSet(viewsets.ReadOnlyModelViewSet):
    """List districts, optionally filtered by ?state={id}."""
    permission_classes = [AllowAny]
    serializer_class = DistrictSerializer
    filterset_fields = ['state']
    search_fields = ['name']
    pagination_class = None

    def get_queryset(self):
        qs = District.objects.select_related('state').order_by('name')
        state_id = self.request.query_params.get('state')
        if state_id:
            qs = qs.filter(state_id=state_id)
        return qs


class VillageViewSet(viewsets.ReadOnlyModelViewSet):
    """
    List villages.
    Supports ?district={id} for dropdown cascade (resolves via block/panchayat).
    Also supports legacy ?panchayat__block__district={id} filter.
    """
    permission_classes = [AllowAny]
    serializer_class = VillageSerializer
    filterset_fields = ['panchayat', 'panchayat__block', 'panchayat__block__district']
    search_fields = ['name', 'lgd_code']
    pagination_class = None  # return all villages for the district in one call

    def get_queryset(self):
        qs = Village.objects.select_related('panchayat__block__district__state').order_by('name')
        district_id = self.request.query_params.get('district')
        if district_id:
            qs = qs.filter(panchayat__block__district_id=district_id)
        return qs


class PanchayatViewSet(viewsets.ReadOnlyModelViewSet):
    """
    List panchayats (Gram Panchayats).
    Supports:
      ?district={id}  — filter by district (resolves via block → district)
      ?village={id}   — return the single panchayat for that village
    Returns all results with no pagination (usable as dropdown source).
    """
    permission_classes = [AllowAny]
    serializer_class = PanchayatSerializer
    filterset_fields = ['block', 'block__district']
    search_fields = ['name', 'lgd_code']
    pagination_class = None

    def get_queryset(self):
        qs = Panchayat.objects.select_related('block__district__state').order_by('name')
        district_id = self.request.query_params.get('district')
        if district_id:
            qs = qs.filter(block__district_id=district_id)
        village_id = self.request.query_params.get('village')
        if village_id:
            qs = qs.filter(villages__id=village_id)
        return qs


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
@permission_classes([])  # Public — tiles are not sensitive, browser can't send JWT in tile requests
def tile_proxy(request, z, x, y):
    """Proxy to Bhuvan WMS with Redis caching."""
    village_id = request.query_params.get('village')
    tile_type = request.query_params.get('type', 'ndvi')

    cache_key = f'tile:{tile_type}:{z}:{x}:{y}:{village_id}'
    try:
        cached = cache.get(cache_key)
        if cached:
            return HttpResponse(cached, content_type='image/png')
    except Exception:
        pass  # Redis not available — proceed without cache

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
            try:
                cache.set(cache_key, resp.content, 7 * 86400)  # 7 days TTL
            except Exception:
                pass  # Redis not available — skip caching
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


@api_view(['POST'])
@permission_classes([AllowAny])
def setup_location(request):
    """
    Find or create the Block → Panchayat → Village chain for any district.

    Allows users to add their village even if it isn't pre-loaded in the database.
    Idempotent: repeated calls with the same names return the same objects.

    Body: {district_id, panchayat_name, village_name}
    Returns: {village_id, village_name, panchayat_id, panchayat_name, district_name, state_name, is_new}
    """
    import random
    district_id = request.data.get('district_id')
    panchayat_name = (request.data.get('panchayat_name') or '').strip()
    village_name = (request.data.get('village_name') or '').strip()

    if not all([district_id, panchayat_name, village_name]):
        return Response(
            {'error': 'district_id, panchayat_name, and village_name are required'},
            status=400,
        )

    try:
        district = District.objects.select_related('state').get(id=district_id)
    except District.DoesNotExist:
        return Response({'error': 'District not found'}, status=404)

    # ── 1. Find or create a Block for this district ──────────────────────────
    # Use short codes (≤10 chars) — LGD max_length is 10
    def _unique_lgd(prefix, model_class):
        """Generate a unique LGD code: single letter + 9 random digits = 10 chars max."""
        for _ in range(100):
            code = f'{prefix}{random.randint(100000000, 999999999)}'
            if not model_class.objects.filter(lgd_code=code).exists():
                return code
        raise RuntimeError(f'Could not generate unique LGD code for prefix {prefix}')

    block = Block.objects.filter(district=district).first()
    if not block:
        block = Block.objects.create(
            district=district,
            name=f'{district.name} Block',
            lgd_code=_unique_lgd('B', Block),
        )

    # ── 2. Find or create Panchayat by name in this district ─────────────────
    panchayat = (
        Panchayat.objects.filter(block__district=district, name__iexact=panchayat_name).first()
    )
    is_new = panchayat is None
    if not panchayat:
        panchayat = Panchayat.objects.create(
            block=block,
            name=panchayat_name,
            lgd_code=_unique_lgd('G', Panchayat),
            ward_count=9,
        )

    # ── 3. Find or create Village by name in this panchayat ──────────────────
    village = Village.objects.filter(panchayat=panchayat, name__iexact=village_name).first()
    if not village:
        is_new = True
        village = Village.objects.create(
            panchayat=panchayat,
            name=village_name,
            lgd_code=_unique_lgd('V', Village),
        )

    # ── 4. Update requesting user's panchayat (if authenticated) ────────────
    if request.user.is_authenticated:
        user = request.user
        if user.panchayat_id != panchayat.id:
            user.panchayat = panchayat
            if not user.ward:
                user.ward = 1
            user.save(update_fields=['panchayat', 'ward'])

    return Response({
        'village_id': village.id,
        'village_name': village.name,
        'panchayat_id': panchayat.id,
        'panchayat_name': panchayat.name,
        'district_id': district.id,
        'district_name': district.name,
        'state_name': district.state.name,
        'ward_count': panchayat.ward_count,
        'fund_available_inr': panchayat.fund_available_inr,
        'is_new': is_new,
        'provisioning': True,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def provision_village(request):
    """
    Trigger background data provisioning for a village.

    Called after a citizen selects their village in the report screen.
    Ensures district scheme stats and panchayat fund data are present.
    Also updates the requesting user's panchayat to the selected village.

    Body: {"village_id": 42}
    Returns: {village_id, village_name, panchayat_id, district_stats_ready, fund_available_inr}
    """
    village_id = request.data.get('village_id')
    if not village_id:
        return Response({'error': 'village_id required'}, status=400)

    try:
        village = Village.objects.select_related(
            'panchayat__block__district__state'
        ).get(id=village_id)
    except Village.DoesNotExist:
        return Response({'error': 'Village not found'}, status=404)

    panchayat = village.panchayat
    district = panchayat.block.district

    # Update requesting user's panchayat if not already set (or if changed)
    user = request.user
    if user.panchayat_id != panchayat.id:
        user.panchayat = panchayat
        if not user.ward:
            user.ward = 1
        user.save(update_fields=['panchayat', 'ward'])

    # Ensure district stats and fund data exist synchronously (seed estimates if missing).
    # This guarantees provisioning=false in the response so the frontend never shows
    # a permanent "Loading..." spinner.
    from apps.data_ingestion.models import DistrictSchemeStats
    from apps.data_ingestion.tasks import _seed_district_stats_estimate, _seed_panchayat_fund_estimate

    if not DistrictSchemeStats.objects.filter(district_lgd=district.lgd_code).exists():
        logger.info(f"provision_village: seeding estimates for district {district.name}")
        try:
            _seed_district_stats_estimate(district)
        except Exception as e:
            logger.warning(f"provision_village: estimate seed failed: {e}")

    # Re-fetch panchayat to pick up any fund updates
    panchayat.refresh_from_db()
    if panchayat.fund_available_inr == 0:
        try:
            _seed_panchayat_fund_estimate(panchayat)
            panchayat.refresh_from_db()
        except Exception as e:
            logger.warning(f"provision_village: fund seed failed: {e}")

    # Trigger background task to fetch real API data (replaces estimates later)
    from apps.utils import dispatch_task
    from apps.data_ingestion.tasks import provision_village_data, _run_provision_village
    dispatch_task(provision_village_data, village_id, fallback=_run_provision_village)

    return Response({
        'village_id': village.id,
        'village_name': village.name,
        'panchayat_id': panchayat.id,
        'panchayat_name': panchayat.name,
        'district_id': district.id,
        'district_name': district.name,
        'state_name': district.state.name,
        'district_stats_ready': True,
        'fund_available_inr': panchayat.fund_available_inr,
        'ward_count': panchayat.ward_count,
        'population': village.population,
        'households': village.households,
        'ndvi_score': village.ndvi_score,
        'groundwater_depth_m': village.groundwater_depth_m,
        'latitude': village.location.y if village.location else None,
        'longitude': village.location.x if village.location else None,
        'provisioning': False,
    })


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
