import io
import logging
from datetime import date, timedelta
from uuid import uuid4

import boto3
from django.conf import settings
from django.http import HttpResponse
from django.utils import timezone
from django.db.models import Avg
from rest_framework import viewsets, status
from rest_framework.decorators import api_view, action, permission_classes
from rest_framework.parsers import MultiPartParser, JSONParser
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response

from apps.auth_service.permissions import IsLeader
from .models import Project, ProjectPhoto, ProjectRating
from .serializers import (
    ProjectSerializer, ProjectPhotoSerializer,
    ProjectRatingSerializer, ProjectAdoptSerializer,
)

logger = logging.getLogger(__name__)


def _generate_pdf_bytes(project: 'Project') -> bytes:
    """Build and return the raw PDF bytes for a project proposal."""
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
                                   textColor=colors.HexColor('#1B5E20'),
                                   fontSize=18, spaceAfter=6)
    sub_style = ParagraphStyle('Sub', parent=styles['Heading2'],
                               textColor=colors.HexColor('#2C3E50'),
                               fontSize=13, spaceAfter=4)
    body_style = ParagraphStyle('Body', parent=styles['Normal'],
                                fontSize=11, spaceAfter=6)

    village = project.village
    panchayat = village.panchayat if village else None
    fund_plan = project.fund_convergence_plans.first()

    story = []

    # Header
    story.append(Paragraph('PrajaShakti AI', ParagraphStyle('brand', parent=styles['Normal'],
                 fontSize=10, textColor=colors.grey, alignment=TA_CENTER)))
    story.append(Paragraph('PROJECT PROPOSAL', heading_style))
    story.append(HRFlowable(width="100%", thickness=2, color=colors.HexColor('#1B5E20')))
    story.append(Spacer(1, 0.4*cm))

    # Project title and status
    story.append(Paragraph(project.title, sub_style))
    story.append(Paragraph(
        f"Category: {project.category.title()} &nbsp;&nbsp; Status: {project.status.replace('_', ' ').title()} &nbsp;&nbsp; "
        f"Priority Score: {int(project.priority_score) if project.priority_score else 'N/A'}/100",
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
        ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#E8F5E9')),
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

    def fmt_inr(n):
        if n >= 100000:
            return f'Rs. {n:,} ({n/100000:.1f} Lakh)'
        return f'Rs. {n:,}'

    fin_data = [
        ['Total Estimated Cost', fmt_inr(cost_inr)],
        ['Beneficiaries', f"{project.beneficiary_count or 'N/A'} households"],
        ['AI Confidence', f"{int((project.ai_confidence or 0.75) * 100)}%"],
    ]
    if fund_plan:
        scheme_total = sum(s.get('amount_inr', 0) for s in (fund_plan.schemes_used or []))
        fin_data.append(['Govt. Scheme Subsidy', fmt_inr(scheme_total)])
        fin_data.append(['Panchayat Contribution', fmt_inr(fund_plan.panchayat_contribution_inr)])
        fin_data.append(['Savings vs. Full Cost', f"{fund_plan.savings_pct:.0f}%"])

    fin_table = Table(fin_data, colWidths=[8*cm, 8*cm])
    fin_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#E8F5E9')),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (1, 0), (1, -1), 'Helvetica-Bold'),
        ('TEXTCOLOR', (1, 0), (1, 0), colors.HexColor('#B71C1C')),   # total cost red
        ('TEXTCOLOR', (1, 3), (1, 4), colors.HexColor('#1B5E20')),   # subsidy green
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('PADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(fin_table)
    story.append(Spacer(1, 0.4*cm))

    # Scheme convergence
    if fund_plan and fund_plan.schemes_used:
        story.append(Paragraph('Fund Convergence Plan', sub_style))
        story.append(Paragraph(
            'This project qualifies for subsidy under multiple government schemes. '
            'The following fund convergence plan minimises panchayat expenditure:',
            body_style
        ))
        scheme_rows = [['Scheme', 'Amount', 'Coverage %']]
        for s in fund_plan.schemes_used:
            scheme_rows.append([
                s.get('scheme_name', ''),
                f"Rs. {s.get('amount_inr', 0):,}",
                f"{s.get('pct_covered', 0):.0f}%",
            ])
        # Add panchayat row
        scheme_rows.append([
            'Panchayat Fund',
            f"Rs. {fund_plan.panchayat_contribution_inr:,}",
            f"{100 - fund_plan.savings_pct:.0f}%",
        ])
        scheme_table = Table(scheme_rows, colWidths=[9*cm, 5*cm, 2.5*cm])
        scheme_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1B5E20')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('BACKGROUND', (0, -1), (-1, -1), colors.HexColor('#FFF9C4')),  # panchayat row yellow
            ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, colors.HexColor('#F1F8E9')]),
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
            ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#E8F5E9')),
            ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('PADDING', (0, 0), (-1, -1), 6),
        ]))
        story.append(impact_table)
        story.append(Spacer(1, 0.4*cm))

    # Footer
    story.append(HRFlowable(width="100%", thickness=1, color=colors.grey))
    story.append(Paragraph(
        f"Generated by PrajaShakti AI &bull; Adopted: {project.adopted_at.strftime('%d %b %Y') if project.adopted_at else 'Pending'} "
        f"&bull; Village: {village.name if village else 'N/A'}",
        ParagraphStyle('footer', parent=styles['Normal'], fontSize=9,
                       textColor=colors.grey, alignment=TA_CENTER)
    ))

    doc.build(story)
    return buffer.getvalue()


