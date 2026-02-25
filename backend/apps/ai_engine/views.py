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

    # Trigger async transcription
    try:
        from .tasks import transcribe_voice_note
        result = transcribe_voice_note.delay(
            serializer.validated_data.get('report_id'),
            serializer.validated_data['audio_s3_key'],
        )
        task.celery_task_id = result.id
        task.status = 'running'
        task.save()
    except Exception:
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
    ).select_related('cluster__village').order_by('-total_score')

    return Response(PriorityScoreSerializer(scores, many=True).data)


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
