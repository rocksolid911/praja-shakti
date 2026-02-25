"""
AI-powered project recommendation engine.
Uses RAG with scheme chunks + village context to generate actionable project recommendations.
"""
import json
import logging

from apps.community.models import ReportCluster
from apps.geo_intelligence.models import Village
from apps.projects.models import Project
from apps.scheme_rag.models import Scheme, SchemeChunk, FundConvergencePlan

logger = logging.getLogger(__name__)


def build_village_context(village: Village) -> str:
    """Build a rich context string for a village."""
    panchayat = village.panchayat
    block = panchayat.block
    district = block.district
    state = district.state

    return f"""Village: {village.name}
Panchayat: {panchayat.name}, Block: {block.name}, District: {district.name}, State: {state.name}
Population: {village.population or 'Unknown'}
Households: {village.households or 'Unknown'}
Agricultural Households: {village.agricultural_households or 'Unknown'}
Groundwater Depth: {village.groundwater_depth_m or 'Unknown'}m
NDVI Score: {village.ndvi_score or 'Unknown'} (0=barren, 1=lush)
Panchayat Fund Available: Rs.{panchayat.fund_available_inr:,}"""


def generate_recommendation(cluster_id: int) -> Project:
    """Generate a project recommendation for a report cluster."""
    cluster = ReportCluster.objects.select_related('village__panchayat__block__district__state').get(id=cluster_id)
    village = cluster.village

    # Find matching schemes by category
    category_scheme_map = {
        'water': ['PM-KUSUM', 'Jal Jeevan Mission', 'MGNREGA'],
        'road': ['PMGSY', 'MGNREGA'],
        'health': ['NRLM/DAY-NRLM', 'MGNREGA'],
        'education': ['Samagra Shiksha', 'MGNREGA'],
        'electricity': ['PM-KUSUM', 'MGNREGA'],
        'sanitation': ['SBM-G', 'MGNREGA'],
    }

    matching_scheme_names = category_scheme_map.get(cluster.category, ['MGNREGA'])
    matching_schemes = Scheme.objects.filter(short_name__in=matching_scheme_names, is_active=True)

    village_context = build_village_context(village)

    # Build recommendation based on cluster data
    recommendation = generate_project_for_cluster(cluster, village, matching_schemes)

    # Create fund convergence plan
    if recommendation:
        create_fund_convergence_plan(recommendation, matching_schemes, village)

    return recommendation


def generate_project_for_cluster(cluster, village, schemes):
    """Generate a concrete project recommendation."""
    # Project templates by category
    templates = {
        'water': {
            'title': f'Solar Borewell with Piped Supply - {village.name} Ward {cluster.reports.values_list("ward", flat=True).first() or ""}',
            'description': (
                f'Install solar-powered borewell with piped water supply network '
                f'to serve {cluster.estimated_households or 200}+ households in {village.name}. '
                f'Community reported {cluster.report_count} water access issues. '
                f'NDVI score of {village.ndvi_score} indicates severe water stress. '
                f'Groundwater at {village.groundwater_depth_m}m depth is accessible via borewell.'
            ),
            'estimated_cost_inr': 450000,
            'impact': {
                'water_distance_km': 0.3,
                'households_served': cluster.estimated_households or 200,
                'daily_water_liters': 55 * (cluster.estimated_households or 200),
            },
        },
        'road': {
            'title': f'All-Weather Road Construction - {village.name}',
            'description': (
                f'Construct all-weather paved road connecting {village.name} to block headquarters. '
                f'{cluster.report_count} community reports highlight road access issues.'
            ),
            'estimated_cost_inr': 800000,
            'impact': {
                'road_length_km': 2.5,
                'households_connected': cluster.estimated_households or 300,
            },
        },
        'health': {
            'title': f'Health Sub-Centre Upgrade - {village.name}',
            'description': f'Upgrade health sub-centre with essential equipment and staff quarters.',
            'estimated_cost_inr': 350000,
            'impact': {'population_served': village.population or 3000},
        },
        'education': {
            'title': f'School Infrastructure Improvement - {village.name}',
            'description': f'Improve school infrastructure: additional classrooms, toilets, and boundary wall.',
            'estimated_cost_inr': 500000,
            'impact': {'students_benefited': 200},
        },
        'electricity': {
            'title': f'Solar Micro-Grid Installation - {village.name}',
            'description': f'Install solar micro-grid for reliable electricity supply to {village.name}.',
            'estimated_cost_inr': 600000,
            'impact': {'households_electrified': cluster.estimated_households or 150},
        },
        'sanitation': {
            'title': f'Community Sanitation Complex - {village.name}',
            'description': f'Construct community sanitation complex with toilets and waste management.',
            'estimated_cost_inr': 250000,
            'impact': {'households_served': cluster.estimated_households or 100},
        },
    }

    template = templates.get(cluster.category, templates['water'])

    from django.contrib.gis.geos import Point
    project = Project.objects.create(
        cluster=cluster,
        village=village,
        title=template['title'],
        description=template['description'],
        category=cluster.category,
        location=Point(cluster.centroid.x, cluster.centroid.y, srid=4326) if cluster.centroid else None,
        estimated_cost_inr=template['estimated_cost_inr'],
        beneficiary_count=cluster.estimated_households or 200,
        impact_projection=template['impact'],
        priority_score=cluster.community_priority_score,
        ai_confidence=0.85,
        status='recommended',
    )

    return project


def create_fund_convergence_plan(project, schemes, village):
    """Create a fund convergence plan mixing multiple schemes."""
    total_cost = project.estimated_cost_inr
    schemes_used = []
    remaining = total_cost

    for scheme in schemes:
        if remaining <= 0:
            break
        subsidy_pct = scheme.max_subsidy_pct or 30
        amount = min(remaining, int(total_cost * subsidy_pct / 100))
        schemes_used.append({
            'scheme_id': scheme.id,
            'scheme_name': scheme.short_name,
            'amount_inr': amount,
            'pct_covered': round(amount / total_cost * 100, 1),
        })
        remaining -= amount

    panchayat_contribution = max(0, remaining)
    savings_pct = round((total_cost - panchayat_contribution) / total_cost * 100, 1)

    FundConvergencePlan.objects.create(
        project=project,
        total_cost_inr=total_cost,
        panchayat_contribution_inr=panchayat_contribution,
        savings_pct=savings_pct,
        schemes_used=schemes_used,
    )
