"""
Celery tasks for the async AI pipeline.
Chain: Transcribe → Categorize → Cluster → Score → Recommend
"""
import json
import logging
from uuid import uuid4

import boto3
from celery import shared_task
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)


@shared_task
def transcribe_voice_note(report_id: int, s3_key: str):
    """Step 1: Start AWS Transcribe job for voice note."""
    from apps.community.models import Report
    from .models import AITask

    try:
        client = boto3.client('transcribe', region_name=settings.AWS_REGION)
        job_name = f"prajashakti-{report_id}-{uuid4().hex[:8]}"

        client.start_transcription_job(
            TranscriptionJobName=job_name,
            Media={'MediaFileUri': f"s3://{settings.AWS_S3_AUDIO_BUCKET}/{s3_key}"},
            MediaFormat='ogg',
            LanguageCode='hi-IN',
            Settings={'ShowSpeakerLabels': False},
        )

        report = Report.objects.get(id=report_id)
        report.transcribe_job_id = job_name
        report.save(update_fields=['transcribe_job_id'])

        # Schedule check after 30 seconds
        check_transcription.apply_async(
            args=[report_id, job_name],
            countdown=30,
        )
        logger.info(f"Started transcription job {job_name} for report #{report_id}")
    except Exception as e:
        logger.error(f"Transcription failed for report #{report_id}: {e}")
        # Fall back to categorizing with existing text
        report = Report.objects.get(id=report_id)
        if report.description_text and report.description_text != '[Voice note - transcription pending]':
            categorize_report.delay(report_id, report.description_text)


@shared_task(bind=True, max_retries=10, default_retry_delay=15)
def check_transcription(self, report_id: int, job_name: str):
    """Step 2: Poll transcription job status."""
    from apps.community.models import Report

    try:
        client = boto3.client('transcribe', region_name=settings.AWS_REGION)
        job = client.get_transcription_job(TranscriptionJobName=job_name)
        status = job['TranscriptionJob']['TranscriptionJobStatus']

        if status == 'IN_PROGRESS':
            raise self.retry()

        if status == 'COMPLETED':
            import requests
            transcript_uri = job['TranscriptionJob']['Transcript']['TranscriptFileUri']
            resp = requests.get(transcript_uri)
            transcript_data = resp.json()
            text = transcript_data['results']['transcripts'][0]['transcript']

            report = Report.objects.get(id=report_id)
            report.description_hindi = text
            if not report.description_text or report.description_text == '[Voice note - transcription pending]':
                report.description_text = text
            report.save()

            categorize_report.delay(report_id, text)
            logger.info(f"Transcription completed for report #{report_id}")

        elif status == 'FAILED':
            logger.error(f"Transcription failed for job {job_name}")

    except self.MaxRetriesExceededError:
        logger.error(f"Transcription polling timed out for report #{report_id}")
    except Exception as e:
        logger.error(f"Check transcription error: {e}")
        raise self.retry(exc=e)


@shared_task
def categorize_report(report_id: int, text: str = ''):
    """Step 3: Use Bedrock Claude to categorize the report."""
    from apps.community.models import Report

    report = Report.objects.get(id=report_id)
    text = text or report.description_text

    prompt = f"""You are analyzing rural Indian citizen reports. Categorize this report.

Report text: "{text}"

Respond ONLY with valid JSON matching this schema:
{{
  "category": "<water|road|health|education|electricity|sanitation|other>",
  "sub_category": "<specific issue in 3-5 words>",
  "urgency": "<low|medium|high|critical>",
  "confidence": <0.0-1.0>,
  "english_summary": "<1 sentence English summary>"
}}"""

    try:
        from .bedrock_client import call_bedrock_claude
        response_text = call_bedrock_claude(prompt, max_tokens=300)
        result = json.loads(response_text)

        report.category = result.get('category', 'other')
        report.sub_category = result.get('sub_category', '')
        report.urgency = result.get('urgency', 'medium')
        report.ai_confidence = result.get('confidence', 0.5)
        if result.get('english_summary'):
            report.description_text = result['english_summary']
        report.save()

        logger.info(f"Report #{report_id} categorized as {report.category}")
    except Exception as e:
        logger.warning(f"Bedrock categorization failed for report #{report_id}: {e}")
        # Fallback: keyword-based categorization
        _keyword_categorize(report, text)

    # For voice-note reports: notify village users after categorization (so message has proper description).
    # Text reports are notified immediately on creation — skip here to avoid duplicates.
    if report.audio_s3_key:
        try:
            from apps.notifications.tasks import notify_village_new_report
            notify_village_new_report.delay(report_id)
        except Exception as e:
            logger.warning(f"Village notification dispatch failed for report #{report_id}: {e}")

    # Trigger clustering
    cluster_village_reports.delay(report.village_id)


