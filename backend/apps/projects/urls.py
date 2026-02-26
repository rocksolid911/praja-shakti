from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'projects', views.ProjectViewSet, basename='project')

urlpatterns = [
    # Custom paths must come BEFORE the router so they aren't swallowed by <pk> patterns
    path('projects/adopt/', views.adopt_project, name='project-adopt'),
    path('dashboard/summary/', views.dashboard_summary, name='dashboard-summary'),
    path('dashboard/fund-status/', views.dashboard_fund_status, name='dashboard-fund-status'),
    path('', include(router.urls)),
]