def _generate_and_upload_proposal(project: 'Project') -> str:
    """Generate a PDF proposal and upload to S3. Returns S3 key or empty string on failure."""
    try:
        pdf_bytes = _generate_pdf_bytes(project)
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
    except Exception as e:
        logger.error(f"PDF generation/upload failed for project {project.id}: {e}")
        return ''


def _upload_photo_to_s3(file, project_id: int) -> str:
    """Upload a file-like object to S3 and return the s3_key."""
    ext = file.name.rsplit('.', 1)[-1].lower() if '.' in file.name else 'jpg'
    s3_key = f"projects/{project_id}/{uuid4().hex}.{ext}"
    s3 = boto3.client(
        's3',
        region_name=settings.AWS_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    )
    s3.put_object(
        Bucket=settings.AWS_S3_CITIZEN_PHOTOS_BUCKET,
        Key=s3_key,
        Body=file.read(),
        ContentType=getattr(file, 'content_type', 'image/jpeg'),
    )
    return s3_key


class ProjectViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ProjectSerializer
    filterset_fields = ['village', 'status', 'category']

    def get_queryset(self):
        return Project.objects.select_related(
            'village', 'cluster', 'adopted_by'
        ).prefetch_related('photos', 'ratings', 'fund_convergence_plans')

    @action(detail=True, methods=['patch'], permission_classes=[IsAuthenticated, IsLeader])
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

    @action(detail=True, methods=['post'], parser_classes=[MultiPartParser, JSONParser])
    def photos(self, request, pk=None):
        project = self.get_object()
        s3_key = ''
        if 'file' in request.FILES:
            try:
                s3_key = _upload_photo_to_s3(request.FILES['file'], project.id)
            except Exception as e:
                logger.error(f"Photo S3 upload failed for project {project.id}: {e}")
                return Response({'error': 'Photo upload failed'}, status=500)
        else:
            s3_key = request.data.get('s3_key', '')

        serializer = ProjectPhotoSerializer(data={
            'project': project.id,
            's3_key': s3_key,
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
    fund_available = panchayat.fund_available_inr or 0

    # Build per-category fund breakdown matching Flutter's FundStatus model:
    # { category, allocated_inr, spent_inr, utilization_pct }
    category_costs = Project.objects.filter(
        village_id__in=village_ids,
        status__in=['adopted', 'in_progress', 'completed'],
    ).values('category').annotate(total=Sum('estimated_cost_inr'))

    by_category = []
    for row in category_costs:
        allocated = row['total'] or 0
        # For demo: completed projects count as 'spent', others as 'allocated'
        spent = Project.objects.filter(
            village_id__in=village_ids,
            category=row['category'],
            status='completed',
        ).aggregate(s=Sum('estimated_cost_inr'))['s'] or 0
        utilization = (spent / allocated * 100) if allocated > 0 else 0
        by_category.append({
            'category': row['category'],
            'allocated_inr': allocated,
            'spent_inr': spent,
            'utilization_pct': round(utilization, 1),
        })

    return Response({
        'fund_available_inr': fund_available,
        'by_category': by_category,
        'panchayat_name': panchayat.name,
    })


def _create_fund_plan(project: 'Project'):
    """Create a FundConvergencePlan for a project based on its category and available schemes."""
    from apps.scheme_rag.models import FundConvergencePlan, Scheme

    # Per-category scheme allocation: list of (short_name_fragment, subsidy_pct)
    CATEGORY_SCHEMES = {
        'water': [('PM-KUSUM', 60), ('MGNREGA', 20), ('Jal Jeevan', 10)],
        'road': [('PMGSY', 60), ('MGNREGA', 30)],
        'sanitation': [('SBM-G', 90)],
        'education': [('Samagra Shiksha', 60), ('MGNREGA', 20)],
        'health': [('MGNREGA', 50)],
        'electricity': [('PM-KUSUM', 60), ('MGNREGA', 20)],
        'other': [('MGNREGA', 50)],
    }
    total_cost = project.estimated_cost_inr or 1_500_000
    scheme_configs = CATEGORY_SCHEMES.get(project.category, CATEGORY_SCHEMES['other'])

    schemes_used = []
    total_scheme_pct = 0
    for name_fragment, pct in scheme_configs:
        scheme = Scheme.objects.filter(short_name__icontains=name_fragment.split()[0]).first()
        if scheme:
            amount = int(total_cost * pct / 100)
            schemes_used.append({
                'scheme_id': scheme.id,
                'scheme_name': scheme.short_name,
                'amount_inr': amount,
                'pct_covered': float(pct),
            })
            total_scheme_pct += pct

    scheme_total = sum(s['amount_inr'] for s in schemes_used)
    panchayat_contribution = max(0, total_cost - scheme_total)
    savings_pct = (scheme_total / total_cost * 100) if total_cost > 0 else 0

    FundConvergencePlan.objects.create(
        project=project,
        total_cost_inr=total_cost,
        panchayat_contribution_inr=panchayat_contribution,
        savings_pct=round(savings_pct, 1),
        schemes_used=schemes_used,
    )
    logger.info(f"Fund plan created for project #{project.id}: {savings_pct:.0f}% subsidy coverage")


def _create_project_from_cluster(cluster, user):
    """Create a project from a cluster and immediately set it in_progress."""
    category_titles = {
        'water': 'Water Supply Infrastructure',
        'road': 'Road Development Project',
        'health': 'Health Facility Improvement',
        'education': 'Education Infrastructure',
        'electricity': 'Rural Electrification Project',
        'sanitation': 'Sanitation and Hygiene Project',
        'other': 'Community Development Project',
    }
    # Estimated costs by category (in INR)
    category_costs = {
        'water': 1_500_000,
        'road': 2_000_000,
        'health': 800_000,
        'education': 600_000,
        'electricity': 1_200_000,
        'sanitation': 500_000,
        'other': 1_000_000,
    }
    title = f"{category_titles.get(cluster.category, 'Development Project')} - {cluster.village.name}"
    description = (
        f"AI-recommended project addressing {cluster.category} needs in {cluster.village.name}. "
        f"Based on {cluster.report_count} community reports with {cluster.upvote_count} upvotes "
        f"across {cluster.ward_count} wards."
    )
    priority_score = None
    try:
        priority_score = cluster.priority_score.total_score
    except Exception:
        pass

    return Project.objects.create(
        cluster=cluster,
        village=cluster.village,
        title=title,
        description=description,
        category=cluster.category,
        location=cluster.centroid,
        estimated_cost_inr=category_costs.get(cluster.category, 1_500_000),
        beneficiary_count=cluster.estimated_households or (cluster.report_count * 3),
        priority_score=priority_score,
        ai_confidence=0.75,
        status='in_progress',
        adopted_by=user,
        adopted_at=timezone.now(),
        started_at=timezone.now(),
        expected_completion=date.today() + timedelta(days=180),
    )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsLeader])
