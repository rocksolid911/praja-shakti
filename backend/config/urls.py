from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/auth/', include('apps.auth_service.urls')),
    path('api/v1/', include('apps.community.urls')),
    path('api/v1/', include('apps.geo_intelligence.urls')),
    path('api/v1/', include('apps.scheme_rag.urls')),
    path('api/v1/', include('apps.ai_engine.urls')),
    path('api/v1/', include('apps.projects.urls')),
    path('api/v1/', include('apps.notifications.urls')),
]
