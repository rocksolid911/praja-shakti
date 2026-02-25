from django.contrib.gis import admin
from .models import Project, ProjectPhoto, ProjectRating


@admin.register(Project)
class ProjectAdmin(admin.GISModelAdmin):
    list_display = ['title', 'village', 'category', 'status', 'estimated_cost_inr', 'priority_score', 'avg_citizen_rating']
    list_filter = ['status', 'category']
    search_fields = ['title', 'description']


@admin.register(ProjectPhoto)
class ProjectPhotoAdmin(admin.ModelAdmin):
    list_display = ['project', 'uploaded_by', 'is_delay_report', 'created_at']
    list_filter = ['is_delay_report']


@admin.register(ProjectRating)
class ProjectRatingAdmin(admin.ModelAdmin):
    list_display = ['project', 'citizen', 'rating', 'created_at']
