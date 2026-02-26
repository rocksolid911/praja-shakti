#!/usr/bin/env python
"""
Ingest government scheme PDFs into pgvector for RAG pipeline.

Usage:
    python scripts/ingest_schemes.py --scheme-dir ./scheme_pdfs/

This script:
1. Reads PDF files from the specified directory
2. Splits each PDF into 500-token chunks with 50-token overlap
3. Generates embeddings via AWS Bedrock (Amazon Titan)
4. Stores chunks + embeddings in the SchemeChunk table (pgvector)

Requires:
    - Django settings configured (DJANGO_SETTINGS_MODULE)
    - PostgreSQL with pgvector extension
    - AWS credentials for Bedrock embedding model
"""

import argparse
import json
import logging
import os
import sys
from pathlib import Path

# Setup Django
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')

import django
django.setup()

import boto3
import fitz  # PyMuPDF
from langchain.text_splitter import RecursiveCharacterTextSplitter

from apps.scheme_rag.models import Scheme, SchemeChunk, EligibilityRule
from django.conf import settings

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

CHUNK_SIZE = 500
CHUNK_OVERLAP = 50

# Master scheme registry — maps PDF filenames to scheme metadata
SCHEMES = [
    {"name": "PM-KUSUM", "short_name": "PM-KUSUM", "ministry": "MNRE",
     "category": "water", "max_subsidy_pct": 60.0,
     "description": "Pradhan Mantri Kisan Urja Suraksha evam Utthaan Mahabhiyan - Solar pumps and grid-connected solar for farmers"},
    {"name": "MGNREGA", "short_name": "MGNREGA", "ministry": "MoRD",
     "category": "infrastructure", "max_subsidy_pct": 100.0,
     "description": "Mahatma Gandhi National Rural Employment Guarantee Act - 100 days guaranteed employment and rural infrastructure"},
    {"name": "Jal Jeevan Mission", "short_name": "JJM", "ministry": "Ministry of Jal Shakti",
     "category": "water", "max_subsidy_pct": 90.0,
     "description": "Functional Household Tap Connection (FHTC) to every rural household by 2024"},
    {"name": "PMAY-G", "short_name": "PMAY-G", "ministry": "MoRD",
     "category": "housing", "max_subsidy_pct": 90.0,
     "description": "Pradhan Mantri Awas Yojana - Gramin: Pucca house with basic amenities to all houseless and dilapidated houses"},
    {"name": "PM-KISAN", "short_name": "PM-KISAN", "ministry": "MoA&FW",
     "category": "agriculture", "max_subsidy_pct": None,
     "description": "Income support of Rs.6000 per year to all farmer families in three equal installments"},
    {"name": "PMFBY", "short_name": "PMFBY", "ministry": "MoA&FW",
     "category": "insurance", "max_subsidy_pct": None,
     "description": "Pradhan Mantri Fasal Bima Yojana - Crop insurance scheme for farmers"},
    {"name": "PMGSY", "short_name": "PMGSY", "ministry": "MoRD",
     "category": "road", "max_subsidy_pct": 100.0,
     "description": "Pradhan Mantri Gram Sadak Yojana - All-weather road connectivity to unconnected habitations"},
    {"name": "SBM-G", "short_name": "SBM-G", "ministry": "Ministry of Jal Shakti",
     "category": "sanitation", "max_subsidy_pct": 100.0,
     "description": "Swachh Bharat Mission Gramin - ODF Plus: solid and liquid waste management"},
    {"name": "DDU-GKY", "short_name": "DDU-GKY", "ministry": "MoRD",
     "category": "skill", "max_subsidy_pct": 100.0,
     "description": "Deen Dayal Upadhyaya Grameen Kaushalya Yojana - Skill development and placement for rural poor youth"},
    {"name": "NRLM/DAY-NRLM", "short_name": "DAY-NRLM", "ministry": "MoRD",
     "category": "livelihood", "max_subsidy_pct": None,
     "description": "Deendayal Antyodaya Yojana - National Rural Livelihood Mission: Self-help groups and micro-enterprises"},
    {"name": "National Social Assistance", "short_name": "NSAP", "ministry": "MoRD",
     "category": "social_security", "max_subsidy_pct": None,
     "description": "Old age pension, widow pension, disability pension for BPL families"},
    {"name": "Samagra Shiksha", "short_name": "SS", "ministry": "MoE",
     "category": "education", "max_subsidy_pct": None,
     "description": "Integrated scheme for school education from pre-school to senior secondary"},
]


def get_embedding(text: str) -> list[float]:
    """Generate embedding vector using AWS Bedrock Titan Embeddings."""
    try:
        bedrock = boto3.client('bedrock-runtime', region_name=settings.AWS_REGION)
        response = bedrock.invoke_model(
            modelId=getattr(settings, 'BEDROCK_EMBEDDING_MODEL_ID', 'amazon.titan-embed-text-v2:0'),
            body=json.dumps({"inputText": text[:8000]})  # Titan limit
        )
        result = json.loads(response['body'].read())
        return result['embedding']
    except Exception as e:
        logger.warning(f"Bedrock embedding failed, using zero vector: {e}")
        return [0.0] * 1536


def classify_chunk(content: str) -> str:
    """Classify chunk type based on content keywords."""
    content_lower = content.lower()
    if any(kw in content_lower for kw in ['eligib', 'paatr', 'qualifying', 'criteria', 'condition']):
        return 'eligibility'
    if any(kw in content_lower for kw in ['fund', 'budget', 'allocation', 'amount', 'crore', 'lakh', 'subsidy']):
        return 'fund_allocation'
    if any(kw in content_lower for kw in ['document', 'required', 'aadhaar', 'certificate', 'proof']):
        return 'documents'
    if any(kw in content_lower for kw in ['process', 'apply', 'application', 'step', 'procedure', 'aavedan']):
        return 'process'
    return 'general'


