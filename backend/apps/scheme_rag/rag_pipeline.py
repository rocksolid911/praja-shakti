"""
RAG pipeline for querying government scheme information.
1. Embed the query
2. Find top-k similar scheme chunks via pgvector
3. Build context + call Claude with village data
4. Return answer with source citations
"""
import logging

from django.db.models import F
from pgvector.django import CosineDistance

from apps.geo_intelligence.models import Village
from .models import Scheme, SchemeChunk

logger = logging.getLogger(__name__)


def build_village_context(village: Village) -> str:
    panchayat = village.panchayat
    block = panchayat.block
    district = block.district
    state = district.state

    return f"""Village: {village.name}
Panchayat: {panchayat.name}, Block: {block.name}
District: {district.name}, State: {state.name}
Population: {village.population or 'Unknown'}
Households: {village.households or 'Unknown'}
Agricultural Households: {village.agricultural_households or 'Unknown'}
Groundwater Depth: {village.groundwater_depth_m or 'Unknown'}m
NDVI Vegetation Score: {village.ndvi_score or 'Unknown'}
Panchayat Fund Available: Rs.{panchayat.fund_available_inr:,}"""


def query_scheme_rag(query: str, village_id: int, top_k: int = 5) -> dict:
    """RAG query: embed → search pgvector → build context → call Claude."""
    village = Village.objects.select_related(
        'panchayat__block__district__state'
    ).get(id=village_id)

    village_context = build_village_context(village)

    # Try vector similarity search if embeddings exist
    chunks = []
    try:
        from apps.ai_engine.bedrock_client import get_embedding
        query_embedding = get_embedding(query)
        chunks = list(
            SchemeChunk.objects.select_related('scheme')
            .annotate(distance=CosineDistance('embedding', query_embedding))
            .order_by('distance')[:top_k]
        )
    except Exception as e:
        logger.warning(f"Vector search failed, falling back to keyword: {e}")
        # Fallback: keyword search
        chunks = list(
            SchemeChunk.objects.select_related('scheme')
            .filter(content__icontains=query.split()[0] if query else '')[:top_k]
        )

    if not chunks:
        # If no chunks, return all scheme summaries
        schemes = Scheme.objects.filter(is_active=True)
        context = "\n\n".join([
            f"[{s.short_name} - {s.ministry}]\n{s.description[:500]}"
            for s in schemes
        ])
    else:
        context = "\n\n".join([
            f"[{c.scheme.short_name} - {c.section_header or 'General'}]\n{c.content}"
            for c in chunks
        ])

    prompt = f"""You are an expert on Indian government rural development schemes.

VILLAGE CONTEXT:
{village_context}

RELEVANT SCHEME INFORMATION:
{context}

USER QUERY: {query}

Answer based ONLY on the scheme information provided. Cite which scheme each piece of
information comes from. If the village is eligible, say YES with specific qualifying criteria.
If not eligible, explain why. Suggest the application process and required documents.
Keep the answer concise and actionable."""

    try:
        from apps.ai_engine.bedrock_client import call_bedrock_claude
        answer = call_bedrock_claude(prompt, max_tokens=1000)
    except Exception as e:
        logger.error(f"RAG Claude call failed: {e}")
        answer = _fallback_answer(query, chunks, village)

    sources = [
        {'scheme': c.scheme.short_name, 'section': c.section_header or 'General'}
        for c in chunks
    ] if chunks else [
        {'scheme': s.short_name, 'section': 'Overview'}
        for s in Scheme.objects.filter(is_active=True)[:3]
    ]

    return {
        'answer': answer,
        'sources': sources,
        'village': village.name,
    }


def _fallback_answer(query: str, chunks, village):
    """Generate a simple answer when Bedrock is unavailable."""
    query_lower = query.lower()

    if 'kusum' in query_lower or 'solar' in query_lower:
        return (
            f"PM-KUSUM scheme provides 60% subsidy for solar water pumps. "
            f"For {village.name} with {village.agricultural_households or 'many'} "
            f"agricultural households, Component-B (standalone solar pumps up to 7.5 HP) "
            f"is most relevant. Apply through your District Agriculture Officer."
        )
    elif 'mgnrega' in query_lower:
        return (
            f"MGNREGA guarantees 100 days of wage employment per household per year. "
            f"Works include road construction, water conservation, and land development. "
            f"Apply at your Gram Panchayat office with job card."
        )
    elif 'jal' in query_lower or 'water' in query_lower or 'pani' in query_lower:
        return (
            f"Jal Jeevan Mission aims to provide tap water to every rural household by 2024. "
            f"For {village.name}, check eligibility with Block Development Officer. "
            f"Priority given to quality-affected areas and SC/ST habitations."
        )

    scheme_names = [c.scheme.short_name for c in chunks] if chunks else ['PM-KUSUM', 'MGNREGA', 'JJM']
    return (
        f"Based on your query about {village.name}, relevant schemes include: "
        f"{', '.join(scheme_names)}. Please contact your Block Development Officer "
        f"for detailed eligibility and application process."
    )