def adopt_project(request):
    serializer = ProjectAdoptSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    cluster_id = serializer.validated_data['cluster_id']

    # Find any existing project for this cluster
    project = Project.objects.filter(
        cluster_id=cluster_id
    ).prefetch_related('fund_convergence_plans').order_by('created_at').first()

    if project:
        if project.status == 'completed':
            # Already completed — return as-is without re-adopting
            project.refresh_from_db()
            return Response(ProjectSerializer(project).data)

        # Move to in_progress (covers both 'recommended' and 'adopted' states)
        if project.status != 'in_progress':
            project.status = 'in_progress'
        if not project.adopted_by:
            project.adopted_by = request.user
        if not project.adopted_at:
            project.adopted_at = timezone.now()
        if not project.started_at:
            project.started_at = timezone.now()
        project.save()
    else:
        # No project exists — generate one from cluster data
        from apps.community.models import ReportCluster
        try:
            cluster = ReportCluster.objects.select_related(
                'village__panchayat__block__district', 'priority_score'
            ).get(id=cluster_id)
        except ReportCluster.DoesNotExist:
            return Response({'error': 'Cluster not found'}, status=404)
        project = _create_project_from_cluster(cluster, request.user)

    # Reload with relations needed for PDF and serializer
    project = Project.objects.prefetch_related('fund_convergence_plans').get(id=project.id)

    # Create fund convergence plan if none exists
    if not project.fund_convergence_plans.exists():
        _create_fund_plan(project)
        project = Project.objects.prefetch_related('fund_convergence_plans').get(id=project.id)

    # Generate PDF proposal (always regenerate if key missing)
    if not project.proposal_s3_key:
        proposal_key = _generate_and_upload_proposal(project)
        if proposal_key:
            Project.objects.filter(pk=project.id).update(proposal_s3_key=proposal_key)
            project = Project.objects.prefetch_related('fund_convergence_plans').get(id=project.id)

    return Response(ProjectSerializer(project).data)


