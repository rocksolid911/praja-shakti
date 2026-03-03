from .base import *  # noqa: F401,F403

DEBUG = False

# Tell Django it's behind an HTTPS proxy (ALB / CloudFront).
# Without this Django would try to redirect HTTP→HTTPS itself and
# Twilio webhooks (which come in as HTTP internally) would get a 301.
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SECURE_SSL_REDIRECT = False  # ALB handles TLS termination; internal traffic is HTTP

SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True

CORS_ALLOWED_ORIGINS = env.list('CORS_ALLOWED_ORIGINS', default=[])  # noqa: F405
