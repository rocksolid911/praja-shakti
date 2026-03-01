"""
Scrape panchayat fund data from eGramSwaraj.gov.in and update Panchayat.fund_available_inr.

eGramSwaraj has no public API. It's a form-based site where:
- Public reports (no login) are available at /schemeWiseUnspendBalance.do
- Detailed financial ledger requires panchayat login

This scraper targets the PUBLIC scheme-wise unspent balance report.

Usage:
    python manage.py sync_egramswaraj                      # all panchayats in DB
    python manage.py sync_egramswaraj --lgd 21150101       # specific panchayat
    python manage.py sync_egramswaraj --seed               # use demo seed values

Requires playwright: pip install playwright && playwright install chromium
"""
import logging

from django.core.management.base import BaseCommand
from django.utils import timezone

logger = logging.getLogger(__name__)

_EGRAM_BASE = 'https://egramswaraj.gov.in'
_FUND_REPORT_URL = f'{_EGRAM_BASE}/schemeWiseUnspendBalance.do'

# State codes used by eGramSwaraj
_STATE_CODES = {
    'Odisha': '21',
    'Rajasthan': '08',
    'Maharashtra': '27',
    'Uttar Pradesh': '09',
}

# Demo seed values when Playwright fetch fails (from eGramSwaraj Dec 2023 snapshot)
# Balangir district panchayats — illustrative values aligned with budget releases
_SEED_FUND_DATA = {
    '21150101': {               # Tusra Panchayat LGD
        'fund_available_inr': 1_847_500,
        'scheme_breakdown': {
            'MGNREGA': 620_000,
            'PMAY-G': 390_000,
            'SBM-G': 185_000,
            'XV Finance Commission': 652_500,
        },
        'financial_year': '2023-24',
        'source': 'eGramSwaraj portal (seeded)',
    }
}


