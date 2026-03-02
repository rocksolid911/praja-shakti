from django.urls import path
from . import views

urlpatterns = [
    path('ai/transcribe/', views.transcribe, name='ai-transcribe'),
    path('ai/transcribe/<int:task_id>/', views.transcribe_status, name='ai-transcribe-status'),
    path('ai/priorities/', views.priorities, name='ai-priorities'),
    path('ai/recommendations/', views.recommendations, name='ai-recommendations'),
    path('ai/score/<int:cluster_id>/', views.score_detail, name='ai-score-detail'),
    path('ai/scheme-query/', views.scheme_query, name='ai-scheme-query'),
]
