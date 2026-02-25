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
