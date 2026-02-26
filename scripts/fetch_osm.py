#!/usr/bin/env python
"""
Fetch infrastructure features from OpenStreetMap Overpass API.

Usage:
    python scripts/fetch_osm.py --village-id=1
    python scripts/fetch_osm.py --lat=26.4521 --lon=73.1143 --radius=5000
    python scripts/fetch_osm.py --all-villages

This script:
1. Queries OpenStreetMap Overpass API for infrastructure around a village
2. Fetches schools, hospitals, water sources, markets, roads
3. Stores results in the Infrastructure model with PostGIS geometry
4. Calculates distance from village center

Requires:
    - Django settings configured
    - PostgreSQL with PostGIS
    - Internet access (Overpass API is free, no auth needed)

Rate limit: 10 requests/min — be respectful of OSM servers.
"""

import argparse
import logging
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')

import django
django.setup()

import requests
from django.contrib.gis.geos import Point
from django.contrib.gis.measure import D
from django.db import transaction

from apps.geo_intelligence.models import Village, Infrastructure

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

OVERPASS_URL = 'https://overpass-api.de/api/interpreter'
REQUEST_DELAY = 7  # seconds between requests (respect rate limits)

# OSM tag → Infrastructure type mapping
OSM_QUERIES = {
    'school': [
        'node["amenity"="school"]',
        'way["amenity"="school"]',
    ],
    'hospital': [
        'node["amenity"="hospital"]',
        'node["amenity"="clinic"]',
        'node["amenity"="doctors"]',
        'node["healthcare"="centre"]',
        'node["healthcare"="hospital"]',
    ],
    'water_source': [
        'node["amenity"="drinking_water"]',
        'node["man_made"="water_well"]',
        'node["natural"="spring"]',
        'node["amenity"="water_point"]',
        'node["man_made"="borehole"]',
    ],
    'market': [
        'node["amenity"="marketplace"]',
        'node["shop"="general"]',
        'node["shop"="convenience"]',
        'node["landuse"="retail"]',
    ],
    'road': [
        'way["highway"="primary"]',
        'way["highway"="secondary"]',
        'way["highway"="tertiary"]',
    ],
}


def build_overpass_query(lat: float, lon: float, radius: int = 5000) -> str:
    """Build a single Overpass QL query for all infrastructure types."""
    elements = []
    for infra_type, tags in OSM_QUERIES.items():
        for tag_query in tags:
            elements.append(f'  {tag_query}(around:{radius},{lat},{lon});')

    query = f"""[out:json][timeout:60];
(
{chr(10).join(elements)}
);
out center body;
"""
    return query


def fetch_overpass(query: str) -> list[dict]:
    """Execute Overpass API query and return elements."""
    try:
        response = requests.post(
            OVERPASS_URL,
            data={'data': query},
            timeout=120,
            headers={'User-Agent': 'PrajaShakti-AI/1.0 (Rural Hackathon)'}
        )
        response.raise_for_status()
        data = response.json()
        return data.get('elements', [])
    except requests.exceptions.Timeout:
        logger.error("Overpass API timeout — try a smaller radius")
        return []
    except requests.exceptions.RequestException as e:
        logger.error(f"Overpass API error: {e}")
        return []
    except ValueError:
        logger.error("Invalid JSON response from Overpass API")
        return []


def classify_element(element: dict) -> tuple[str, str]:
    """Classify an OSM element into (infra_type, name)."""
    tags = element.get('tags', {})

    # Determine type
    amenity = tags.get('amenity', '')
    healthcare = tags.get('healthcare', '')
    man_made = tags.get('man_made', '')
    natural = tags.get('natural', '')
    highway = tags.get('highway', '')
    shop = tags.get('shop', '')
    landuse = tags.get('landuse', '')

    infra_type = 'other'
    if amenity in ('school',):
        infra_type = 'school'
    elif amenity in ('hospital', 'clinic', 'doctors') or healthcare:
        infra_type = 'hospital'
    elif amenity in ('drinking_water', 'water_point') or man_made in ('water_well', 'borehole') or natural == 'spring':
        infra_type = 'water_source'
    elif amenity == 'marketplace' or shop or landuse == 'retail':
        infra_type = 'market'
    elif highway in ('primary', 'secondary', 'tertiary'):
        infra_type = 'road'

    # Get name
    name = tags.get('name', tags.get('name:en', tags.get('name:hi', '')))
    if not name:
        name = f"{infra_type.replace('_', ' ').title()} (OSM)"

    return infra_type, name


