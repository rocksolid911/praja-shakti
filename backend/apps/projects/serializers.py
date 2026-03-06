import logging

from rest_framework import serializers
from .models import Project, ProjectPhoto, ProjectRating
from apps.scheme_rag.models import FundConvergencePlan

logger = logging.getLogger(__name__)


def _get_s3_presigned_url(bucket: str, key: str, expires: int = 3600) -> str | None:
    """Generate a presigned S3 URL. Returns None on failure."""
    if not key:
        return None
    if key.startswith('http'):
        return key
    try:
        import boto3
        from django.conf import settings
        s3 = boto3.client(
            's3',
            region_name=settings.AWS_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        )
        return s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket, 'Key': key},
            ExpiresIn=expires,
        )
    except Exception as e:
        logger.error(f"S3 presigned URL failed for {bucket}/{key}: {e}")
        return None


class ProjectPhotoSerializer(serializers.ModelSerializer):
    photo_url = serializers.SerializerMethodField()

    class Meta:
        model = ProjectPhoto
        fields = ['id', 'project', 's3_key', 'caption', 'is_delay_report', 'created_at', 'photo_url']
        read_only_fields = ['id', 'created_at', 'photo_url']

    def get_photo_url(self, obj):
        from django.conf import settings
        return _get_s3_presigned_url(settings.AWS_S3_CITIZEN_PHOTOS_BUCKET, obj.s3_key)


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
    proposal_download_url = serializers.SerializerMethodField()
    lat = serializers.SerializerMethodField()
    lng = serializers.SerializerMethodField()

    class Meta:
        model = Project
        fields = [
            'id', 'cluster', 'village', 'village_name', 'adopted_by', 'adopted_by_name',
            'title', 'description', 'category', 'location', 'lat', 'lng',
            'estimated_cost_inr', 'beneficiary_count', 'impact_projection',
            'priority_score', 'ai_confidence', 'status', 'proposal_s3_key',
            'proposal_download_url', 'mgnrega_request_s3_key',
            'scheme_application_s3_key', 'adopted_at', 'started_at',
            'expected_completion', 'completed_at', 'avg_citizen_rating',
            'created_at', 'photos', 'ratings', 'fund_plans',
        ]
        read_only_fields = ['id', 'created_at']

    def get_proposal_download_url(self, obj):
        if obj.proposal_s3_key:
            from django.conf import settings
            url = _get_s3_presigned_url(settings.AWS_S3_REPORTS_BUCKET, obj.proposal_s3_key)
            if url:
                return url
        return f'/api/v1/projects/{obj.id}/proposal/'

    def get_lat(self, obj):
        return obj.location.y if obj.location else None

    def get_lng(self, obj):
        return obj.location.x if obj.location else None


class ProjectAdoptSerializer(serializers.Serializer):
    cluster_id = serializers.IntegerField()
    recommendation_index = serializers.IntegerField(default=0)
