"""Scheduled data ingestion tasks."""
import logging
from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task
def sync_agmarknet_prices():
    """Daily: Fetch mandi prices from Agmarknet."""
    logger.info("Starting Agmarknet price sync")
    # Implementation would scrape agmarknet.gov.in
    # For hackathon, uses demo data


@shared_task
def sync_egram_swaraj():
    """Weekly: Fetch panchayat financial data from eGramSwaraj."""
    logger.info("Starting eGramSwaraj sync")


@shared_task
def refresh_bhuvan_ndvi():
    """Weekly: Refresh satellite NDVI tiles from Bhuvan ISRO."""
    logger.info("Starting Bhuvan NDVI refresh")


@shared_task
def sync_cgwb_groundwater():
    """Quarterly: Fetch groundwater levels from CGWB."""
    logger.info("Starting CGWB groundwater sync")


@shared_task
def detect_delayed_projects():
    """Daily: Flag projects that are behind schedule."""
    from django.utils import timezone
    from apps.projects.models import Project

    behind = Project.objects.filter(
        status='in_progress',
        expected_completion__lt=timezone.now().date(),
    )
    count = behind.update(status='delayed')
    logger.info(f"Flagged {count} delayed projects")
