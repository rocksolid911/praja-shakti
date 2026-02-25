import io
import logging
from uuid import uuid4

import boto3
from django.conf import settings
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

logger = logging.getLogger(__name__)


def _generate_and_upload_proposal(project: 'Project') -> str:
    """Generate a PDF project proposal using reportlab and upload to S3. Returns S3 key."""
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.units import cm
        from reportlab.lib import colors
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
        from reportlab.lib.enums import TA_CENTER, TA_LEFT

        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4,
                                rightMargin=2*cm, leftMargin=2*cm,
                                topMargin=2*cm, bottomMargin=2*cm)

        styles = getSampleStyleSheet()
        heading_style = ParagraphStyle('Heading', parent=styles['Heading1'],
                                       textColor=colors.HexColor('#FF6B35'),
                                       fontSize=18, spaceAfter=6)
        sub_style = ParagraphStyle('Sub', parent=styles['Heading2'],
                                   textColor=colors.HexColor('#2C3E50'),
                                   fontSize=13, spaceAfter=4)
        body_style = styles['Normal']
        body_style.fontSize = 11
        body_style.spaceAfter = 6

        village = project.village
        panchayat = village.panchayat if village else None
        fund_plan = getattr(project, 'fund_convergence_plans', None)
        fund_plan = fund_plan.first() if fund_plan else None

        story = []

        # Header
        story.append(Paragraph('PrajaShakti AI', ParagraphStyle('brand', parent=styles['Normal'],
                     fontSize=10, textColor=colors.grey, alignment=TA_CENTER)))
        story.append(Paragraph('PROJECT PROPOSAL', heading_style))
        story.append(HRFlowable(width="100%", thickness=2, color=colors.HexColor('#FF6B35')))
        story.append(Spacer(1, 0.4*cm))

        # Project title and status
        story.append(Paragraph(project.title, sub_style))
        story.append(Paragraph(
            f"Category: {project.category.title()} &nbsp;&nbsp; Status: {project.status.replace('_', ' ').title()} &nbsp;&nbsp; "
            f"Priority Score: {project.priority_score or 'N/A'}",
            body_style
        ))
        story.append(Spacer(1, 0.3*cm))

        # Location
        story.append(Paragraph('Location', sub_style))
        loc_data = [
            ['Village', village.name if village else 'N/A'],
            ['Panchayat', panchayat.name if panchayat else 'N/A'],
            ['Block', panchayat.block.name if panchayat else 'N/A'],
            ['District', panchayat.block.district.name if panchayat else 'N/A'],
        ]
        loc_table = Table(loc_data, colWidths=[5*cm, 11*cm])
        loc_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#F5F5F5')),
            ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('PADDING', (0, 0), (-1, -1), 6),
        ]))
        story.append(loc_table)
        story.append(Spacer(1, 0.4*cm))

        # Project Description
        story.append(Paragraph('Project Description', sub_style))
        story.append(Paragraph(project.description, body_style))
        story.append(Spacer(1, 0.3*cm))

        # Financial Summary
        story.append(Paragraph('Financial Summary', sub_style))
        cost_inr = project.estimated_cost_inr or 0
        fin_data = [
            ['Total Estimated Cost', f'Rs. {cost_inr:,}'],
            ['Beneficiaries', str(project.beneficiary_count or 'N/A')],
        ]
        if fund_plan:
            fin_data.append(['Panchayat Contribution', f'Rs. {fund_plan.panchayat_contribution_inr:,}'])
            fin_data.append(['Govt. Scheme Coverage', f'{100 - fund_plan.savings_pct:.0f}%'])
        fin_table = Table(fin_data, colWidths=[8*cm, 8*cm])
        fin_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#F5F5F5')),
            ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
            ('FONTNAME', (1, 0), (1, -1), 'Helvetica-Bold'),
            ('TEXTCOLOR', (1, 0), (1, -1), colors.HexColor('#27AE60')),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('PADDING', (0, 0), (-1, -1), 6),
        ]))
        story.append(fin_table)
        story.append(Spacer(1, 0.4*cm))

        # Scheme convergence
        if fund_plan and fund_plan.schemes_used:
            story.append(Paragraph('Fund Convergence Plan', sub_style))
            scheme_rows = [['Scheme', 'Amount (Rs.)', 'Coverage']]
            for s in fund_plan.schemes_used:
                scheme_rows.append([
                    s.get('scheme_name', ''),
                    f"{s.get('amount_inr', 0):,}",
                    f"{s.get('pct_covered', 0):.0f}%",
                ])
            scheme_table = Table(scheme_rows, colWidths=[9*cm, 5*cm, 2*cm])
            scheme_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#FF6B35')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#FFF8F5')]),
                ('PADDING', (0, 0), (-1, -1), 6),
            ]))
            story.append(scheme_table)
            story.append(Spacer(1, 0.4*cm))

        # Impact projections
        if project.impact_projection:
            story.append(Paragraph('Projected Impact', sub_style))
            impact_rows = [[k.replace('_', ' ').title(), str(v)]
                           for k, v in project.impact_projection.items()]
            impact_table = Table(impact_rows, colWidths=[10*cm, 6*cm])
            impact_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#F5F5F5')),
                ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
                ('PADDING', (0, 0), (-1, -1), 6),
            ]))
            story.append(impact_table)
            story.append(Spacer(1, 0.4*cm))

        # Footer
        story.append(HRFlowable(width="100%", thickness=1, color=colors.grey))
        story.append(Paragraph(
            f"Generated by PrajaShakti AI &bull; Adopted: {project.adopted_at.strftime('%d %b %Y') if project.adopted_at else 'N/A'} "
            f"&bull; AI Confidence: {int((project.ai_confidence or 0) * 100)}%",
            ParagraphStyle('footer', parent=styles['Normal'], fontSize=9,
                           textColor=colors.grey, alignment=TA_CENTER)
        ))

        doc.build(story)
        pdf_bytes = buffer.getvalue()

        # Upload to S3
        s3_key = f"proposals/{project.id}/{uuid4().hex}-proposal.pdf"
        s3 = boto3.client(
            's3',
            region_name=settings.AWS_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        )
        s3.put_object(
            Bucket=settings.AWS_S3_REPORTS_BUCKET,
            Key=s3_key,
            Body=pdf_bytes,
            ContentType='application/pdf',
        )
        logger.info(f"Project proposal uploaded: {s3_key}")
        return s3_key

    except ImportError:
        logger.warning("reportlab not installed — skipping PDF generation")
        return ''
    except Exception as e:
        logger.error(f"PDF generation failed for project {project.id}: {e}")
        return ''


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

    # Generate PDF proposal and upload to S3 (best-effort, non-blocking)
    proposal_key = _generate_and_upload_proposal(project)
    if proposal_key:
        project.proposal_s3_key = proposal_key
        project.save(update_fields=['proposal_s3_key'])

    return Response(ProjectSerializer(project).data)
