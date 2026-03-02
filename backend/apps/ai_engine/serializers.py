from rest_framework import serializers
from .models import PriorityScore, AITask


class PriorityScoreSerializer(serializers.ModelSerializer):
    cluster_category = serializers.CharField(source='cluster.category', read_only=True)
    village_name = serializers.CharField(source='cluster.village.name', read_only=True)

    class Meta:
        model = PriorityScore
        fields = [
            'id', 'cluster', 'cluster_category', 'village_name',
            'community_score', 'data_score', 'urgency_score', 'total_score',
            'report_count_pts', 'geographic_spread_pts', 'upvote_pts',
            'gram_sabha_bonus', 'satellite_pts', 'data_gap_pts',
            'demographic_pts', 'economic_pts', 'seasonal_pts',
            'safety_pts', 'worsening_trend_pts', 'justification',
            'calculated_at',
        ]


class AITaskSerializer(serializers.ModelSerializer):
    class Meta:
        model = AITask
        fields = ['id', 'task_type', 'status', 'input_data', 'output_data',
                  'error', 'created_at', 'completed_at']
        read_only_fields = ['id', 'status', 'output_data', 'error',
                           'created_at', 'completed_at']


class TranscribeRequestSerializer(serializers.Serializer):
    audio_s3_key = serializers.CharField()
    report_id = serializers.IntegerField(required=False)


class SchemeQuerySerializer(serializers.Serializer):
    query = serializers.CharField()
    village_id = serializers.IntegerField()


class SchemeQueryResponseSerializer(serializers.Serializer):
    answer = serializers.CharField()
    sources = serializers.ListField()
