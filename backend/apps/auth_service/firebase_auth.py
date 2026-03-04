"""Firebase Authentication token verification for auth_service.

Tries to reuse the Firebase Admin SDK app from notifications.firebase.
Falls back to initialising a minimal app with just the project ID
(sufficient for verify_id_token in development).
"""
import logging

logger = logging.getLogger(__name__)

_auth_firebase_app = None


def _get_or_init_firebase_app():
    """Return a Firebase Admin app, creating one if necessary.

    Priority:
      1. App already cached in this module
      2. App from notifications.firebase (uses service-account key → full FCM)
      3. Fallback: initialise with project ID only (enough for token verification)
    """
    global _auth_firebase_app
    if _auth_firebase_app is not None:
        return _auth_firebase_app

    # Try the shared FCM app first
    try:
        from apps.notifications.firebase import _get_firebase_app
        app = _get_firebase_app()
        if app:
            _auth_firebase_app = app
            return _auth_firebase_app
    except Exception:
        pass

    # Fallback: init with project ID only (no service-account key needed)
    try:
        import firebase_admin

        # If any app was already initialised (e.g. by FCM), reuse it
        try:
            _auth_firebase_app = firebase_admin.get_app()
            return _auth_firebase_app
        except ValueError:
            pass

        # Minimal init — enough for auth.verify_id_token()
        from django.conf import settings
        project_id = getattr(settings, 'FIREBASE_PROJECT_ID', 'praja-shakti')
        _auth_firebase_app = firebase_admin.initialize_app(
            options={'projectId': project_id}
        )
        logger.info(f"Firebase Admin SDK initialised (project={project_id}, no credentials)")
        return _auth_firebase_app
    except ImportError:
        logger.error("firebase-admin not installed")
        return None
    except Exception as e:
        logger.error(f"Firebase Admin init failed: {e}")
        return None


def verify_firebase_token(id_token: str) -> dict | None:
    """Verify a Firebase ID token and return the decoded claims.

    Returns dict with keys like: uid, phone_number (optional),
    firebase.sign_in_provider, etc.
    Returns None if verification fails.
    """
    try:
        app = _get_or_init_firebase_app()
        if not app:
            logger.error("Firebase app not initialized — cannot verify token")
            return None

        from firebase_admin import auth

        decoded = auth.verify_id_token(id_token, app=app, clock_skew_seconds=5)
        return decoded
    except ImportError:
        logger.error("firebase-admin not installed")
        return None
    except Exception as e:
        logger.warning(f"Firebase token verification failed: {e}")
        return None


def extract_phone_from_firebase(decoded_token: dict) -> str | None:
    """Extract and normalize phone number from Firebase token claims.

    Firebase stores phone as '+919090291939'. We normalize to '9090291939'
    using the same normalize_phone() that the rest of the backend uses.
    """
    phone = decoded_token.get('phone_number')
    if not phone:
        return None

    from .utils import normalize_phone

    return normalize_phone(phone)
