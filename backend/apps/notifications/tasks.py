"""Notification tasks."""
import logging
from celery import shared_task
from django.conf import settings

logger = logging.getLogger(__name__)


@shared_task
def send_push_notification(user_id: int, title: str, message: str, data: dict = None):
    """Send push notification via Firebase Cloud Messaging."""
    from apps.notifications.models import Notification
    from apps.notifications.firebase import send_fcm_to_user
    from django.contrib.auth import get_user_model
    User = get_user_model()

    try:
        user = User.objects.get(id=user_id)
        Notification.objects.create(
            user=user, channel='push', title=title, message=message, data=data,
        )
        sent = send_fcm_to_user(user_id, title, message, data)
        logger.info(f"Push notification to user #{user_id}: '{title}' — {sent} device(s) reached")
    except Exception as e:
        logger.error(f"Push notification failed for user #{user_id}: {e}")


@shared_task
def send_whatsapp_message(phone: str, message: str):
    """Send WhatsApp message via Twilio."""
    from apps.notifications.models import Notification
    from django.contrib.auth import get_user_model
    User = get_user_model()

    try:
        if settings.TWILIO_ACCOUNT_SID:
            from twilio.rest import Client
            client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
            client.messages.create(
                body=message,
                from_=settings.TWILIO_WHATSAPP_NUMBER,
                to=f'whatsapp:{phone}',
            )

        user = User.objects.filter(phone=phone).first()
        if user:
            Notification.objects.create(
                user=user, channel='whatsapp', title='WhatsApp', message=message,
            )
        logger.info(f"WhatsApp message sent to {phone}")
    except Exception as e:
        logger.error(f"WhatsApp message failed: {e}")


@shared_task
def notify_village_new_report(report_id: int):
    """
    Notify all users in the same panchayat about a new community report.
    Excludes the reporter themselves. Fires one send_whatsapp_message task per user.
    """
    from apps.community.models import Report
    from django.contrib.auth import get_user_model
    User = get_user_model()

    try:
        report = Report.objects.select_related(
            'village__panchayat', 'reporter'
        ).get(id=report_id)
    except Report.DoesNotExist:
        logger.warning(f"notify_village_new_report: report #{report_id} not found")
        return

    panchayat = report.village.panchayat if report.village else None
    if not panchayat:
        logger.info(f"Report #{report_id} has no panchayat — skipping village notification")
        return

    phones = list(
        User.objects.filter(panchayat=panchayat)
        .exclude(id=report.reporter_id)
        .values_list('phone', flat=True)
    )
    if not phones:
        logger.info(f"No other users in panchayat #{panchayat.id} — nothing to notify")
        return

    category_labels = {
        'water': 'Paani', 'road': 'Rasta', 'health': 'Swasthya',
        'education': 'Shiksha', 'electricity': 'Bijli',
        'sanitation': 'Safai', 'other': 'Anya',
    }
    category = category_labels.get(report.category, report.category or 'Samasya')
    desc = (report.description_text or '').strip()
    short_desc = (desc[:60] + '...') if len(desc) > 60 else desc
    village_name = report.village.name if report.village else 'aapka gaon'

    message = (
        f"\U0001f195 *PrajaShakti: Nayi Samasya Report!*\n\n"
        f"\U0001f4cb *{category}:* {short_desc}\n"
        f"\U0001f4cd Gram: {village_name}\n"
        f"\U0001f194 Report #{report.id}\n\n"
        f"Is samasya ko support karne ke liye vote karein!\n"
        f"App kholen ya reply karein:\n"
        f"*VOTE {report.id}*"
    )

    for phone in phones:
        send_whatsapp_message.delay(phone, message)

    logger.info(
        f"Queued WhatsApp notification for report #{report_id} "
        f"to {len(phones)} user(s) in panchayat #{panchayat.id}"
    )
