"""
Ingest scheme descriptions into pgvector for RAG.
Uses the scheme descriptions already in the database (no PDFs needed for demo).

Usage: python manage.py ingest_schemes
"""
import json
import boto3
from django.core.management.base import BaseCommand
from django.conf import settings


class Command(BaseCommand):
    help = 'Generate embeddings for all scheme descriptions and store in pgvector'

    def add_arguments(self, parser):
        parser.add_argument(
            '--rebuild', action='store_true',
            help='Delete existing chunks and rebuild from scratch'
        )

    def handle(self, *args, **options):
        from apps.scheme_rag.models import Scheme, SchemeChunk, EligibilityRule

        bedrock = boto3.client('bedrock-runtime', region_name=settings.AWS_REGION)

        if options['rebuild']:
            deleted = SchemeChunk.objects.all().delete()[0]
            self.stdout.write(f'Deleted {deleted} existing chunks')

        schemes = Scheme.objects.all()
        if not schemes.exists():
            self.stdout.write(self.style.ERROR('No schemes found. Run create_demo first.'))
            return

        total_chunks = 0
        for scheme in schemes:
            # Split scheme description into chunks
            chunks = self._split_text(scheme.description, scheme_name=scheme.name)

            for i, (chunk_text, section_header, chunk_type) in enumerate(chunks):
                # Skip if already exists
                if SchemeChunk.objects.filter(scheme=scheme, chunk_index=i).exists():
                    continue

                embedding = self._get_embedding(bedrock, chunk_text)
                if embedding is None:
                    self.stdout.write(self.style.WARNING(f'  Skipping chunk {i} for {scheme.short_name} (embedding failed)'))
                    continue

                SchemeChunk.objects.create(
                    scheme=scheme,
                    chunk_index=i,
                    content=chunk_text,
                    section_header=section_header,
                    chunk_type=chunk_type,
                    embedding=embedding,
                    token_count=len(chunk_text.split()),
                )
                total_chunks += 1

            # Create eligibility rule embedding
            if not EligibilityRule.objects.filter(scheme=scheme).exists():
                eligibility_text = f"{scheme.name} ({scheme.short_name}): {scheme.description[:300]}"
                embedding = self._get_embedding(bedrock, eligibility_text)
                if embedding:
                    EligibilityRule.objects.create(
                        scheme=scheme,
                        rule_text=scheme.description[:500],
                        rule_type='general',
                        embedding=embedding,
                    )

            self.stdout.write(f'  Processed: {scheme.short_name} ({len(chunks)} chunks)')

        self.stdout.write(self.style.SUCCESS(
            f'\nDone! Created {total_chunks} chunks for {schemes.count()} schemes.'
        ))
        self.stdout.write('You can now run: python manage.py create_hnsw_index')

    def _split_text(self, text, scheme_name=''):
        """Split scheme description into meaningful chunks with metadata."""
        chunks = []

        # Main description as overview chunk
        if len(text) > 50:
            chunks.append((text[:500], 'Overview', 'general'))

        # Look for key sections
        import re
        sections = {
            'eligib': 'eligibility',
            'subsidy': 'fund_allocation',
            'fund': 'fund_allocation',
            'document': 'documents',
            'apply': 'process',
            'process': 'process',
            'benefit': 'general',
        }

        sentences = re.split(r'[.!?]+', text)
        current_chunk = []
        current_type = 'general'

        for sentence in sentences:
            sentence = sentence.strip()
            if not sentence:
                continue

            # Detect section type
            s_lower = sentence.lower()
            for keyword, chunk_type in sections.items():
                if keyword in s_lower:
                    current_type = chunk_type
                    break

            current_chunk.append(sentence)

            if len(' '.join(current_chunk)) > 200:
                chunk_text = '. '.join(current_chunk) + '.'
                chunks.append((chunk_text, f'{scheme_name} - Details', current_type))
                current_chunk = []
                current_type = 'general'

        if current_chunk:
            chunk_text = '. '.join(current_chunk) + '.'
            chunks.append((chunk_text, f'{scheme_name} - Additional', current_type))

        return chunks if chunks else [(text[:400], 'Overview', 'general')]

    def _get_embedding(self, bedrock, text):
        """Get embedding from Amazon Titan Embed Text V2."""
        try:
            response = bedrock.invoke_model(
                modelId=settings.BEDROCK_EMBEDDING_MODEL_ID,
                body=json.dumps({'inputText': text[:8000]})  # Titan V2 limit
            )
            result = json.loads(response['body'].read())
            return result['embedding']
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Embedding error: {e}'))
            return None
