from django.utils import timezone
from django.db.models import Avg
from rest_framework import viewsets, status
from rest_framework.decorators import api_view, action, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.auth_service.permissions import IsLeader
from .models import Project, ProjectPhoto, ProjectRating
from .serializers import (
    ProjectSerializer, ProjectPhotoSerializer,
    ProjectRatingSerializer, ProjectAdoptSerializer,
)


class ProjectViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ProjectSerializer
    filterset_fields = ['village', 'status', 'category']

    def get_queryset(self):
        return Project.objects.select_related(
            'village', 'cluster', 'adopted_by'
        ).prefetch_related('photos', 'ratings', 'fund_convergence_plans')

    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        project = self.get_object()
        new_status = request.data.get('status')
        if new_status not in dict(Project.STATUS):
            return Response({'error': 'Invalid status'}, status=400)

        project.status = new_status
        if new_status == 'in_progress' and not project.started_at:
            project.started_at = timezone.now()
        elif new_status == 'completed':
            project.completed_at = timezone.now()
        project.save()
        return Response(ProjectSerializer(project).data)

    @action(detail=True, methods=['post'])
    def photos(self, request, pk=None):
        project = self.get_object()
        serializer = ProjectPhotoSerializer(data={
            'project': project.id,
            's3_key': request.data.get('s3_key', ''),
            'caption': request.data.get('caption', ''),
            'is_delay_report': request.data.get('is_delay_report', False),
        })
        serializer.is_valid(raise_exception=True)
        serializer.save(uploaded_by=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def rating(self, request, pk=None):
        project = self.get_object()
        rating_val = request.data.get('rating')
        review = request.data.get('review', '')

        if not rating_val or int(rating_val) not in range(1, 6):
            return Response({'error': 'Rating must be 1-5'}, status=400)

        obj, created = ProjectRating.objects.update_or_create(
            project=project, citizen=request.user,
            defaults={'rating': int(rating_val), 'review': review},
        )
        # Update average rating
        avg = project.ratings.aggregate(avg=Avg('rating'))['avg']
        project.avg_citizen_rating = avg
        project.save(update_fields=['avg_citizen_rating'])

        return Response(ProjectRatingSerializer(obj).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_summary(request):
    """Leader dashboard: top priorities + fund status + active projects."""
    panchayat_id = request.query_params.get('panchayat')
    if not panchayat_id:
        return Response({'error': 'panchayat parameter required'}, status=400)

    from apps.geo_intelligence.models import Village, Panchayat
    from apps.ai_engine.models import PriorityScore

    try:
        panchayat = Panchayat.objects.get(id=panchayat_id)
    except Panchayat.DoesNotExist:
        return Response({'error': 'Panchayat not found'}, status=404)

    villages = Village.objects.filter(panchayat=panchayat)
    village_ids = villages.values_list('id', flat=True)

    top_scores = PriorityScore.objects.filter(
        cluster__village_id__in=village_ids
    ).select_related('cluster__village').order_by('-total_score')[:5]

    from apps.ai_engine.serializers import PriorityScoreSerializer
    priorities_data = PriorityScoreSerializer(top_scores, many=True).data

    active_projects = Project.objects.filter(
        village_id__in=village_ids,
        status__in=['adopted', 'in_progress'],
    )

    total_reports = sum(v.reports.count() for v in villages)
    total_projects = Project.objects.filter(village_id__in=village_ids).count()
    completed = Project.objects.filter(village_id__in=village_ids, status='completed').count()

    return Response({
        'panchayat': {'id': panchayat.id, 'name': panchayat.name},
        'fund_available_inr': panchayat.fund_available_inr,
        'total_reports': total_reports,
        'total_projects': total_projects,
        'completed_projects': completed,
        'active_projects': ProjectSerializer(active_projects, many=True).data,
        'top_priorities': priorities_data,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_fund_status(request):
    panchayat_id = request.query_params.get('panchayat')
    if not panchayat_id:
        return Response({'error': 'panchayat parameter required'}, status=400)

    from apps.geo_intelligence.models import Panchayat
    from django.db.models import Sum

    try:
        panchayat = Panchayat.objects.get(id=panchayat_id)
    except Panchayat.DoesNotExist:
        return Response({'error': 'Panchayat not found'}, status=404)

    village_ids = panchayat.villages.values_list('id', flat=True)
    category_costs = Project.objects.filter(
        village_id__in=village_ids,
        status__in=['adopted', 'in_progress', 'completed'],
    ).values('category').annotate(total=Sum('estimated_cost_inr'))

    return Response({
        'fund_available_inr': panchayat.fund_available_inr,
        'fund_allocated_by_category': list(category_costs),
        'panchayat_name': panchayat.name,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsLeader])
def adopt_project(request):
    serializer = ProjectAdoptSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    cluster_id = serializer.validated_data['cluster_id']

    # Find existing recommended project for this cluster
    try:
        project = Project.objects.filter(
            cluster_id=cluster_id, status='recommended'
        ).first()
        if not project:
            return Response({'error': 'No recommendation found for this cluster'}, status=404)
    except Exception as e:
        return Response({'error': str(e)}, status=400)

    project.status = 'adopted'
    project.adopted_by = request.user
    project.adopted_at = timezone.now()
    project.save()

    return Response(ProjectSerializer(project).data)
