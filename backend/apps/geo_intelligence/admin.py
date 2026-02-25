from django.contrib.gis import admin
from .models import State, District, Block, Panchayat, Village, Infrastructure


@admin.register(State)
class StateAdmin(admin.ModelAdmin):
    list_display = ['name', 'lgd_code']
    search_fields = ['name', 'lgd_code']


@admin.register(District)
class DistrictAdmin(admin.ModelAdmin):
    list_display = ['name', 'state', 'lgd_code']
    list_filter = ['state']
    search_fields = ['name', 'lgd_code']


@admin.register(Block)
class BlockAdmin(admin.ModelAdmin):
    list_display = ['name', 'district', 'lgd_code']
    list_filter = ['district__state']
    search_fields = ['name', 'lgd_code']


@admin.register(Panchayat)
class PanchayatAdmin(admin.GISModelAdmin):
    list_display = ['name', 'block', 'lgd_code', 'population', 'fund_available_inr']
    list_filter = ['block__district__state']
    search_fields = ['name', 'lgd_code']


@admin.register(Village)
class VillageAdmin(admin.GISModelAdmin):
    list_display = ['name', 'panchayat', 'lgd_code', 'population', 'ndvi_score', 'groundwater_depth_m']
    list_filter = ['panchayat__block__district__state']
    search_fields = ['name', 'lgd_code']


@admin.register(Infrastructure)
class InfrastructureAdmin(admin.GISModelAdmin):
    list_display = ['name', 'infra_type', 'village', 'distance_from_center_km']
    list_filter = ['infra_type']
    search_fields = ['name']
