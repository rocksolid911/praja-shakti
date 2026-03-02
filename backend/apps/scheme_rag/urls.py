from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'schemes', views.SchemeViewSet, basename='scheme')

urlpatterns = [
    path('', include(router.urls)),
]
