from .base import *  # noqa: F401,F403
import os

DEBUG = False

# SSL — disabled by default (ALB handles HTTPS termination in AWS)
SECURE_SSL_REDIRECT = env.bool('SECURE_SSL_REDIRECT', default=False)  # noqa: F405
SESSION_COOKIE_SECURE = env.bool('SESSION_COOKIE_SECURE', default=False)  # noqa: F405
CSRF_COOKIE_SECURE = env.bool('CSRF_COOKIE_SECURE', default=False)  # noqa: F405
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True

# Trust ALB forwarded headers
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
USE_X_FORWARDED_HOST = True

# CORS — allow all for hackathon demo (tighten before production)
CORS_ALLOW_ALL_ORIGINS = env.bool('CORS_ALLOW_ALL_ORIGINS', default=True)  # noqa: F405
CORS_ALLOWED_ORIGINS = env.list('CORS_ALLOWED_ORIGINS', default=[])  # noqa: F405

# Static files served by WhiteNoise
MIDDLEWARE = ['whitenoise.middleware.WhiteNoiseMiddleware'] + MIDDLEWARE  # noqa: F405
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Logging to stdout for CloudWatch
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': os.getenv('DJANGO_LOG_LEVEL', 'INFO'),
            'propagate': False,
        },
    },
}