@api_view(['GET'])
@permission_classes([AllowAny])
def project_proposal_pdf(request, project_id):
    """Stream the project proposal PDF directly — accepts JWT via Authorization header or ?token= param."""
    # Validate auth: accept standard header OR query param (for browser-tab downloads)
    token = request.query_params.get('token', '')
    if not token:
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        token = auth_header.replace('Bearer ', '').replace('bearer ', '').strip()

    if not token:
        return HttpResponse('Unauthorized — pass ?token=<jwt>', status=401, content_type='text/plain')

    try:
        from rest_framework_simplejwt.tokens import AccessToken
        AccessToken(token)  # raises if invalid/expired
    except Exception:
        return HttpResponse('Invalid or expired token', status=401, content_type='text/plain')

    try:
        project = Project.objects.select_related(
            'village__panchayat__block__district'
        ).prefetch_related('fund_convergence_plans').get(id=project_id)
    except Project.DoesNotExist:
        return HttpResponse('Project not found', status=404, content_type='text/plain')

    try:
        pdf_bytes = _generate_pdf_bytes(project)
    except Exception as e:
        logger.error(f"PDF stream generation failed for project {project_id}: {e}")
        return HttpResponse('PDF generation failed', status=500, content_type='text/plain')

    safe_title = ''.join(c if c.isalnum() or c in '-_' else '_' for c in project.title)[:40]
    filename = f"PrajaShakti_Proposal_{project_id}_{safe_title}.pdf"
    response = HttpResponse(pdf_bytes, content_type='application/pdf')
    response['Content-Disposition'] = f'inline; filename="{filename}"'
    response['Content-Length'] = str(len(pdf_bytes))
    return response


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def government_dashboard(request):
    """Government dashboard: top voted reports + AI priority ranking across all villages."""
    village_id = request.query_params.get('village', 1)

    from apps.community.models import Report, ReportCluster
    from apps.community.serializers import ReportSerializer, ReportClusterSerializer
    from apps.ai_engine.models import PriorityScore
    from apps.ai_engine.serializers import PriorityScoreSerializer

    # Top 10 most-voted reports
    top_reports = Report.objects.filter(
        village_id=village_id
    ).select_related('reporter', 'village').order_by('-vote_count')[:10]

    # AI priority clusters ranked by score
    priority_scores = PriorityScore.objects.filter(
        cluster__village_id=village_id
    ).select_related('cluster__village').order_by('-total_score')[:10]

    # Summary counts
    total_reports = Report.objects.filter(village_id=village_id).count()
    critical_reports = Report.objects.filter(village_id=village_id, urgency='critical').count()
    resolved_reports = Report.objects.filter(village_id=village_id, status='completed').count()
    active_projects = Project.objects.filter(village_id=village_id, status__in=['adopted', 'in_progress']).count()

    return Response({
        'summary': {
            'total_reports': total_reports,
            'critical_reports': critical_reports,
            'resolved_reports': resolved_reports,
            'active_projects': active_projects,
        },
        'top_voted_reports': ReportSerializer(top_reports, many=True, context={'request': request}).data,
        'ai_priority_ranking': PriorityScoreSerializer(priority_scores, many=True).data,
    })