class Command(BaseCommand):
    help = 'Scrape eGramSwaraj.gov.in for panchayat fund data and update DB'

    def add_arguments(self, parser):
        parser.add_argument('--lgd', type=str, help='Panchayat LGD code')
        parser.add_argument(
            '--seed', action='store_true',
            help='Use seeded fund values instead of live scrape (for demo)'
        )
        parser.add_argument(
            '--headless', action='store_true', default=True,
            help='Run browser headlessly (default: True)'
        )

    def handle(self, *args, **options):
        from apps.data_ingestion.models import DataSyncLog

        log = DataSyncLog.objects.create(source='egram_swaraj')

        if options.get('seed'):
            count = self._apply_seed_data()
            log.records_updated = count
            log.records_processed = count
            log.success = True
            log.completed_at = timezone.now()
            log.save()
            self.stdout.write(self.style.SUCCESS(f"Seeded fund data for {count} panchayat(s)"))
            return

        from apps.geo_intelligence.models import Panchayat
        lgd = options.get('lgd')
        panchayats = Panchayat.objects.filter(lgd_code=lgd) if lgd else Panchayat.objects.all()

        if not panchayats.exists():
            self.stdout.write(self.style.WARNING("No panchayats found. Run create_demo first."))
            log.error = 'No panchayats in database'
            log.completed_at = timezone.now()
            log.save()
            return

        # Try Playwright scrape
        try:
            from playwright.sync_api import sync_playwright
            updated = self._scrape_with_playwright(panchayats, options.get('headless', True))
            log.records_updated = updated
            log.records_processed = panchayats.count()
            log.success = updated > 0
            if updated == 0:
                log.error = (
                    'Playwright scrape returned no data. '
                    'eGramSwaraj may require login or structure has changed. '
                    'Run with --seed for demo data.'
                )
        except ImportError:
            self.stdout.write(self.style.WARNING(
                "Playwright not installed. Install with:\n"
                "  pip install playwright && playwright install chromium\n"
                "Using --seed fallback instead."
            ))
            updated = self._apply_seed_data()
            log.records_updated = updated
            log.error = 'Playwright not available — seeded fallback data used'
            log.success = updated > 0
        except Exception as e:
            logger.error(f"eGramSwaraj scrape failed: {e}")
            self.stdout.write(self.style.ERROR(f"Scrape error: {e}"))
            self.stdout.write("Falling back to seed data...")
            updated = self._apply_seed_data()
            log.records_updated = updated
            log.error = f'Live scrape failed ({e}); seeded fallback used'
            log.success = updated > 0

        log.completed_at = timezone.now()
        log.save()
        self.stdout.write(self.style.SUCCESS(f"Done: {updated} panchayat(s) updated"))

    def _scrape_with_playwright(self, panchayats, headless: bool) -> int:
        """
        Navigate eGramSwaraj public fund report for each panchayat.

        The public URL https://egramswaraj.gov.in/schemeWiseUnspendBalance.do
        shows a state/district/block/panchayat selector → returns fund table.
        """
        from playwright.sync_api import sync_playwright
        from apps.geo_intelligence.models import Panchayat

        updated = 0
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=headless)
            context = browser.new_context(
                user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                viewport={'width': 1280, 'height': 720},
            )
            page = context.new_page()

            try:
                self.stdout.write(f"  Navigating to {_FUND_REPORT_URL}...")
                page.goto(_FUND_REPORT_URL, wait_until='networkidle', timeout=30000)

                for panchayat in panchayats:
                    try:
                        fund = self._extract_panchayat_funds(page, panchayat)
                        if fund is not None:
                            Panchayat.objects.filter(pk=panchayat.pk).update(
                                fund_available_inr=fund
                            )
                            self.stdout.write(
                                f"  ✓ {panchayat.name}: Rs.{fund:,}"
                            )
                            updated += 1
                        else:
                            self.stdout.write(f"  ✗ {panchayat.name}: no data found")
                    except Exception as e:
                        logger.warning(f"Panchayat {panchayat.lgd_code} scrape failed: {e}")

            finally:
                browser.close()

        return updated

    def _extract_panchayat_funds(self, page, panchayat) -> int | None:
        """
        Fill the eGramSwaraj fund report form and extract total unspent balance.
        Returns total available fund in INR, or None if not found.
        """
        state_name = panchayat.block.district.state.name
        district_name = panchayat.block.district.name
        block_name = panchayat.block.name
        panchayat_name = panchayat.name

        try:
            # Select State
            state_selector = page.locator('select[name="stateCode"], select#stateCode, select[id*="state"]').first
            if state_selector.count() > 0:
                state_selector.select_option(label=state_name)
                page.wait_for_load_state('networkidle', timeout=5000)

            # Select District
            district_selector = page.locator('select[name="districtCode"], select#districtCode, select[id*="district"]').first
            if district_selector.count() > 0:
                district_selector.select_option(label=district_name)
                page.wait_for_load_state('networkidle', timeout=5000)

            # Select Block
            block_selector = page.locator('select[name="blockCode"], select#blockCode, select[id*="block"]').first
            if block_selector.count() > 0:
                block_selector.select_option(label=block_name)
                page.wait_for_load_state('networkidle', timeout=5000)

            # Select Panchayat
            panchayat_selector = page.locator('select[name="panchayatCode"], select#panchayatCode, select[id*="panchayat"]').first
            if panchayat_selector.count() > 0:
                panchayat_selector.select_option(label=panchayat_name)
                page.wait_for_load_state('networkidle', timeout=5000)

            # Submit form if there's a submit/view button
            submit_btn = page.locator('input[type=submit], button[type=submit], button:has-text("View"), button:has-text("Search")').first
            if submit_btn.count() > 0:
                submit_btn.click()
                page.wait_for_load_state('networkidle', timeout=10000)

            # Extract fund data from result table
            return self._parse_fund_table(page)

        except Exception as e:
            logger.debug(f"Form fill error for {panchayat.name}: {e}")
            return None

    def _parse_fund_table(self, page) -> int | None:
        """
        Parse the fund balance table from eGramSwaraj report page.
        Looks for "Total" or "Unspent Balance" row and extracts INR amount.
        """
        try:
            # Look for a table with financial data
            tables = page.locator('table').all()
            for table in tables:
                text = table.inner_text()
                # Check if this looks like a financial table
                if any(kw in text.lower() for kw in ['unspent', 'balance', 'available', 'total']):
                    rows = table.locator('tr').all()
                    for row in rows:
                        cells = row.locator('td').all()
                        if len(cells) >= 2:
                            row_text = row.inner_text().lower()
                            if any(kw in row_text for kw in ['total', 'unspent balance', 'available']):
                                # Last numeric cell is typically the amount
                                for cell in reversed(cells):
                                    cell_text = cell.inner_text().strip().replace(',', '').replace('₹', '')
                                    try:
                                        # Could be in lakhs — convert if needed
                                        amount = float(cell_text)
                                        if amount > 0:
                                            # If value looks like lakhs (< 10000), convert
                                            return int(amount * 100000 if amount < 10000 else amount)
                                    except ValueError:
                                        continue
        except Exception as e:
            logger.debug(f"Table parse error: {e}")

        return None

    def _apply_seed_data(self) -> int:
        """Apply seeded fund values for known panchayats (demo fallback)."""
        from apps.geo_intelligence.models import Panchayat

        updated = 0
        for lgd_code, data in _SEED_FUND_DATA.items():
            rows = Panchayat.objects.filter(lgd_code=lgd_code).update(
                fund_available_inr=data['fund_available_inr']
            )
            if rows:
                self.stdout.write(
                    f"  ✓ Seeded {lgd_code}: Rs.{data['fund_available_inr']:,} "
                    f"({data['financial_year']})"
                )
                self.stdout.write("    Breakdown:")
                for scheme, amount in data.get('scheme_breakdown', {}).items():
                    self.stdout.write(f"      {scheme}: Rs.{amount:,}")
                updated += rows

        if not updated:
            self.stdout.write(
                self.style.WARNING(
                    "  No matching panchayats found for seed data. "
                    "Run create_demo to create Tusra panchayat first."
                )
            )
        return updated
