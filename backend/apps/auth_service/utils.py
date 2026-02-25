import random
import logging
from datetime import timedelta

from django.conf import settings
from django.utils import timezone

from .models import OTPVerification

logger = logging.getLogger(__name__)


def generate_otp():
    return str(random.randint(100000, 999999))


def send_otp(phone: str) -> str:
    otp = generate_otp()
    expires_at = timezone.now() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)

    OTPVerification.objects.create(
        phone=phone,
        otp=otp,
        expires_at=expires_at,
    )

    # In production, send via AWS SNS or Twilio
    # For hackathon, log to console
    logger.info(f"OTP for {phone}: {otp}")

    return otp


def verify_otp(phone: str, otp: str) -> bool:
    try:
        record = OTPVerification.objects.filter(
            phone=phone,
            otp=otp,
            is_used=False,
            expires_at__gt=timezone.now(),
        ).latest('created_at')
        record.is_used = True
        record.save()
        return True
    except OTPVerification.DoesNotExist:
        return False
