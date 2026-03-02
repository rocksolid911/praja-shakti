"""Firebase Cloud Messaging integration for push notifications."""
import logging

from django.conf import settings

logger = logging.getLogger(__name__)

_firebase_app = None


def _get_firebase_app():
    """Lazily initialize Firebase Admin SDK. Returns app or None if not configured."""
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app

    cred_path = getattr(settings, 'FIREBASE_SERVICE_ACCOUNT_KEY', None)
    if not cred_path:
        logger.warning("FIREBASE_SERVICE_ACCOUNT_KEY not set — FCM disabled")
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        # Avoid double-initialization
        try:
            _firebase_app = firebase_admin.get_app()
        except ValueError:
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)

        logger.info("Firebase Admin SDK initialized")
        return _firebase_app
    except ImportError:
        logger.error("firebase-admin not installed. Run: pip install firebase-admin")
        return None
    except Exception as e:
        logger.error(f"Firebase initialization failed: {e}")
        return None


def send_fcm_to_token(token: str, title: str, body: str, data: dict = None) -> bool:
    """Send FCM notification to a single device token. Returns True on success."""
    app = _get_firebase_app()
    if not app:
        return False

    try:
        from firebase_admin import messaging

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
            android=messaging.AndroidConfig(priority='high'),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound='default')
                )
            ),
        )
        response = messaging.send(message)
        logger.info(f"FCM sent successfully: {response}")
        return True
    except Exception as e:
        # Log invalid tokens so they can be deactivated
        if 'registration-token-not-registered' in str(e) or 'invalid-registration-token' in str(e):
            logger.warning(f"Invalid FCM token (will deactivate): {token[:20]}...")
            _deactivate_token(token)
        else:
            logger.error(f"FCM send failed: {e}")
        return False


def send_fcm_to_user(user_id: int, title: str, body: str, data: dict = None) -> int:
    """Send FCM notification to all active tokens for a user. Returns count of successful sends."""
    from apps.notifications.models import DeviceToken

    tokens = DeviceToken.objects.filter(user_id=user_id, is_active=True)
    success_count = 0
    for device in tokens:
        if send_fcm_to_token(device.token, title, body, data):
            success_count += 1
    return success_count


def _deactivate_token(token: str):
    """Mark a device token as inactive after FCM rejection."""
    try:
        from apps.notifications.models import DeviceToken
        DeviceToken.objects.filter(token=token).update(is_active=False)
    except Exception as e:
        logger.error(f"Failed to deactivate token: {e}")