def _keyword_categorize(report, text):
    """Fallback keyword-based categorization when Bedrock is unavailable."""
    text_lower = text.lower()
    keyword_map = {
        'water': ['water', 'pani', 'jal', 'borewell', 'well', 'nala', 'paani', 'handpump'],
        'road': ['road', 'sadak', 'rasta', 'bridge', 'pul', 'path', 'footpath'],
        'health': ['health', 'hospital', 'doctor', 'dawai', 'medicine', 'clinic', 'swasthya'],
        'education': ['school', 'vidyalaya', 'teacher', 'shiksha', 'padhai'],
        'electricity': ['bijli', 'electricity', 'light', 'power', 'solar', 'transformer'],
        'sanitation': ['toilet', 'shauchalaya', 'drain', 'nali', 'garbage', 'kachra'],
    }
    for cat, keywords in keyword_map.items():
        if any(kw in text_lower for kw in keywords):
            report.category = cat
            report.urgency = 'medium'
            report.ai_confidence = 0.6
            report.save()
            return
    report.category = 'other'
    report.urgency = 'medium'
    report.ai_confidence = 0.3
    report.save()


@shared_task
def cluster_village_reports(village_id: int):
    """Step 4: Spatial clustering using PostGIS ST_ClusterDBSCAN."""
    from django.db import connection
    from django.contrib.gis.geos import Point
    from apps.community.models import Report, ReportCluster

    # Use PostGIS spatial clustering
    with connection.cursor() as cursor:
        cursor.execute("""
            WITH clustered AS (
                SELECT id, category,
                    ST_ClusterDBSCAN(location::geometry, eps := 0.005, minpoints := 2)
                        OVER (PARTITION BY category) AS cid
                FROM community_report
                WHERE village_id = %s AND category IS NOT NULL
                    AND category != '' AND location IS NOT NULL
            )
            SELECT cid, category,
                   ST_X(ST_Centroid(ST_Collect(cr.location::geometry))) as cx,
                   ST_Y(ST_Centroid(ST_Collect(cr.location::geometry))) as cy,
                   COUNT(*) as report_count,
                   COUNT(DISTINCT cr.ward) as ward_count,
                   SUM(cr.vote_count) as upvote_count
            FROM community_report cr
            JOIN clustered c ON cr.id = c.id
            WHERE c.cid IS NOT NULL
            GROUP BY c.cid, c.category
        """, [village_id])

        rows = cursor.fetchall()

    for row in rows:
        cid, category, cx, cy, report_count, ward_count, upvote_count = row
        centroid = Point(cx, cy, srid=4326)

        cluster, created = ReportCluster.objects.update_or_create(
            village_id=village_id,
            category=category,
            defaults={
                'centroid': centroid,
                'radius_km': 0.5,
                'report_count': report_count,
                'ward_count': ward_count,
                'upvote_count': upvote_count or 0,
            },
        )

        # Assign reports to clusters
        Report.objects.filter(
            village_id=village_id, category=category, location__isnull=False,
        ).update(cluster=cluster)

    logger.info(f"Clustered reports for village #{village_id}: {len(rows)} clusters")

    # Trigger priority scoring
    score_village_priorities.delay(village_id)


@shared_task
def score_village_priorities(village_id: int):
    """Step 5: Calculate priority scores for all clusters in a village."""
    from apps.community.models import ReportCluster
    from .scoring import calculate_priority_score

    clusters = ReportCluster.objects.filter(village_id=village_id)
    for cluster in clusters:
        try:
            calculate_priority_score(cluster.id)
        except Exception as e:
            logger.error(f"Scoring failed for cluster #{cluster.id}: {e}")

    # Generate recommendations for top-priority clusters
    top_clusters = clusters.order_by('-community_priority_score')[:3]
    for cluster in top_clusters:
        generate_project_recommendation.delay(cluster.id)


@shared_task
def generate_project_recommendation(cluster_id: int):
    """Step 6: Generate AI-powered project recommendation."""
    from apps.projects.models import Project
    from .recommendation import generate_recommendation

    # Check if recommendation already exists
    existing = Project.objects.filter(cluster_id=cluster_id, status='recommended').exists()
    if existing:
        logger.info(f"Recommendation already exists for cluster #{cluster_id}")
        return

    try:
        project = generate_recommendation(cluster_id)
        logger.info(f"Generated recommendation for cluster #{cluster_id}: {project.title}")
    except Exception as e:
        logger.error(f"Recommendation generation failed for cluster #{cluster_id}: {e}")


@shared_task
def generate_gram_sabha_summary(session_id: int):
    """Generate AI summary for a completed Gram Sabha session."""
    from apps.community.models import GramSabhaSession, GramSabhaIssue
    from .bedrock_client import call_bedrock_claude

    try:
        session = GramSabhaSession.objects.select_related('village').get(id=session_id)
        issues = GramSabhaIssue.objects.filter(session=session).order_by('-vote_count')
        issue_list = "\n".join(f"- {i.title} ({i.vote_count} votes)" for i in issues)

        if not issue_list:
            issue_list = "(No issues recorded)"

        prompt = f"""Gram Sabha session "{session.title}" for {session.village.name}.
Issues raised:\n{issue_list}\n\nWrite a concise Hindi+English meeting summary
(3-5 bullet points) suitable for official records. Focus on top-voted issues."""

        summary = call_bedrock_claude(prompt, max_tokens=500)
        session.transcript = summary
        session.save(update_fields=['transcript'])
        logger.info(f"Gram Sabha summary generated for session #{session_id}")
    except Exception as e:
        logger.error(f"Gram Sabha summary failed for session #{session_id}: {e}")
