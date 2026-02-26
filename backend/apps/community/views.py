from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.db.models import F

from .models import Report, Vote, ReportCluster, GramSabhaSession, GramSabhaIssue
from .serializers import (
    ReportSerializer, ReportCreateSerializer, ReportClusterSerializer,
    ReportClusterGeoSerializer, GramSabhaSessionSerializer, GramSabhaIssueSerializer,
)


class ReportViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    filterset_fields = ['village', 'category', 'status', 'ward']
    search_fields = ['description_text']
    ordering_fields = ['created_at', 'vote_count']

    def get_queryset(self):
        return Report.objects.select_related('reporter', 'village', 'cluster')

    def get_serializer_class(self):
        if self.action == 'create':
            return ReportCreateSerializer
        return ReportSerializer

    @action(detail=True, methods=['post'])
    def vote(self, request, pk=None):
        report = self.get_object()
        _, created = Vote.objects.get_or_create(report=report, voter=request.user)
        if created:
            Report.objects.filter(pk=report.pk).update(vote_count=F('vote_count') + 1)
            report.refresh_from_db()
            return Response({'vote_count': report.vote_count, 'voted': True})
        return Response({'vote_count': report.vote_count, 'voted': True})

    @vote.mapping.delete
    def unvote(self, request, pk=None):
        report = self.get_object()
        deleted, _ = Vote.objects.filter(report=report, voter=request.user).delete()
        if deleted:
            Report.objects.filter(pk=report.pk).update(vote_count=F('vote_count') - 1)
            report.refresh_from_db()
        return Response({'vote_count': report.vote_count, 'voted': False})

    @action(detail=False, methods=['get'])
    def clusters(self, request):
        village_id = request.query_params.get('village')
        if not village_id:
            return Response({'error': 'village parameter required'}, status=400)
        clusters = ReportCluster.objects.filter(village_id=village_id)
        data = ReportClusterGeoSerializer(clusters, many=True).data
        return Response({
            'type': 'FeatureCollection',
            'features': data,
        })

    @action(detail=True, methods=['get'])
    def score(self, request, pk=None):
        report = self.get_object()
        if report.cluster and hasattr(report.cluster, 'priority_score'):
            from apps.ai_engine.serializers import PriorityScoreSerializer
            return Response(PriorityScoreSerializer(report.cluster.priority_score).data)
        return Response({'error': 'No priority score available'}, status=404)


class ReportClusterViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ReportClusterSerializer
    filterset_fields = ['village', 'category']

    def get_queryset(self):
        return ReportCluster.objects.select_related('village')


class GramSabhaSessionViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = GramSabhaSessionSerializer
    filterset_fields = ['village', 'is_active']

    def get_queryset(self):
        return GramSabhaSession.objects.select_related('village', 'created_by')

    @action(detail=True, methods=['post'])
    def end(self, request, pk=None):
        session = self.get_object()
        session.is_active = False
        session.save()
        # Trigger AI summary generation (async)
        try:
            from apps.ai_engine.tasks import generate_gram_sabha_summary
            generate_gram_sabha_summary.delay(session.id)
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning(f"Could not queue Gram Sabha summary task: {e}")
        return Response({'status': 'session ended, summary generating...'})


class GramSabhaIssueViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = GramSabhaIssueSerializer
    filterset_fields = ['session']

    def get_queryset(self):
        return GramSabhaIssue.objects.select_related('session', 'report')

    @action(detail=True, methods=['post'])
    def vote(self, request, pk=None):
        issue = self.get_object()
        GramSabhaIssue.objects.filter(pk=issue.pk).update(vote_count=F('vote_count') + 1)
        issue.refresh_from_db()
        return Response({'vote_count': issue.vote_count})
