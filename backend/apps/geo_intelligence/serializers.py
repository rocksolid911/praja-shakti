from rest_framework import serializers
from .models import State, District, Block, Panchayat, Village, Infrastructure


class StateSerializer(serializers.ModelSerializer):
    class Meta:
        model = State
        fields = ['id', 'name', 'lgd_code']


class DistrictSerializer(serializers.ModelSerializer):
    state_name = serializers.CharField(source='state.name', read_only=True)

    class Meta:
        model = District
        fields = ['id', 'name', 'lgd_code', 'state', 'state_name']


class BlockSerializer(serializers.ModelSerializer):
    district_name = serializers.CharField(source='district.name', read_only=True)

    class Meta:
        model = Block
        fields = ['id', 'name', 'lgd_code', 'district', 'district_name']


class PanchayatSerializer(serializers.ModelSerializer):
    block_name = serializers.CharField(source='block.name', read_only=True)
    district_name = serializers.CharField(
        source='block.district.name', read_only=True)

    class Meta:
        model = Panchayat
        fields = [
            'id', 'name', 'lgd_code', 'block', 'block_name', 'district_name',
            'population', 'households', 'area_sq_km',
            'fund_available_inr', 'ward_count',
        ]


class VillageSerializer(serializers.ModelSerializer):
    panchayat_name = serializers.CharField(source='panchayat.name', read_only=True)
    district_name = serializers.SerializerMethodField()
    state_name = serializers.SerializerMethodField()
    location = serializers.SerializerMethodField()

    class Meta:
        model = Village
        fields = [
            'id', 'name', 'lgd_code', 'panchayat', 'panchayat_name',
            'district_name', 'state_name', 'location', 'population',
            'households', 'agricultural_households', 'groundwater_depth_m',
            'ndvi_score', 'ndvi_updated_at',
        ]

    def get_district_name(self, obj):
        return obj.panchayat.block.district.name

    def get_state_name(self, obj):
        return obj.panchayat.block.district.state.name

    def get_location(self, obj):
        if obj.location:
            return {'type': 'Point', 'coordinates': [obj.location.x, obj.location.y]}
        return None


class VillageGeoJSONSerializer(serializers.ModelSerializer):
    """GeoJSON Feature for a village."""
    type = serializers.SerializerMethodField()
    geometry = serializers.SerializerMethodField()
    properties = serializers.SerializerMethodField()

    class Meta:
        model = Village
        fields = ['type', 'geometry', 'properties']

    def get_type(self, obj):
        return 'Feature'

    def get_geometry(self, obj):
        if obj.location:
            return {'type': 'Point', 'coordinates': [obj.location.x, obj.location.y]}
        return None

    def get_properties(self, obj):
        return {
            'id': obj.id,
            'name': obj.name,
            'lgd_code': obj.lgd_code,
            'population': obj.population,
            'households': obj.households,
            'ndvi_score': obj.ndvi_score,
            'groundwater_depth_m': obj.groundwater_depth_m,
        }


class InfrastructureSerializer(serializers.ModelSerializer):
    village_name = serializers.CharField(source='village.name', read_only=True)

    class Meta:
        model = Infrastructure
        fields = [
            'id', 'village', 'village_name', 'infra_type', 'name',
            'location', 'osm_id', 'distance_from_center_km',
        ]


class InfrastructureGeoJSONSerializer(serializers.ModelSerializer):
    type = serializers.SerializerMethodField()
    geometry = serializers.SerializerMethodField()
    properties = serializers.SerializerMethodField()

    class Meta:
        model = Infrastructure
        fields = ['type', 'geometry', 'properties']

    def get_type(self, obj):
        return 'Feature'

    def get_geometry(self, obj):
        return {'type': 'Point', 'coordinates': [obj.location.x, obj.location.y]}

    def get_properties(self, obj):
        return {
            'id': obj.id,
            'infra_type': obj.infra_type,
            'name': obj.name,
            'distance_from_center_km': obj.distance_from_center_km,
        }