def get_element_location(element: dict) -> tuple[float, float] | None:
    """Extract lat/lon from OSM element (handles nodes and ways with center)."""
    if element.get('type') == 'node':
        return element.get('lat'), element.get('lon')
    # Ways/relations may have center
    center = element.get('center', {})
    if center:
        return center.get('lat'), center.get('lon')
    return None


def process_village(village: Village, radius: int = 5000):
    """Fetch and store OSM infrastructure for a single village."""
    if not village.location:
        logger.warning(f"Village {village.name} (#{village.id}) has no location — skipping")
        return 0

    lat = village.location.y
    lon = village.location.x
    logger.info(f"Fetching infrastructure for {village.name} ({lat}, {lon}) within {radius}m")

    query = build_overpass_query(lat, lon, radius)
    elements = fetch_overpass(query)
    logger.info(f"  Received {len(elements)} elements from Overpass")

    created_count = 0
    village_center = village.location

    with transaction.atomic():
        for element in elements:
            osm_id = f"{element.get('type', 'n')}{element.get('id', '')}"

            # Skip if already exists
            if Infrastructure.objects.filter(osm_id=osm_id).exists():
                continue

            location = get_element_location(element)
            if not location:
                continue

            lat_e, lon_e = location
            if not lat_e or not lon_e:
                continue

            infra_type, name = classify_element(element)
            if infra_type == 'other':
                continue

            point = Point(lon_e, lat_e, srid=4326)

            # Calculate distance from village center (approximate km)
            distance_km = None
            try:
                # Use geodetic distance
                from django.contrib.gis.db.models.functions import Distance as GeoDistance
                from math import radians, sin, cos, sqrt, atan2

                R = 6371.0
                lat1, lon1 = radians(lat), radians(lon)
                lat2, lon2 = radians(lat_e), radians(lon_e)
                dlat = lat2 - lat1
                dlon = lon2 - lon1
                a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
                distance_km = round(R * 2 * atan2(sqrt(a), sqrt(1 - a)), 2)
            except Exception:
                pass

            Infrastructure.objects.create(
                village=village,
                infra_type=infra_type,
                name=name[:200],
                location=point,
                osm_id=osm_id,
                distance_from_center_km=distance_km,
            )
            created_count += 1

    logger.info(f"  Created {created_count} infrastructure records for {village.name}")
    return created_count


def main():
    parser = argparse.ArgumentParser(description='Fetch OSM infrastructure for villages')
    parser.add_argument('--village-id', type=int, help='Specific village ID to fetch')
    parser.add_argument('--lat', type=float, help='Latitude (use with --lon)')
    parser.add_argument('--lon', type=float, help='Longitude (use with --lat)')
    parser.add_argument('--radius', type=int, default=5000, help='Search radius in meters (default: 5000)')
    parser.add_argument('--all-villages', action='store_true', help='Fetch for all villages with locations')
    parser.add_argument('--limit', type=int, help='Limit number of villages to process')
    args = parser.parse_args()

    if args.village_id:
        try:
            village = Village.objects.get(id=args.village_id)
            process_village(village, args.radius)
        except Village.DoesNotExist:
            logger.error(f"Village #{args.village_id} not found")
            sys.exit(1)

    elif args.lat and args.lon:
        # Find nearest village or create temp context
        nearby = Village.objects.filter(
            location__distance_lte=(Point(args.lon, args.lat, srid=4326), D(km=10))
        ).first()
        if nearby:
            process_village(nearby, args.radius)
        else:
            logger.error("No village found near those coordinates. Load census data first.")
            sys.exit(1)

    elif args.all_villages:
        villages = Village.objects.filter(location__isnull=False)
        if args.limit:
            villages = villages[:args.limit]

        total = villages.count()
        logger.info(f"Processing {total} villages...")

        total_created = 0
        for i, village in enumerate(villages):
            count = process_village(village, args.radius)
            total_created += count

            if i < total - 1:
                logger.info(f"  Waiting {REQUEST_DELAY}s (rate limit)...")
                time.sleep(REQUEST_DELAY)

            logger.info(f"  Progress: {i + 1}/{total} villages")

        logger.info(f"\n=== COMPLETE: {total_created} infrastructure records across {total} villages ===")

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
