import hashlib
import hmac
import logging
from html import escape

from django.conf import settings
from django.http import HttpResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from .whatsapp_bot import handle_whatsapp_message

logger = logging.getLogger(__name__)


def verify_twilio_signature(request):
    """Verify that the request came from Twilio."""
    if settings.DEBUG:
        return True  # Skip in development — Twilio can't sign local/ngrok requests

    if not settings.TWILIO_AUTH_TOKEN:
        return True

    try:
        from twilio.request_validator import RequestValidator
        validator = RequestValidator(settings.TWILIO_AUTH_TOKEN)

        # Build the URL Twilio actually called — ngrok uses https but Django
        # may reconstruct http:// without SECURE_PROXY_SSL_HEADER set.
        url = request.build_absolute_uri()
        if request.META.get('HTTP_X_FORWARDED_PROTO') == 'https':
            url = url.replace('http://', 'https://', 1)

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

    try:
        response_text = handle_whatsapp_message(
            phone=from_number.replace('whatsapp:', ''),
            body=body,
            media_url=media_url,
            media_type=media_type,
        )
    except Exception as e:
        logger.error(f"WhatsApp handler error for {from_number}: {e}", exc_info=True)
        response_text = "Kuch galat ho gaya. Thodi der baad phir koshish karein."

    # Return raw TwiML XML — must use HttpResponse not DRF Response,
    # otherwise DRF JSON-encodes the string and Twilio can't parse it.
    twiml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Message>{escape(response_text)}</Message>
</Response>"""

    return HttpResponse(twiml, content_type='text/xml')


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_device_token(request):
    """Register an FCM device token for push notifications."""
    from .models import DeviceToken

    token = request.data.get('token', '').strip()
    platform = request.data.get('platform', 'android')

    if not token:
        return Response({'error': 'token is required'}, status=400)
    if platform not in ('android', 'ios', 'web'):
        return Response({'error': 'platform must be android, ios, or web'}, status=400)

    obj, created = DeviceToken.objects.update_or_create(
        user=request.user, token=token,
        defaults={'platform': platform, 'is_active': True},
    )
    return Response({'registered': True, 'created': created})


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def deregister_device_token(request):
    """Deactivate an FCM device token (on logout)."""
    from .models import DeviceToken

    token = request.data.get('token', '').strip()
    if not token:
        return Response({'error': 'token is required'}, status=400)

    DeviceToken.objects.filter(user=request.user, token=token).update(is_active=False)
    return Response({'deregistered': True})
