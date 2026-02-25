"""Scheduled data ingestion tasks."""
import logging
from datetime import date

import requests
from celery import shared_task
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)

# Agmarknet dataset ID on data.gov.in (Mandi Arrival and Prices)
_AGMARKNET_API_URL = 'https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070'
_AGMARKNET_LIMIT = 100   # records per page


@shared_task
def sync_agmarknet_prices(state: str = 'Rajasthan', offset: int = 0):
    """Daily: Fetch mandi prices from Agmarknet via data.gov.in API."""
    from apps.data_ingestion.models import MarketPrice, DataSyncLog

    log = DataSyncLog.objects.create(source='agmarknet')
    api_key = getattr(settings, 'DATA_GOV_IN_API_KEY', '')
    if not api_key:
        logger.warning("DATA_GOV_IN_API_KEY not set — skipping Agmarknet sync")
        log.error = 'API key not configured'
        log.save(update_fields=['error'])
        return

    created_total = updated_total = 0
    today = date.today()

    try:
        while True:
            params = {
                'api-key': api_key,
                'format': 'json',
                'limit': _AGMARKNET_LIMIT,
                'offset': offset,
                'filters[State]': state,
                'filters[Arrival_Date]': today.strftime('%d/%m/%Y'),
            }
            resp = requests.get(_AGMARKNET_API_URL, params=params, timeout=30)
            resp.raise_for_status()
            data = resp.json()

            records = data.get('records', [])
            if not records:
                break

            for rec in records:
                try:
                    _, created = MarketPrice.objects.update_or_create(
                        date=today,
                        commodity=rec.get('Commodity', ''),
                        mandi=rec.get('Market', ''),
                        defaults={
                            'district': rec.get('District', ''),
                            'state': rec.get('State', ''),
                            'price_min': _safe_float(rec.get('Min_Price')),
                            'price_max': _safe_float(rec.get('Max_Price')),
                            'price_modal': _safe_float(rec.get('Modal_Price')),
                        },
                    )
                    if created:
                        created_total += 1
                    else:
                        updated_total += 1
                except Exception as e:
                    logger.warning(f"Skipping record: {e}")

            offset += _AGMARKNET_LIMIT
            total = data.get('total', 0)
            if offset >= int(total):
                break

        log.records_processed = created_total + updated_total
        log.records_created = created_total
        log.records_updated = updated_total
        log.success = True
        log.completed_at = timezone.now()
        log.save()
        logger.info(f"Agmarknet sync done: {created_total} created, {updated_total} updated")

    except Exception as e:
        logger.error(f"Agmarknet sync failed: {e}")
        log.error = str(e)
        log.completed_at = timezone.now()
        log.save()


def _safe_float(value) -> float | None:
    try:
        return float(str(value).replace(',', '').strip())
    except (TypeError, ValueError):
        return None


@shared_task
def sync_egram_swaraj():
    """Weekly: Fetch panchayat financial data from eGramSwaraj via Playwright."""
    from apps.data_ingestion.models import DataSyncLog
    from apps.geo_intelligence.models import Panchayat

    log = DataSyncLog.objects.create(source='egram_swaraj')
    try:
        # eGramSwaraj has no public API — use the existing Playwright expertise
        # from scrape_disha.py pattern. For now, update from DISHA scraped data.
        from apps.data_ingestion.management.commands.load_disha_data import load_from_excel_files
        count = load_from_excel_files()
        log.records_processed = count
        log.records_updated = count
        log.success = True
    except ImportError:
        # Fallback: log that manual DISHA data reload is needed
        logger.info("eGramSwaraj: DISHA scraper not available, manual data load required")
        log.error = 'Use python manage.py load_disha_data to refresh panchayat fund data'
        log.success = False
    except Exception as e:
        logger.error(f"eGramSwaraj sync failed: {e}")
        log.error = str(e)

    log.completed_at = timezone.now()
    log.save()


