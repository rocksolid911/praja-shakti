"""Shared utilities used across multiple Django apps."""
import logging

logger = logging.getLogger(__name__)

# Cache Redis availability for 30 seconds to avoid repeated pings
_redis_available_cache: dict = {'value': None, 'expires': 0}


def is_redis_available() -> bool:
    """
    Check Redis (Celery broker) connectivity with a 0.5s timeout.
    Caches the result for 30 seconds to avoid a ping on every request.
    Returns False immediately if Redis is down — never blocks > 0.5s.
    """
    import time
    now = time.monotonic()
    if _redis_available_cache['value'] is not None and now < _redis_available_cache['expires']:
        return _redis_available_cache['value']

    try:
        import redis as redis_lib
        from django.conf import settings
        url = getattr(settings, 'CELERY_BROKER_URL', 'redis://127.0.0.1:6379/0')
        r = redis_lib.from_url(url, socket_connect_timeout=0.5, socket_timeout=0.5)
        r.ping()
        available = True
    except Exception:
        available = False

    _redis_available_cache['value'] = available
    _redis_available_cache['expires'] = now + 30  # re-check every 30 seconds
    if not available:
        logger.debug('Redis unavailable — Celery tasks will use thread fallback')
    return available


def dispatch_task(task_func, *args, fallback=None, **kwargs):
    """
    Dispatch a Celery task, falling back to a background thread if Redis is down.

    Usage:
        dispatch_task(my_task, arg1, arg2, fallback=my_sync_func)
        # If fallback is None, the task is silently skipped when Redis is down.
    """
    if is_redis_available():
        try:
            task_func.delay(*args, **kwargs)
            return
        except Exception as e:
            logger.warning(f'Celery dispatch failed ({e}), trying fallback')

    if fallback is not None:
        import threading
        threading.Thread(target=fallback, args=args, kwargs=kwargs, daemon=True).start()
    else:
        logger.warning(f'No fallback for {task_func.__name__} — task skipped (Redis down)')
