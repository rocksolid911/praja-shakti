from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer
from .models import Report, Vote, ReportCluster, GramSabhaSession, GramSabhaIssue


class ReportSerializer(serializers.ModelSerializer):
    reporter_name = serializers.CharField(source='reporter.get_full_name', read_only=True, default='Anonymous')
    village_name = serializers.CharField(source='village.name', read_only=True)
    has_voted = serializers.SerializerMethodField()
    location = serializers.SerializerMethodField()

    class Meta:
        model = Report
        fields = [
            'id', 'reporter', 'reporter_name', 'village', 'village_name',
            'category', 'sub_category', 'description_text', 'description_hindi',
            'audio_s3_key', 'photo_s3_key', 'location', 'ward', 'urgency',
            'status', 'vote_count', 'cluster', 'ai_confidence',
            'is_gram_sabha', 'created_at', 'updated_at', 'has_voted',
        ]
        read_only_fields = ['id', 'reporter', 'vote_count', 'cluster',
                           'ai_confidence', 'status', 'created_at', 'updated_at']

    def get_has_voted(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.votes.filter(voter=request.user).exists()
        return False

    def get_location(self, obj):
        if obj.location:
            return {'type': 'Point', 'coordinates': [obj.location.x, obj.location.y]}
        return None


class ReportCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Report
        fields = [
            'village', 'category', 'sub_category', 'description_text',
            'description_hindi', 'audio_s3_key', 'photo_s3_key',
            'location', 'ward', 'is_gram_sabha',
        ]

    def create(self, validated_data):
        validated_data['reporter'] = self.context['request'].user
        return super().create(validated_data)


class ReportClusterSerializer(serializers.ModelSerializer):
    village_name = serializers.CharField(source='village.name', read_only=True)
    centroid_geojson = serializers.SerializerMethodField()
    priority_score = serializers.FloatField(source='community_priority_score', read_only=True)

    class Meta:
        model = ReportCluster
        fields = [
            'id', 'village', 'village_name', 'category', 'centroid_geojson',
            'radius_km', 'report_count', 'ward_count', 'upvote_count',
            'estimated_households', 'community_priority_score', 'priority_score',
            'created_at', 'updated_at',
        ]

    def get_centroid_geojson(self, obj):
        if obj.centroid:
            return {'type': 'Point', 'coordinates': [obj.centroid.x, obj.centroid.y]}
        return None


class ReportClusterGeoSerializer(serializers.ModelSerializer):
    """GeoJSON-compatible cluster serializer."""
    type = serializers.SerializerMethodField()
    geometry = serializers.SerializerMethodField()
    properties = serializers.SerializerMethodField()

    class Meta:
        model = ReportCluster
        fields = ['type', 'geometry', 'properties']

    def get_type(self, obj):
        return 'Feature'

    def get_geometry(self, obj):
        return {
            'type': 'Point',
            'coordinates': [obj.centroid.x, obj.centroid.y],
        }

    def get_properties(self, obj):
        return {
            'id': obj.id,
            'category': obj.category,
            'report_count': obj.report_count,
            'upvote_count': obj.upvote_count,
            'community_priority_score': obj.community_priority_score,
            'radius_km': obj.radius_km,
        }


class GramSabhaSessionSerializer(serializers.ModelSerializer):
    village_name = serializers.CharField(source='village.name', read_only=True)
    issue_count = serializers.IntegerField(source='issues.count', read_only=True)

    class Meta:
        model = GramSabhaSession
        fields = [
            'id', 'village', 'village_name', 'title', 'scheduled_at',
            'is_active', 'transcript', 'created_by', 'issue_count', 'created_at',
        ]
        read_only_fields = ['id', 'created_by', 'created_at']

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)


class GramSabhaIssueSerializer(serializers.ModelSerializer):
    class Meta:
        model = GramSabhaIssue
        fields = ['id', 'session', 'report', 'title', 'vote_count']
        read_only_fields = ['id', 'vote_count']
