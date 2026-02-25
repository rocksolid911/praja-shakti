from django.contrib.gis import admin
from .models import Report, Vote, ReportCluster, GramSabhaSession, GramSabhaIssue


@admin.register(Report)
class ReportAdmin(admin.GISModelAdmin):
    list_display = ['id', 'category', 'village', 'status', 'vote_count', 'urgency', 'ai_confidence', 'created_at']
    list_filter = ['category', 'status', 'urgency', 'is_gram_sabha']
    search_fields = ['description_text', 'description_hindi']
    readonly_fields = ['vote_count', 'ai_confidence', 'embedding']


@admin.register(Vote)
class VoteAdmin(admin.ModelAdmin):
    list_display = ['report', 'voter', 'created_at']


@admin.register(ReportCluster)
class ReportClusterAdmin(admin.GISModelAdmin):
    list_display = ['id', 'category', 'village', 'report_count', 'upvote_count', 'community_priority_score']
    list_filter = ['category']


@admin.register(GramSabhaSession)
class GramSabhaSessionAdmin(admin.ModelAdmin):
    list_display = ['title', 'village', 'scheduled_at', 'is_active']
    list_filter = ['is_active']


@admin.register(GramSabhaIssue)
class GramSabhaIssueAdmin(admin.ModelAdmin):
    list_display = ['title', 'session', 'vote_count']
