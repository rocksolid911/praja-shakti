import hashlib
import hmac
import logging

from django.conf import settings
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .whatsapp_bot import handle_whatsapp_message

logger = logging.getLogger(__name__)


def verify_twilio_signature(request):
    """Verify that the request came from Twilio."""
    if not settings.TWILIO_AUTH_TOKEN:
        return True  # Skip verification in dev

    try:
        from twilio.request_validator import RequestValidator
        validator = RequestValidator(settings.TWILIO_AUTH_TOKEN)
        url = request.build_absolute_uri()
        signature = request.META.get('HTTP_X_TWILIO_SIGNATURE', '')
        return validator.validate(url, request.data, signature)
    except ImportError:
        logger.warning("twilio package not installed, skipping signature verification")
        return True


@api_view(['POST'])
@permission_classes([AllowAny])
def whatsapp_webhook(request):
    """Receive WhatsApp messages from Twilio."""
    if not verify_twilio_signature(request):
        return Response({'error': 'Invalid signature'}, status=403)

    from_number = request.data.get('From', '')
    body = request.data.get('Body', '')
    media_url = request.data.get('MediaUrl0', '')
    media_type = request.data.get('MediaContentType0', '')

    logger.info(f"WhatsApp message from {from_number}: {body[:50]}")

    response_text = handle_whatsapp_message(
        phone=from_number.replace('whatsapp:', ''),
        body=body,
        media_url=media_url,
        media_type=media_type,
    )

    # Return TwiML response
    twiml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Message>{response_text}</Message>
</Response>"""

    return Response(twiml, content_type='text/xml')
