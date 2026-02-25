from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'villages', views.VillageViewSet, basename='village')
router.register(r'panchayats', views.PanchayatViewSet, basename='panchayat')

urlpatterns = [
    path('', include(router.urls)),
    path('map/layers/', views.map_layers, name='map-layers'),
    path('map/tiles/<int:z>/<int:x>/<int:y>.png', views.tile_proxy, name='map-tile-proxy'),
    path('map/village/<int:village_id>/boundary/', views.village_boundary, name='village-boundary'),
    path('map/infrastructure/', views.infrastructure_bbox, name='infra-bbox'),
]
