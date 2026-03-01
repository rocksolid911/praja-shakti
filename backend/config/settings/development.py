from .base import *  # noqa: F401,F403

DEBUG = True

# ── Celery: fail-fast when Redis is unavailable ───────────────────────────────
# Without these, .delay() blocks for ~20 s retrying before falling back to thread.
CELERY_BROKER_TRANSPORT_OPTIONS = {
    'socket_connect_timeout': 1,   # give up connecting after 1 second
    'socket_timeout': 1,
}
CELERY_RESULT_BACKEND_TRANSPORT_OPTIONS = {
    'socket_connect_timeout': 1,
    'socket_timeout': 1,
}
# Do NOT retry on startup — fail fast so the thread fallback kicks in immediately
CELERY_BROKER_CONNECTION_RETRY_ON_STARTUP = False

ALLOWED_HOSTS = ['*']

CORS_ALLOW_ALL_ORIGINS = True

EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# More verbose logging in development
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
            'level': 'INFO',
            'propagate': False,
        },
        'apps': {
            'handlers': ['console'],
            'level': 'DEBUG',
            'propagate': False,
        },
    },
}
