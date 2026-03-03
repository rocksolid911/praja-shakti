import logging
from uuid import uuid4

import requests
from django.conf import settings
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)
User = get_user_model()



def _download_media_to_s3(media_url: str, report_id: int) -> str:
    """Download Twilio voice note and upload to S3. Returns S3 key or original URL as fallback."""
    import boto3

    try:
        response = requests.get(
            media_url,
            auth=(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN),
            timeout=30,
        )
        response.raise_for_status()

        content_type = response.headers.get('Content-Type', 'audio/ogg')
        ext = 'ogg' if 'ogg' in content_type else ('m4a' if 'm4a' in content_type else 'ogg')
        s3_key = f"voice/{report_id}/{uuid4().hex}.{ext}"

        s3 = boto3.client(
            's3',
            region_name=settings.AWS_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        )
        s3.put_object(
            Bucket=settings.AWS_S3_AUDIO_BUCKET,
            Key=s3_key,
            Body=response.content,
            ContentType=content_type,
        )
        logger.info(f"Voice note uploaded to S3: {s3_key}")
        return s3_key
    except Exception as e:
        logger.error(f"Failed to upload voice note to S3, falling back to URL: {e}")
        return media_url  # fallback for local dev without AWS

HELP_TEXT_HINDI = """PrajaShakti AI - Aapka Gaon, Aapki Awaaz

Commands:
- Voice note bhejein: Report banaye
- "Status" ya "Mera report": Apne report ka status dekhein
- "Vote 123": Report #123 ko upvote karein
- "GAON [naam]": Apna gaon set/change karein
- "WARD <number>": Apna ward set karein
- Scheme ka naam (e.g., "PM-KUSUM"): Eligibility jaanein
- "Help": Ye help message

Aapki awaaz sunai jayegi!"""


def _normalize_phone(phone: str) -> str:
    """Strip country code prefix so +919078277159 and 9078277159 match the same user."""
    # Remove leading + and country code 91 for India
    if phone.startswith('+91'):
        return phone[3:]
    if phone.startswith('91') and len(phone) == 12:
        return phone[2:]
    return phone


def _get_or_create_whatsapp_user(phone: str):
    """Find user by normalized phone, or create one without panchayat (gate handles assignment)."""
    normalized = _normalize_phone(phone)

    # Try exact match first, then normalized
    user = (
        User.objects.filter(phone=phone).first() or
        User.objects.filter(phone=normalized).first()
    )
    if user:
        return user

    # New user — no panchayat assigned; village gate prompts GAON command
    user = User.objects.create_user(
        username=normalized,
        phone=normalized,
        role='citizen',
    )
    return user


def handle_whatsapp_message(phone: str, body: str, media_url: str = '', media_type: str = '') -> str:
    """Process incoming WhatsApp message and return response text."""

    user = _get_or_create_whatsapp_user(phone)

    body_lower = body.strip().lower()

    # Village gate: users without panchayat must select village first
    if not user.panchayat and not body_lower.startswith('gaon '):
        return ("Namaste! PrajaShakti mein aapka swagat hai.\n\n"
                "Pehle apna gaon batayein:\nGAON [gaon ka naam]\n\n"
                "Example: GAON Tusra")

    # GAON command — set/change village
    if body_lower.startswith('gaon '):
        return _handle_village_selection(user, body[5:])

    # WARD command — set/change ward
    if body_lower.startswith('ward '):
        return _handle_ward_selection(user, body[5:])

    # Voice note handling
    if media_type and 'audio' in media_type:
        return handle_voice_note(user, media_url)

    # Status query
    if body_lower in ('status', 'mera report', 'report status'):
        return handle_status_query(user)

    # Vote command
    if body_lower.startswith('vote '):
        try:
            report_id = int(body_lower.split(' ')[1])
            return handle_vote(user, report_id)
        except (ValueError, IndexError):
            return "Vote ke liye report number bhejein. Example: Vote 123"

    # Help
    if body_lower in ('help', 'madad', 'sahayata'):
        return HELP_TEXT_HINDI

    # Scheme query
    scheme_keywords = ['pm-kusum', 'mgnrega', 'jal jeevan', 'pmay', 'pm-kisan',
                       'pmfby', 'pmgsy', 'sbm', 'ddu-gky', 'nrlm']
    for kw in scheme_keywords:
        if kw in body_lower:
            return handle_scheme_query(user, body)

    # Default: treat as text report
    return handle_text_report(user, body)


