from rest_framework import serializers
from .models import Project, ProjectPhoto, ProjectRating
from apps.scheme_rag.models import FundConvergencePlan


class ProjectPhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProjectPhoto
        fields = ['id', 'project', 's3_key', 'caption', 'is_delay_report', 'created_at']
        read_only_fields = ['id', 'created_at']


class ProjectRatingSerializer(serializers.ModelSerializer):
    citizen_name = serializers.CharField(source='citizen.get_full_name', read_only=True, default='')

    class Meta:
        model = ProjectRating
        fields = ['id', 'project', 'citizen', 'citizen_name', 'rating', 'review', 'created_at']
        read_only_fields = ['id', 'citizen', 'created_at']


class FundConvergenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = FundConvergencePlan
        fields = ['id', 'total_cost_inr', 'panchayat_contribution_inr',
                  'savings_pct', 'schemes_used', 'generated_at']


class ProjectSerializer(serializers.ModelSerializer):
    village_name = serializers.CharField(source='village.name', read_only=True)
    photos = ProjectPhotoSerializer(many=True, read_only=True)
    ratings = ProjectRatingSerializer(many=True, read_only=True)
    fund_plans = FundConvergenceSerializer(source='fund_convergence_plans', many=True, read_only=True)
    adopted_by_name = serializers.CharField(
        source='adopted_by.get_full_name', read_only=True, default=None
    )

    class Meta:
        model = Project
        fields = [
            'id', 'cluster', 'village', 'village_name', 'adopted_by', 'adopted_by_name',
            'title', 'description', 'category', 'location', 'estimated_cost_inr',
            'beneficiary_count', 'impact_projection', 'priority_score', 'ai_confidence',
            'status', 'proposal_s3_key', 'mgnrega_request_s3_key',
            'scheme_application_s3_key', 'adopted_at', 'started_at',
            'expected_completion', 'completed_at', 'avg_citizen_rating',
            'created_at', 'photos', 'ratings', 'fund_plans',
        ]
        read_only_fields = ['id', 'created_at']


class ProjectAdoptSerializer(serializers.Serializer):
    cluster_id = serializers.IntegerField()
    recommendation_index = serializers.IntegerField(default=0)