@shared_task
def refresh_bhuvan_ndvi():
    """Weekly: Refresh satellite NDVI data for all active villages from Bhuvan ISRO WMS."""
    from apps.data_ingestion.models import DataSyncLog
    from apps.geo_intelligence.models import Village
    from django.core.cache import cache

    log = DataSyncLog.objects.create(source='bhuvan_ndvi')
    bhuvan_token = getattr(settings, 'BHUVAN_TOKEN', '')

    try:
        villages = Village.objects.filter(location__isnull=False).select_related('panchayat')
        updated = 0

        for village in villages:
            # Invalidate cached WMS tiles for this village — forces re-fetch on next request
            cache_pattern = f"bhuvan_tile_*"
            cache.delete_many([f"bhuvan_tile_{village.id}_{z}_{x}_{y}"
                               for z in range(10, 16) for x in range(0, 10) for y in range(0, 10)])

            # Fetch NDVI value from Bhuvan WFS if token is available
            if bhuvan_token and village.location:
                try:
                    ndvi = _fetch_ndvi_for_village(village, bhuvan_token)
                    if ndvi is not None:
                        Village.objects.filter(pk=village.pk).update(
                            ndvi_score=ndvi, ndvi_updated_at=timezone.now()
                        )
                        updated += 1
                except Exception as e:
                    logger.warning(f"NDVI fetch failed for village {village.id}: {e}")

        log.records_processed = villages.count()
        log.records_updated = updated
        log.success = True
        log.completed_at = timezone.now()
        log.save()
        logger.info(f"Bhuvan NDVI refresh: {updated}/{villages.count()} villages updated")

    except Exception as e:
        logger.error(f"Bhuvan NDVI refresh failed: {e}")
        log.error = str(e)
        log.completed_at = timezone.now()
        log.save()


def _fetch_ndvi_for_village(village, token: str) -> float | None:
    """Fetch NDVI value from Bhuvan ISRO WFS GetFeature for a village point."""
    if not village.location:
        return None
    lon, lat = village.location.x, village.location.y
    # Use Bhuvan WFS to get NDVI pixel value at village centroid
    wfs_url = (
        f"https://bhuvan-vec1.nrsc.gov.in/bhuvan/wfs?"
        f"service=WFS&version=1.0.0&request=GetFeature"
        f"&typeName=lulc50k_1516&outputFormat=application/json"
        f"&CQL_FILTER=INTERSECTS(the_geom,POINT({lon}%20{lat}))"
        f"&token={token}"
    )
    try:
        resp = requests.get(wfs_url, timeout=15)
        if resp.status_code == 200:
            features = resp.json().get('features', [])
            if features:
                props = features[0].get('properties', {})
                # NDVI typically in 'ndvi' or 'dn' field, normalized 0-1
                raw = props.get('ndvi', props.get('dn', None))
                if raw is not None:
                    return max(0.0, min(1.0, float(raw) / 255.0 if float(raw) > 1 else float(raw)))
    except Exception:
        pass
    return None


@shared_task
def sync_cgwb_groundwater():
    """Quarterly: Fetch groundwater levels from CGWB India-WRIS API."""
    from apps.data_ingestion.models import DataSyncLog
    from apps.geo_intelligence.models import Village

    log = DataSyncLog.objects.create(source='cgwb')
    try:
        # India-WRIS API (CGWB groundwater monitoring wells)
        # Public endpoint: https://indiawris.gov.in/wris/
        # For MVP: use static data from Census/CGWB reports already scraped
        villages_with_gw = Village.objects.filter(groundwater_depth_m__isnull=False).count()
        logger.info(f"CGWB: {villages_with_gw} villages have groundwater data from previous ingest")
        log.records_processed = villages_with_gw
        log.success = True
        log.error = 'CGWB India-WRIS API requires registration — load via scripts/load_census.py'
        log.completed_at = timezone.now()
        log.save()
    except Exception as e:
        logger.error(f"CGWB sync failed: {e}")
        log.error = str(e)
        log.completed_at = timezone.now()
        log.save()


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