def _handle_village_selection(user, query: str) -> str:
    """Handle GAON <name> command — find and assign village/panchayat."""
    from apps.geo_intelligence.models import Village

    query = query.strip()
    if not query:
        return "Gaon ka naam likhein. Example: GAON Tusra"

    qs = Village.objects.select_related('panchayat').filter(name__icontains=query)[:5]
    count = qs.count()

    if count == 1:
        v = qs.first()
        user.panchayat = v.panchayat
        user.ward = user.ward or 1
        user.save(update_fields=['panchayat', 'ward'])
        return f"Gaon set! {v.name}, {v.panchayat.name}. Ab voice note bhejkar report karein!"
    elif count > 1:
        opts = "\n".join(f"• GAON {v.name} ({v.panchayat.name})" for v in qs)
        return f"Kai gaon mile:\n{opts}\n\nPoora naam likhein."
    return "Gaon nahi mila. Sahi naam likhein. Example: GAON Tusra"


def _handle_ward_selection(user, ward_text: str) -> str:
    """Handle WARD <n> command — set user's ward number."""
    try:
        ward = int(ward_text.strip())
        user.ward = ward
        user.save(update_fields=['ward'])
        return f"Ward {ward} set ho gaya!"
    except ValueError:
        return "Ward number sahi likhein. Example: WARD 3"


def _run_transcription_pipeline(report_id: int, s3_key: str):
    """Run full transcription → categorization pipeline in a background thread."""
    import time
    import json
    import boto3
    from django.conf import settings

    try:
        from apps.community.models import Report
        from apps.ai_engine.bedrock_client import call_bedrock_claude

        # Start AWS Transcribe job
        client = boto3.client('transcribe', region_name=settings.AWS_REGION)
        job_name = f'prajashakti-wa-{report_id}-{uuid4().hex[:8]}'
        ext = s3_key.rsplit('.', 1)[-1].lower() if '.' in s3_key else 'ogg'
        media_format = ext if ext in ['wav', 'mp3', 'ogg', 'flac', 'mp4', 'm4a'] else 'ogg'

        client.start_transcription_job(
            TranscriptionJobName=job_name,
            Media={'MediaFileUri': f's3://{settings.AWS_S3_AUDIO_BUCKET}/{s3_key}'},
            MediaFormat=media_format,
            LanguageCode='hi-IN',
        )

        # Poll until complete (max 2 minutes)
        for _ in range(12):
            time.sleep(10)
            job = client.get_transcription_job(TranscriptionJobName=job_name)
            status = job['TranscriptionJob']['TranscriptionJobStatus']
            if status == 'COMPLETED':
                uri = job['TranscriptionJob']['Transcript']['TranscriptFileUri']
                resp = requests.get(uri)
                text = resp.json()['results']['transcripts'][0]['transcript']
                break
            elif status == 'FAILED':
                logger.error(f"Transcription failed for report #{report_id}")
                return
        else:
            logger.error(f"Transcription timed out for report #{report_id}")
            return

        # Update report with transcript
        report = Report.objects.get(id=report_id)
        report.description_hindi = text
        report.save(update_fields=['description_hindi'])

        # Categorize with Bedrock Claude
        prompt = f"""You are analyzing rural Indian citizen reports. Categorize this report.

Report text: "{text}"

Respond ONLY with valid JSON:
{{
  "category": "<water|road|health|education|electricity|sanitation|other>",
  "sub_category": "<specific issue in 3-5 words>",
  "urgency": "<low|medium|high|critical>",
  "confidence": <0.0-1.0>,
  "english_summary": "<1 sentence English summary>"
}}"""

        response_text = call_bedrock_claude(prompt, max_tokens=300)
        # Strip markdown if present
        if '```' in response_text:
            response_text = response_text.split('```')[1]
            if response_text.startswith('json'):
                response_text = response_text[4:]
        result = json.loads(response_text.strip())

        report.refresh_from_db()
        report.category = result.get('category', 'other')
        report.sub_category = result.get('sub_category', '')
        report.urgency = result.get('urgency', 'medium')
        report.ai_confidence = result.get('confidence', 0.5)
        report.description_text = result.get('english_summary', text)
        report.save()

        logger.info(f"Report #{report_id} transcribed and categorized as {report.category}")

        # Notify the reporter that their voice note has been processed
        try:
            reporter = report.reporter
            if reporter and reporter.phone:
                village_name = report.village.name if report.village_id else 'aapka gaon'
                category_hindi = {
                    'water': 'Paani', 'road': 'Rasta', 'health': 'Swasthya',
                    'education': 'Shiksha', 'electricity': 'Bijli',
                    'sanitation': 'Safai', 'other': 'Anya',
                }.get(report.category, report.category or 'Samasya')
                desc = (report.description_text or '').strip()
                short_desc = (desc[:60] + '...') if len(desc) > 60 else desc
                msg = (
                    f"\u2705 Report #{report_id} process ho gaya!\n\n"
                    f"\U0001f4cb *{category_hindi}:* {short_desc}\n"
                    f"\U0001f4cd {village_name}\n\n"
                    f"App mein track karein ya *STATUS* bhejein."
                )
                # We are already in a daemon thread — call directly (synchronous is fine)
                from apps.notifications.tasks import send_whatsapp_message
                send_whatsapp_message(reporter.phone, msg)
        except Exception as ne:
            logger.warning(f"Reporter notification failed for report #{report_id}: {ne}")

        # Notify other village users about the new report
        try:
            from apps.notifications.tasks import notify_village_new_report
            from apps.utils import dispatch_task
            dispatch_task(notify_village_new_report, report_id, fallback=None)
        except Exception as ne:
            logger.warning(f"Village notification dispatch failed for report #{report_id}: {ne}")

    except Exception as e:
        logger.error(f"Transcription pipeline failed for report #{report_id}: {e}")


