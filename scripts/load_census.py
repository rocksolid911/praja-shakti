#!/usr/bin/env python
"""
Load Census 2011 village directory data into PostGIS.

Usage:
    python scripts/load_census.py --state=Rajasthan
    python scripts/load_census.py --csv=census_villages.csv
    python scripts/load_census.py --all

This script:
1. Reads Census 2011 Village Directory CSV (from data.gov.in)
2. Creates State → District → Block → Panchayat → Village hierarchy
3. Uses LGD (Local Government Directory) code as the master key
4. Populates population, households, and agricultural data

CSV columns expected (Census 2011 Village Directory format):
    State Code, State Name, District Code, District Name,
    Sub-District Code, Sub-District Name, Village Code, Village Name,
    Total Population, Total Households, ...

Requires:
    - Django settings configured
    - PostgreSQL with PostGIS
"""

import argparse
import csv
import logging
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')

import django
django.setup()

from django.contrib.gis.geos import Point
from django.db import transaction

from apps.geo_intelligence.models import State, District, Block, Panchayat, Village

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

# Cache for lookups to avoid repeated DB queries
_state_cache = {}
_district_cache = {}
_block_cache = {}
_panchayat_cache = {}


def get_or_create_state(code: str, name: str) -> State:
    if code in _state_cache:
        return _state_cache[code]
    state, _ = State.objects.get_or_create(
        lgd_code=code.strip(),
        defaults={'name': name.strip().title()}
    )
    _state_cache[code] = state
    return state


def get_or_create_district(state: State, code: str, name: str) -> District:
    key = f"{state.id}_{code}"
    if key in _district_cache:
        return _district_cache[key]
    district, _ = District.objects.get_or_create(
        lgd_code=code.strip(),
        defaults={'state': state, 'name': name.strip().title()}
    )
    _district_cache[key] = district
    return district


def get_or_create_block(district: District, code: str, name: str) -> Block:
    key = f"{district.id}_{code}"
    if key in _block_cache:
        return _block_cache[key]
    block, _ = Block.objects.get_or_create(
        lgd_code=code.strip(),
        defaults={'district': district, 'name': name.strip().title()}
    )
    _block_cache[key] = block
    return block


def get_or_create_panchayat(block: Block, code: str, name: str) -> Panchayat:
    key = f"{block.id}_{code}"
    if key in _panchayat_cache:
        return _panchayat_cache[key]
    panchayat, _ = Panchayat.objects.get_or_create(
        lgd_code=code.strip(),
        defaults={'block': block, 'name': name.strip().title()}
    )
    _panchayat_cache[key] = panchayat
    return panchayat


def safe_int(val, default=None):
    """Safely convert to int, returning default on failure."""
    try:
        return int(str(val).strip().replace(',', ''))
    except (ValueError, TypeError):
        return default


def safe_float(val, default=None):
    try:
        return float(str(val).strip().replace(',', ''))
    except (ValueError, TypeError):
        return default


