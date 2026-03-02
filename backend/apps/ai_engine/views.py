from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import PriorityScore, AITask
from .serializers import (
    PriorityScoreSerializer, AITaskSerializer,
    TranscribeRequestSerializer, SchemeQuerySerializer,
)
from apps.community.models import ReportCluster
from apps.projects.models import Project
from apps.projects.serializers import ProjectSerializer


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def transcribe(request):
    serializer = TranscribeRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    task = AITask.objects.create(
        task_type='transcribe',
        input_data=serializer.validated_data,
    )

    # Trigger async transcription (fail-fast: never blocks > 0.5s if Redis is down)
    from apps.utils import is_redis_available
    from .tasks import transcribe_voice_note
    if is_redis_available():
        try:
            result = transcribe_voice_note.delay(
                serializer.validated_data.get('report_id'),
                serializer.validated_data['audio_s3_key'],
            )
            task.celery_task_id = result.id
            task.status = 'running'
        except Exception:
            task.status = 'pending'
    else:
        task.status = 'pending'
    task.save()

    return Response({
        'task_id': task.id,
        'status': task.status,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def transcribe_status(request, task_id):
    try:
        task = AITask.objects.get(id=task_id)
    except AITask.DoesNotExist:
        return Response({'error': 'Task not found'}, status=404)
    return Response(AITaskSerializer(task).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def priorities(request):
    village_id = request.query_params.get('village')
    if not village_id:
        return Response({'error': 'village parameter required'}, status=400)

    scores = PriorityScore.objects.filter(
        cluster__village_id=village_id
    ).select_related('cluster').order_by('-total_score')

    # Return cluster-centric format that matches the Flutter PriorityCluster model.
    # The Flutter model expects: id=cluster_id, category, report_count, upvote_count,
    # and a nested priority_score object.
    data = []
    for ps in scores:
        cluster = ps.cluster
        data.append({
            'id': cluster.id,
            'category': cluster.category,
            'report_count': cluster.report_count,
            'upvote_count': cluster.upvote_count,
            'priority_score': {
                'total_score': ps.total_score,
                'community_score': ps.community_score,
                'data_score': ps.data_score,
                'urgency_score': ps.urgency_score,
                'justification': ps.justification,
            },
        })

    # Include total_reports so the Flutter summary card can display the count.
    # The cubit reads prioritiesData['total_reports'] when the response is a dict.
    from apps.community.models import Report
    total_reports = Report.objects.filter(village_id=village_id).count()

    return Response({
        'total_reports': total_reports,
        'results': data,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def recommendations(request):
    village_id = request.query_params.get('village')
    if not village_id:
        return Response({'error': 'village parameter required'}, status=400)

    projects = Project.objects.filter(
        village_id=village_id,
        status='recommended',
    ).select_related('village', 'cluster').prefetch_related(
        'fund_convergence_plans'
    ).order_by('-priority_score')

    return Response(ProjectSerializer(projects, many=True).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def score_detail(request, cluster_id):
    try:
        score = PriorityScore.objects.select_related(
            'cluster__village'
        ).get(cluster_id=cluster_id)
    except PriorityScore.DoesNotExist:
        return Response({'error': 'Score not found'}, status=404)

    return Response(PriorityScoreSerializer(score).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def scheme_query(request):
    serializer = SchemeQuerySerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    try:
        from apps.scheme_rag.rag_pipeline import query_scheme_rag
        result = query_scheme_rag(
            query=serializer.validated_data['query'],
            village_id=serializer.validated_data['village_id'],
        )
        return Response(result)
    except Exception as e:
        return Response({'error': str(e)}, status=500)