def _start_transcription_async(report_id: int, s3_key: str):
    """Try Celery first; fall back to background thread if broker unreachable."""
    from apps.utils import dispatch_task
    from apps.ai_engine.tasks import transcribe_voice_note
    dispatch_task(transcribe_voice_note, report_id, s3_key, fallback=_run_transcription_pipeline)


def _run_full_pipeline(report_id: int, twilio_url: str):
    """Download audio from Twilio → upload to S3 → queue Celery transcription task."""
    from apps.community.models import Report

    try:
        s3_key = _download_media_to_s3(twilio_url, report_id)

        if s3_key.startswith('http'):
            # S3 upload failed — the fallback URL cannot be passed to AWS Transcribe
            # (it would produce an invalid s3:// URI). Skip transcription and go
            # straight to keyword categorization so the report at least gets a
            # category and becomes visible in the community feed.
            logger.warning(
                f"S3 upload failed for report #{report_id}; "
                "skipping transcription, triggering keyword categorization"
            )
            try:
                from apps.ai_engine.tasks import categorize_report
                from apps.utils import dispatch_task
                dispatch_task(categorize_report, report_id, '', fallback=None)
            except Exception as ce:
                logger.error(f"Fallback categorization dispatch failed for report #{report_id}: {ce}")
            return

        # Update report with real S3 key (was 'pending' until download completes)
        Report.objects.filter(pk=report_id).update(audio_s3_key=s3_key)
        # Queue Celery task (or fall back to thread) — exits immediately instead of blocking 2 min
        _start_transcription_async(report_id, s3_key)
    except Exception as e:
        logger.error(f"Full pipeline failed for report #{report_id}: {e}")


def _start_full_pipeline_async(report_id: int, twilio_url: str):
    """Launch full pipeline in a background thread so webhook returns immediately."""
    import threading

    threading.Thread(
        target=_run_full_pipeline, args=(report_id, twilio_url), daemon=True
    ).start()
    logger.info(f"Background pipeline started for report #{report_id}")