def load_csv(csv_path: str, state_filter: str = None, limit: int = None):
    """Load Census village directory CSV into database."""
    logger.info(f"Loading: {csv_path}")

    if not os.path.exists(csv_path):
        logger.error(f"File not found: {csv_path}")
        return

    with open(csv_path, 'r', encoding='utf-8-sig') as f:
        # Try to auto-detect CSV format
        sample = f.read(4096)
        f.seek(0)
        dialect = csv.Sniffer().sniff(sample, delimiters=',\t|')
        reader = csv.DictReader(f, dialect=dialect)

        # Normalize column names
        if reader.fieldnames:
            reader.fieldnames = [col.strip().lower().replace(' ', '_') for col in reader.fieldnames]

        # Map common Census CSV column variations
        col_map = {
            'state_code': ['state_code', 'state_lgd_code', 'st_code', 'statecode'],
            'state_name': ['state_name', 'state', 'statename'],
            'district_code': ['district_code', 'dist_code', 'districtcode', 'district_lgd_code'],
            'district_name': ['district_name', 'district', 'districtname'],
            'block_code': ['sub-district_code', 'sub_district_code', 'block_code', 'subdistrict_code', 'tehsil_code'],
            'block_name': ['sub-district_name', 'sub_district_name', 'block_name', 'subdistrict_name', 'tehsil_name'],
            'village_code': ['village_code', 'villagecode', 'town/village_code'],
            'village_name': ['village_name', 'villagename', 'town/village_name'],
            'population': ['total_population', 'population', 'tot_pop', 'total_pop'],
            'households': ['total_households', 'households', 'no_of_households', 'tot_hh'],
            'latitude': ['latitude', 'lat'],
            'longitude': ['longitude', 'lon', 'lng'],
        }

        def find_col(row, key):
            for variant in col_map.get(key, [key]):
                if variant in row:
                    return row[variant]
            return None

        created_count = 0
        skipped_count = 0

        with transaction.atomic():
            for i, row in enumerate(reader):
                if limit and i >= limit:
                    break

                state_name = find_col(row, 'state_name')
                if not state_name:
                    continue

                # Filter by state if requested
                if state_filter and state_filter.lower() not in state_name.lower():
                    skipped_count += 1
                    continue

                state_code = find_col(row, 'state_code') or f"S{i}"
                district_code = find_col(row, 'district_code') or f"D{i}"
                district_name = find_col(row, 'district_name') or 'Unknown'
                block_code = find_col(row, 'block_code') or f"B{i}"
                block_name = find_col(row, 'block_name') or 'Unknown'
                village_code = find_col(row, 'village_code') or f"V{i}"
                village_name = find_col(row, 'village_name') or 'Unknown'

                if not village_code or not village_name or village_name.strip() == '':
                    skipped_count += 1
                    continue

                # Build hierarchy
                state = get_or_create_state(state_code, state_name)
                district = get_or_create_district(state, district_code, district_name)
                block = get_or_create_block(district, block_code, block_name)

                # Use block as panchayat proxy (Census doesn't have panchayat level)
                panchayat = get_or_create_panchayat(block, f"P{block_code}", block_name)

                # Build location point if lat/lon available
                lat = safe_float(find_col(row, 'latitude'))
                lon = safe_float(find_col(row, 'longitude'))
                location = Point(lon, lat, srid=4326) if lat and lon else None

                population = safe_int(find_col(row, 'population'))
                households = safe_int(find_col(row, 'households'))

                village, created = Village.objects.update_or_create(
                    lgd_code=village_code.strip(),
                    defaults={
                        'panchayat': panchayat,
                        'name': village_name.strip().title(),
                        'location': location,
                        'population': population,
                        'households': households,
                    }
                )

                if created:
                    created_count += 1

                if (i + 1) % 1000 == 0:
                    logger.info(f"  Processed {i + 1} rows ({created_count} created, {skipped_count} skipped)")

    logger.info(f"=== COMPLETE: {created_count} villages created, {skipped_count} skipped ===")
    logger.info(f"  States: {State.objects.count()}")
    logger.info(f"  Districts: {District.objects.count()}")
    logger.info(f"  Blocks: {Block.objects.count()}")
    logger.info(f"  Panchayats: {Panchayat.objects.count()}")
    logger.info(f"  Villages: {Village.objects.count()}")


def main():
    parser = argparse.ArgumentParser(description='Load Census 2011 village data into PostGIS')
    parser.add_argument('--csv', help='Path to Census village directory CSV file')
    parser.add_argument('--state', help='Filter by state name (e.g., Rajasthan, Odisha)')
    parser.add_argument('--limit', type=int, help='Limit number of rows to process')
    parser.add_argument('--all', action='store_true', help='Load all states (no filter)')

    args = parser.parse_args()

    if not args.csv:
        # Try default locations
        default_paths = [
            'data/census/village_directory.csv',
            'data/census_villages.csv',
            'data/village_directory_census2011.csv',
        ]
        for p in default_paths:
            if os.path.exists(p):
                args.csv = p
                break

    if not args.csv:
        logger.error("No CSV file specified. Use --csv=<path>")
        logger.info("Download from: https://data.gov.in/resource/census-village-directory-2011")
        sys.exit(1)

    state_filter = None if args.all else args.state
    load_csv(args.csv, state_filter=state_filter, limit=args.limit)


if __name__ == '__main__':
    main()
