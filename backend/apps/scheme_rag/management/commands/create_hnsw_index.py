"""
Management command to create the HNSW vector index for fast RAG similarity search.

Must be run AFTER `python manage.py migrate` (requires the scheme_rag tables to exist)
and AFTER `CREATE EXTENSION vector;` in PostgreSQL.

Usage:
    python manage.py create_hnsw_index

This creates:
  - HNSW index on scheme_rag_schemechunk(embedding) for fast cosine similarity search
  - HNSW index on community_report(embedding) for report clustering similarity
  - IVFFlat index on scheme_rag_eligibilityrule(embedding) as a lighter-weight alternative
"""
from django.core.management.base import BaseCommand
from django.db import connection


INDEXES = [
    {
        'name': 'scheme_rag_schemechunk_embedding_hnsw',
        'sql': """
            CREATE INDEX IF NOT EXISTS scheme_rag_schemechunk_embedding_hnsw
            ON scheme_rag_schemechunk
            USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64);
        """,
        'description': 'HNSW index on SchemeChunk.embedding for fast scheme RAG queries',
    },
    {
        'name': 'community_report_embedding_hnsw',
        'sql': """
            CREATE INDEX IF NOT EXISTS community_report_embedding_hnsw
            ON community_report
            USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64);
        """,
        'description': 'HNSW index on Report.embedding for similarity-based report clustering',
    },
    {
        'name': 'scheme_rag_eligibilityrule_embedding_ivfflat',
        'sql': """
            CREATE INDEX IF NOT EXISTS scheme_rag_eligibilityrule_embedding_ivfflat
            ON scheme_rag_eligibilityrule
            USING ivfflat (embedding vector_cosine_ops)
            WITH (lists = 10);
        """,
        'description': 'IVFFlat index on EligibilityRule.embedding',
    },
]


class Command(BaseCommand):
    help = 'Create pgvector HNSW indexes for fast RAG similarity search (run after migrate)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--drop-existing',
            action='store_true',
            help='Drop existing indexes before recreating (use if rebuilding with more data)',
        )

    def handle(self, *args, **options):
        self.stdout.write('Creating pgvector indexes...\n')

        # Verify pgvector extension is installed
        with connection.cursor() as cursor:
            cursor.execute("SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'vector');")
            has_vector = cursor.fetchone()[0]

        if not has_vector:
            self.stderr.write(self.style.ERROR(
                'pgvector extension not found!\n'
                'Run in PostgreSQL: CREATE EXTENSION vector;\n'
                'Then retry this command.'
            ))
            return

        for idx in INDEXES:
            self.stdout.write(f"  Creating: {idx['name']}...")
            try:
                with connection.cursor() as cursor:
                    if options['drop_existing']:
                        cursor.execute(f"DROP INDEX IF EXISTS {idx['name']};")
                        self.stdout.write(f"    Dropped existing index.")
                    cursor.execute(idx['sql'])
                self.stdout.write(self.style.SUCCESS(
                    f"    [OK] {idx['description']}"
                ))
            except Exception as e:
                self.stderr.write(self.style.ERROR(f"    [FAILED] {e}"))

        self.stdout.write(self.style.SUCCESS(
            '\nAll indexes created. RAG queries will now use HNSW for fast cosine similarity.\n'
            'Tip: After ingesting scheme documents, run with --drop-existing to rebuild indexes.\n'
        ))