def handle_voice_note(user, media_url: str) -> str:
    """Process voice note — create report and trigger full pipeline in background."""
    from apps.community.models import Report
    from apps.geo_intelligence.models import Village

    village = None
    if user.panchayat:
        village = user.panchayat.villages.first()
    if not village:
        village = Village.objects.first()  # fallback to demo village
    if not village:
        return "Pehle apna gaon set karein. Admin se sampark karein."

    # Use village centroid as default location (WhatsApp voice notes have no GPS)
    location = village.location

    report = Report.objects.create(
        reporter=user,
        village=village,
        description_text='[Voice note - transcription pending]',
        audio_s3_key='pending',
        ward=user.ward or 1,
        location=location,
    )

    # IMPORTANT: Do NOT call _download_media_to_s3 synchronously here.
    # Twilio's webhook timeout is ~15s; the download can take up to 30s.
    # Instead, start the full pipeline (download → S3 → transcribe) in background
    # so we return the confirmation reply to the citizen immediately.
    _start_full_pipeline_async(report.id, media_url)

    return f"Report #{report.id} darj ho gaya! AI transcription jaari hai (~30 sec). {village.name} ke log ab ise upvote kar sakte hain."


def handle_status_query(user) -> str:
    """Return status of user's latest reports."""
    from apps.community.models import Report
    reports = Report.objects.filter(reporter=user).order_by('-created_at')[:3]

    if not reports:
        return "Aapka koi report nahi mila. Voice note ya text bhejkar report banayein."

    lines = ["Aapke haal ke reports:\n"]
    for r in reports:
        status_hindi = {
            'reported': 'Darj', 'adopted': 'Swiikrit', 'in_progress': 'Kaam jaari',
            'completed': 'Poora', 'delayed': 'Deri',
        }.get(r.status, r.status)
        lines.append(f"#{r.id} [{r.category}] - {status_hindi} - {r.vote_count} votes")

    return "\n".join(lines)


def handle_vote(user, report_id: int) -> str:
    """Vote on a report."""
    from apps.community.models import Report, Vote
    from django.db.models import F

    try:
        report = Report.objects.get(id=report_id)
    except Report.DoesNotExist:
        return f"Report #{report_id} nahi mila."

    _, created = Vote.objects.get_or_create(report=report, voter=user)
    if created:
        Report.objects.filter(pk=report.pk).update(vote_count=F('vote_count') + 1)
        report.refresh_from_db()
        return f"Vote darj! Report #{report_id} ke ab {report.vote_count} votes hain."
    return f"Aapne pehle se vote kiya hai. Report #{report_id} ke {report.vote_count} votes hain."


def handle_scheme_query(user, query: str) -> str:
    """Query schemes via RAG."""
    try:
        from apps.scheme_rag.rag_pipeline import query_scheme_rag
        village = None
        if user.panchayat:
            village = user.panchayat.villages.first()
        if not village:
            return "Apna gaon set karein pehle scheme jaankari ke liye."

        result = query_scheme_rag(query=query, village_id=village.id)
        return result.get('answer', 'Koi jaankari nahi mili.')
    except Exception as e:
        logger.error(f"Scheme query error: {e}")
        return "Scheme jaankari abhi uplabdh nahi hai. Baad mein koshish karein."


def handle_text_report(user, text: str) -> str:
    """Create a text-based report."""
    from apps.community.models import Report
    from apps.geo_intelligence.models import Village

    village = None
    if user.panchayat:
        village = user.panchayat.villages.first()
    if not village:
        village = Village.objects.first()  # fallback to demo village
    if not village:
        return "Pehle apna gaon set karein. Admin se sampark karein."

    report = Report.objects.create(
        reporter=user,
        village=village,
        description_text=text,
        description_hindi=text,
        ward=user.ward or 1,
        location=village.location,
    )

    # Trigger categorization via Celery
    try:
        from apps.ai_engine.tasks import categorize_report
        categorize_report.delay(report.id, text)
    except Exception as e:
        logger.warning(f"Celery unavailable for categorization of report #{report.id}: {e}")

    # Notify other village users about the new report
    try:
        from .tasks import notify_village_new_report
        notify_village_new_report.delay(report.id)
    except Exception as e:
        logger.warning(f"Celery unavailable for village notification of report #{report.id}: {e}")

    return f"Report #{report.id} darj ho gaya! {village.name} ke log ab ise upvote kar sakte hain."
