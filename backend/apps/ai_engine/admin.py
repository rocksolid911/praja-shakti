from django.contrib import admin
from .models import PriorityScore, AITask


@admin.register(PriorityScore)
class PriorityScoreAdmin(admin.ModelAdmin):
    list_display = ['cluster', 'total_score', 'community_score', 'data_score', 'urgency_score', 'calculated_at']
    ordering = ['-total_score']


@admin.register(AITask)
class AITaskAdmin(admin.ModelAdmin):
    list_display = ['task_type', 'status', 'created_at', 'completed_at']
    list_filter = ['task_type', 'status']
