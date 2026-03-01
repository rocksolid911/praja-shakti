import random
import logging
from datetime import timedelta

from django.conf import settings
from django.utils import timezone

from .models import OTPVerification

logger = logging.getLogger(__name__)


def normalize_phone(phone: str) -> str:
    """Return the canonical 10-digit Indian mobile number.

    Strips +91 / 91 country code prefix so that '+919090291939',
    '919090291939', and '9090291939' all map to '9090291939'.
    """
    digits = ''.join(c for c in (phone or '') if c.isdigit())
    # 12-digit number starting with 91 → strip country code
    if len(digits) == 12 and digits.startswith('91'):
        return digits[2:]
    # 11-digit number starting with 0 (trunk prefix) → strip trunk
    if len(digits) == 11 and digits.startswith('0'):
        return digits[1:]
    # Truncate to last 10 digits if longer than expected
    return digits[-10:] if len(digits) > 10 else digits


def generate_otp():
    return str(random.randint(100000, 999999))


def send_otp(phone: str) -> str:
    phone = normalize_phone(phone)
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
    phone = normalize_phone(phone)
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
