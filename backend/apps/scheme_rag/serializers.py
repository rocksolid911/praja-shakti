from rest_framework import serializers
from .models import Scheme, SchemeChunk


class SchemeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Scheme
        fields = [
            'id', 'name', 'short_name', 'ministry', 'category',
            'description', 'max_subsidy_pct', 'is_active', 'last_updated',
        ]


class SchemeChunkSerializer(serializers.ModelSerializer):
    scheme_name = serializers.CharField(source='scheme.short_name', read_only=True)

    class Meta:
        model = SchemeChunk
        fields = ['id', 'scheme', 'scheme_name', 'chunk_index',
                  'section_header', 'chunk_type', 'content', 'token_count']
