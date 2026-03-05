"""Firebase Authentication token verification for auth_service.

Verifies Firebase ID tokens using Google's public keys (RS256 JWTs).
Does NOT require a service account key or Application Default Credentials.

The Firebase Admin SDK's verify_id_token() requires credentials on non-GCP
environments (like AWS ECS). This module uses PyJWT + Google's public certs
directly, which only needs outbound HTTPS access.
"""
import json
import logging
import time
from typing import Optional

import jwt
import requests
from cryptography.x509 import load_pem_x509_certificate

logger = logging.getLogger(__name__)

# Google's public key endpoint for Firebase token verification
_GOOGLE_CERTS_URL = (
    "https://www.googleapis.com/robot/v1/metadata/x509/"
    "securetoken@system.gserviceaccount.com"
)

# Cached public keys: {kid: public_key}
_cached_keys: dict = {}
_cache_expiry: float = 0


def _fetch_google_public_keys() -> dict:
    """Fetch and cache Google's public RSA keys for Firebase token verification."""
    global _cached_keys, _cache_expiry

    now = time.time()
    if _cached_keys and now < _cache_expiry:
        return _cached_keys

    try:
        resp = requests.get(_GOOGLE_CERTS_URL, timeout=10)
        resp.raise_for_status()

        # Parse Cache-Control max-age for cache duration
        cache_control = resp.headers.get("Cache-Control", "")
        max_age = 3600  # default 1 hour
        for part in cache_control.split(","):
            part = part.strip()
            if part.startswith("max-age="):
                try:
                    max_age = int(part.split("=")[1])
                except (ValueError, IndexError):
                    pass

        certs = resp.json()
        keys = {}
        for kid, cert_pem in certs.items():
            cert = load_pem_x509_certificate(cert_pem.encode("utf-8"))
            keys[kid] = cert.public_key()

        _cached_keys = keys
        _cache_expiry = now + max_age
        logger.info(f"Fetched {len(keys)} Google public keys (cache {max_age}s)")
        return keys
    except Exception as e:
        logger.error(f"Failed to fetch Google public keys: {e}")
        return _cached_keys  # return stale cache if available


def verify_firebase_token(id_token: str) -> Optional[dict]:
    """Verify a Firebase ID token and return the decoded claims.

    Validates:
      - RS256 signature against Google's public keys
      - Token expiry (exp) with 5s clock skew allowance
      - Issuer (iss) matches Firebase project
      - Audience (aud) matches Firebase project
      - Subject (sub) is non-empty

    Returns dict with keys like: uid, phone_number, firebase.sign_in_provider, etc.
    Returns None if verification fails.
    """
    from django.conf import settings

    project_id = getattr(settings, "FIREBASE_PROJECT_ID", "praja-shakti")

    try:
        # Get the key ID from JWT header without verifying
        unverified_header = jwt.get_unverified_header(id_token)
        kid = unverified_header.get("kid")
        if not kid:
            logger.warning("Firebase token missing 'kid' header")
            return None

        # Fetch Google's public keys
        keys = _fetch_google_public_keys()
        if not keys:
            logger.error("No Google public keys available")
            return None

        public_key = keys.get(kid)
        if not public_key:
            # Key might have rotated — force refresh
            _force_refresh_keys()
            keys = _fetch_google_public_keys()
            public_key = keys.get(kid)
            if not public_key:
                logger.warning(f"Firebase token kid '{kid}' not found in Google certs")
                return None

        # Verify and decode
        decoded = jwt.decode(
            id_token,
            key=public_key,
            algorithms=["RS256"],
            audience=project_id,
            issuer=f"https://securetoken.google.com/{project_id}",
            leeway=5,  # 5s clock skew allowance
        )

        # Additional checks
        sub = decoded.get("sub", "")
        if not sub:
            logger.warning("Firebase token missing 'sub' claim")
            return None

        # Map 'sub' to 'uid' for compatibility with firebase-admin SDK format
        decoded["uid"] = sub
        return decoded

    except jwt.ExpiredSignatureError:
        logger.warning("Firebase token expired")
        return None
    except jwt.InvalidAudienceError:
        logger.warning(f"Firebase token audience mismatch (expected {project_id})")
        return None
    except jwt.InvalidIssuerError:
        logger.warning("Firebase token issuer mismatch")
        return None
    except jwt.DecodeError as e:
        logger.warning(f"Firebase token decode error: {e}")
        return None
    except Exception as e:
        logger.warning(f"Firebase token verification failed: {e}")
        return None


def _force_refresh_keys():
    """Force a refresh of the cached keys on next fetch."""
    global _cache_expiry
    _cache_expiry = 0


def extract_phone_from_firebase(decoded_token: dict) -> Optional[str]:
    """Extract and normalize phone number from Firebase token claims.

    Firebase stores phone as '+919090291939'. We normalize to '9090291939'
    using the same normalize_phone() that the rest of the backend uses.
    """
    phone = decoded_token.get("phone_number")
    if not phone:
        return None

    from .utils import normalize_phone

    return normalize_phone(phone)
