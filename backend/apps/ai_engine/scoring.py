"""
Priority Scoring Algorithm
PRIORITY = Community Score (40%) + Data Validation Score (40%) + Urgency Modifier (20%)
All sub-scores are normalized to 0-100, then weighted.
"""
import logging
from datetime import datetime

from apps.community.models import Report, ReportCluster
from apps.projects.models import Project
from apps.geo_intelligence.models import Village
from .models import PriorityScore

logger = logging.getLogger(__name__)

SAFETY_KEYWORDS = ['accident', 'danger', 'unsafe', 'injury', 'death', 'khatra',
                   'durghatna', 'khatarnak', 'chot', 'maut']


def calculate_economic_impact_pts(cluster, village):
    """Economic impact score from agricultural/market data."""
    pts = 0
    if village.agricultural_households and village.population:
        ag_ratio = village.agricultural_households / max(village.population, 1)
        if cluster.category in ('water', 'electricity'):
            pts = min(25, ag_ratio * 100)
    return pts


def is_worsening_trend(village, category):
    """Check if the situation is getting worse based on data trends."""
    if category == 'water':
        if village.groundwater_depth_m and village.groundwater_depth_m > 12:
            return True
        if village.ndvi_score is not None and village.ndvi_score < 0.2:
            return True
    return False


def calculate_priority_score(cluster_id: int) -> PriorityScore:
    """
    PRIORITY = Community Score (40%) + Data Validation Score (40%) + Urgency Modifier (20%)
    """
    cluster = ReportCluster.objects.select_related('village').get(id=cluster_id)
    reports = Report.objects.filter(cluster=cluster)
    village = cluster.village

    # ── Community Score (max 40 points) ──────────────────────────────────
    # Signal 1: Report count (0-25 pts) — saturates at 20 reports
    report_pts = min(25, cluster.report_count * 25 / 20)

    # Signal 2: Geographic spread (0-25 pts) — saturates at 5 wards
    ward_count = reports.values('ward').distinct().count()
    geo_pts = min(25, ward_count * 25 / 5)

    # Signal 3: Community upvotes (0-25 pts) — saturates at 50 votes
    upvote_pts = min(25, cluster.upvote_count * 25 / 50)

    # Signal 4: Gram Sabha mention bonus (0 or +20)
    gram_sabha_bonus = 20 if reports.filter(is_gram_sabha=True).exists() else 0

    community_raw = report_pts + geo_pts + upvote_pts + gram_sabha_bonus
    community_score = min(40, community_raw * 40 / 100)

    # ── Data Validation Score (max 40 points) ─────────────────────────────
    # Signal 1: Satellite evidence (0-25 pts)
    satellite_pts = 25 if (village.ndvi_score is not None and village.ndvi_score < 0.3) else 0

    # Signal 2: Government data gap (0-25 pts)
    active_projects = Project.objects.filter(
        village=village, category=cluster.category,
        status__in=['adopted', 'in_progress'],
    ).count()
    gap_pts = 25 if active_projects == 0 else max(0, 25 - active_projects * 10)

    # Signal 3: Demographic impact (0-25 pts)
    pop_pct = (cluster.estimated_households or 0) / max(village.households or 1, 1)
    demographic_pts = min(25, pop_pct * 100)

    # Signal 4: Economic impact (0-25 pts)
    economic_pts = calculate_economic_impact_pts(cluster, village)

    data_raw = satellite_pts + gap_pts + demographic_pts + economic_pts
    data_score = min(40, data_raw * 40 / 100)

    # ── Urgency Modifier (max 20 points) ──────────────────────────────────
    month = datetime.now().month
    seasonal_pts = 10 if (
        (cluster.category == 'water' and month in [4, 5, 6]) or
        (cluster.category == 'road' and month in [7, 8, 9])
    ) else 0

    safety_pts = 10 if any(
        any(kw in (r.description_text or '').lower() for kw in SAFETY_KEYWORDS)
        for r in reports
    ) else 0

    worsening_pts = 10 if is_worsening_trend(village, cluster.category) else 0

    urgency_score = min(20, seasonal_pts + safety_pts + worsening_pts)

    total_score = community_score + data_score + urgency_score

    # Generate justification
    justification = generate_justification(
        cluster, village, total_score, community_score, data_score, urgency_score,
    )

    score, _ = PriorityScore.objects.update_or_create(
        cluster=cluster,
        defaults={
            'community_score': round(community_score, 2),
            'data_score': round(data_score, 2),
            'urgency_score': round(urgency_score, 2),
            'total_score': round(total_score, 2),
            'report_count_pts': round(report_pts, 2),
            'geographic_spread_pts': round(geo_pts, 2),
            'upvote_pts': round(upvote_pts, 2),
            'gram_sabha_bonus': round(gram_sabha_bonus, 2),
            'satellite_pts': round(satellite_pts, 2),
            'data_gap_pts': round(gap_pts, 2),
            'demographic_pts': round(demographic_pts, 2),
            'economic_pts': round(economic_pts, 2),
            'seasonal_pts': round(seasonal_pts, 2),
            'safety_pts': round(safety_pts, 2),
            'worsening_trend_pts': round(worsening_pts, 2),
            'justification': justification,
            'score_breakdown': {
                'community': {
                    'reports': round(report_pts, 2),
                    'geographic_spread': round(geo_pts, 2),
                    'upvotes': round(upvote_pts, 2),
                    'gram_sabha': round(gram_sabha_bonus, 2),
                },
                'data': {
                    'satellite': round(satellite_pts, 2),
                    'gap': round(gap_pts, 2),
                    'demographic': round(demographic_pts, 2),
                    'economic': round(economic_pts, 2),
                },
                'urgency': {
                    'seasonal': round(seasonal_pts, 2),
                    'safety': round(safety_pts, 2),
                    'worsening': round(worsening_pts, 2),
                },
            },
        },
    )

    logger.info(f"Priority score for cluster #{cluster_id}: {total_score:.1f}")
    return score


def generate_justification(cluster, village, total, community, data, urgency):
    parts = [
        f"Priority Score: {total:.0f}/100 for {cluster.category} issues in {village.name}.",
        f"Community voice is {'strong' if community > 25 else 'moderate'} "
        f"with {cluster.report_count} reports and {cluster.upvote_count} upvotes.",
    ]
    if data > 25:
        parts.append("Satellite and government data strongly validate community concerns.")
    if urgency > 10:
        parts.append("Urgency factors detected: immediate attention recommended.")
    return " ".join(parts)
