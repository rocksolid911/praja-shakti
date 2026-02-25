import logging
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)
User = get_user_model()

HELP_TEXT_HINDI = """PrajaShakti AI - Aapka Gaon, Aapki Awaaz

Commands:
- Voice note bhejein: Report banaye
- "Status" ya "Mera report": Apne report ka status dekhein
- "Vote 123": Report #123 ko upvote karein
- Scheme ka naam (e.g., "PM-KUSUM"): Eligibility jaanein
- "Help": Ye help message

Aapki awaaz sunai jayegi!"""


def handle_whatsapp_message(phone: str, body: str, media_url: str = '', media_type: str = '') -> str:
    """Process incoming WhatsApp message and return response text."""

    # Check if user exists
    try:
        user = User.objects.get(phone=phone)
    except User.DoesNotExist:
        user = User.objects.create_user(
            username=phone, phone=phone, role='citizen',
        )

    body_lower = body.strip().lower()

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


def handle_voice_note(user, media_url: str) -> str:
    """Process voice note — create report and trigger transcription."""
    from apps.community.models import Report

    village = None
    if user.panchayat:
        village = user.panchayat.villages.first()

    if not village:
        return "Pehle apna gaon set karein. Admin se sampark karein."

    report = Report.objects.create(
        reporter=user,
        village=village,
        description_text='[Voice note - transcription pending]',
        audio_s3_key=media_url,
        ward=user.ward,
    )

    # Trigger async transcription
    try:
        from apps.ai_engine.tasks import transcribe_voice_note
        transcribe_voice_note.delay(report.id, media_url)
    except Exception:
        pass

    return f"Report #{report.id} darj ho gaya! AI transcription jaari hai. {report.village.name} ke log ab ise upvote kar sakte hain."


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

    village = None
    if user.panchayat:
        village = user.panchayat.villages.first()

    if not village:
        return "Pehle apna gaon set karein. Admin se sampark karein."

    report = Report.objects.create(
        reporter=user,
        village=village,
        description_text=text,
        description_hindi=text,
        ward=user.ward,
    )

    # Trigger categorization
    try:
        from apps.ai_engine.tasks import categorize_report
        categorize_report.delay(report.id, text)
    except Exception:
        pass

    return f"Report #{report.id} darj ho gaya! {village.name} ke log ab ise upvote kar sakte hain."