def extract_section_header(content: str) -> str:
    """Try to extract a section header from the chunk content."""
    lines = content.strip().split('\n')
    for line in lines[:3]:
        stripped = line.strip()
        if stripped and len(stripped) < 100 and stripped[0].isupper():
            return stripped[:200]
    return ''


def ingest_pdf(pdf_path: str, scheme: Scheme):
    """Extract text from PDF, split into chunks, embed, and store."""
    logger.info(f"Ingesting: {pdf_path} → Scheme: {scheme.name}")

    doc = fitz.open(pdf_path)
    text = "\n".join(page.get_text() for page in doc)
    doc.close()

    if not text.strip():
        logger.warning(f"Empty PDF: {pdf_path}")
        return 0

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP,
        separators=["\n\n", "\n", ". ", " "],
        length_function=lambda t: len(t.split()),
    )
    chunks = splitter.split_text(text)
    logger.info(f"  Split into {len(chunks)} chunks")

    # Delete existing chunks for this scheme (re-ingest)
    deleted, _ = SchemeChunk.objects.filter(scheme=scheme).delete()
    if deleted:
        logger.info(f"  Deleted {deleted} existing chunks")

    created = 0
    for i, chunk_text in enumerate(chunks):
        embedding = get_embedding(chunk_text)
        chunk_type = classify_chunk(chunk_text)
        section_header = extract_section_header(chunk_text)

        SchemeChunk.objects.create(
            scheme=scheme,
            chunk_index=i,
            content=chunk_text,
            section_header=section_header,
            chunk_type=chunk_type,
            embedding=embedding,
            token_count=len(chunk_text.split()),
        )
        created += 1

        if (i + 1) % 10 == 0:
            logger.info(f"  Processed {i + 1}/{len(chunks)} chunks")

    # Also create eligibility rules from eligibility-type chunks
    elig_chunks = SchemeChunk.objects.filter(scheme=scheme, chunk_type='eligibility')
    for ec in elig_chunks:
        EligibilityRule.objects.update_or_create(
            scheme=scheme,
            rule_text=ec.content[:500],
            defaults={
                'rule_type': 'general',
                'embedding': ec.embedding,
            }
        )

    logger.info(f"  Done: {created} chunks stored for {scheme.name}")
    return created


def ensure_schemes_exist():
    """Create or update Scheme records in the database."""
    for s in SCHEMES:
        scheme, created = Scheme.objects.update_or_create(
            short_name=s['short_name'],
            defaults={
                'name': s['name'],
                'ministry': s['ministry'],
                'category': s['category'],
                'description': s['description'],
                'max_subsidy_pct': s.get('max_subsidy_pct'),
                'is_active': True,
            }
        )
        action = "Created" if created else "Updated"
        logger.info(f"  {action} scheme: {scheme.name}")


def main():
    parser = argparse.ArgumentParser(description='Ingest scheme PDFs into pgvector for RAG')
    parser.add_argument('--scheme-dir', required=True, help='Directory containing scheme PDF files')
    parser.add_argument('--scheme', help='Specific scheme short_name to ingest (optional)')
    parser.add_argument('--dry-run', action='store_true', help='List files without ingesting')
    args = parser.parse_args()

    scheme_dir = Path(args.scheme_dir)
    if not scheme_dir.exists():
        logger.error(f"Directory not found: {scheme_dir}")
        sys.exit(1)

    # Ensure all scheme records exist
    logger.info("Ensuring scheme records exist in database...")
    ensure_schemes_exist()

    # Find and process PDFs
    pdf_files = sorted(scheme_dir.glob('*.pdf'))
    if not pdf_files:
        logger.warning(f"No PDF files found in {scheme_dir}")
        sys.exit(0)

    logger.info(f"Found {len(pdf_files)} PDF files")

    total_chunks = 0
    for pdf_path in pdf_files:
        # Try to match PDF filename to a scheme
        pdf_stem = pdf_path.stem.lower().replace('_', '-').replace(' ', '-')

        matched_scheme = None
        for s in SCHEMES:
            if s['short_name'].lower().replace('/', '-') in pdf_stem or \
               s['name'].lower().replace(' ', '-') in pdf_stem:
                matched_scheme = s
                break

        if not matched_scheme:
            logger.warning(f"Skipping {pdf_path.name} — no matching scheme found")
            continue

        if args.scheme and matched_scheme['short_name'] != args.scheme:
            continue

        scheme = Scheme.objects.get(short_name=matched_scheme['short_name'])

        if args.dry_run:
            logger.info(f"[DRY RUN] Would ingest: {pdf_path.name} → {scheme.name}")
            continue

        # Upload PDF to S3 (best effort)
        try:
            s3 = boto3.client('s3', region_name=settings.AWS_REGION)
            s3_key = f"schemes/{scheme.short_name}/{pdf_path.name}"
            s3.upload_file(str(pdf_path), settings.AWS_S3_SCHEME_DOCS_BUCKET, s3_key)
            scheme.pdf_s3_key = s3_key
            scheme.save()
        except Exception as e:
            logger.warning(f"S3 upload skipped: {e}")

        chunks = ingest_pdf(str(pdf_path), scheme)
        total_chunks += chunks

    logger.info(f"\n=== COMPLETE: Ingested {total_chunks} total chunks ===")


if __name__ == '__main__':
    main()
