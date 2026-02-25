from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'reports', views.ReportViewSet, basename='report')
router.register(r'clusters', views.ReportClusterViewSet, basename='cluster')
router.register(r'gramsabha', views.GramSabhaSessionViewSet, basename='gramsabha')
router.register(r'gramsabha-issues', views.GramSabhaIssueViewSet, basename='gramsabha-issue')

urlpatterns = [
    path('', include(router.urls)),
]
