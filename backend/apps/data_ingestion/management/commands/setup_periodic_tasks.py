"""
Management command to seed Celery Beat periodic tasks into the database.

Usage:
    python manage.py setup_periodic_tasks

Run once after initial `migrate`. Tasks can also be managed via Django Admin
at /admin/django_celery_beat/periodictask/.
"""
from django.core.management.base import BaseCommand
from django_celery_beat.models import CrontabSchedule, PeriodicTask
from django.conf import settings
import json


TASKS = [
    {
        'name': 'Agmarknet Price Sync (Daily 6 AM IST)',
        'task': 'apps.data_ingestion.tasks.sync_agmarknet_prices',
        'crontab': {'hour': '6', 'minute': '0', 'day_of_week': '*',
                    'day_of_month': '*', 'month_of_year': '*'},
        'kwargs': json.dumps({'state': 'Rajasthan'}),
        'description': 'Fetch daily mandi prices from Agmarknet via data.gov.in',
    },
    {
        'name': 'Detect Delayed Projects (Daily 9 AM IST)',
        'task': 'apps.data_ingestion.tasks.detect_delayed_projects',
        'crontab': {'hour': '9', 'minute': '0', 'day_of_week': '*',
                    'day_of_month': '*', 'month_of_year': '*'},
        'kwargs': '{}',
        'description': 'Flag in_progress projects that have passed expected_completion',
    },
    {
        'name': 'eGramSwaraj Fund Sync (Weekly Sunday 2 AM IST)',
        'task': 'apps.data_ingestion.tasks.sync_egram_swaraj',
        'crontab': {'hour': '2', 'minute': '0', 'day_of_week': '0',
                    'day_of_month': '*', 'month_of_year': '*'},
        'kwargs': '{}',
        'description': 'Sync panchayat fund data from eGramSwaraj DISHA dashboard',
    },
    {
        'name': 'Bhuvan NDVI Tile Refresh (Weekly Saturday Midnight IST)',
        'task': 'apps.data_ingestion.tasks.refresh_bhuvan_ndvi',
        'crontab': {'hour': '0', 'minute': '0', 'day_of_week': '6',
                    'day_of_month': '*', 'month_of_year': '*'},
        'kwargs': '{}',
        'description': 'Refresh Bhuvan ISRO satellite NDVI data for all villages',
    },
    {
        'name': 'CGWB Groundwater Sync (Quarterly)',
        'task': 'apps.data_ingestion.tasks.sync_cgwb_groundwater',
        'crontab': {'hour': '3', 'minute': '0', 'day_of_week': '*',
                    'day_of_month': '1', 'month_of_year': '1,4,7,10'},
        'kwargs': '{}',
        'description': 'Sync groundwater depth data from CGWB India-WRIS',
    },
    {
        'name': 'myScheme Descriptions Sync (Weekly Monday 4 AM IST)',
        'task': 'apps.data_ingestion.tasks.sync_myscheme_schemes',
        'crontab': {'hour': '4', 'minute': '0', 'day_of_week': '1',
                    'day_of_month': '*', 'month_of_year': '*'},
        'kwargs': '{}',
        'description': 'Fetch real scheme eligibility/benefits from myscheme.gov.in',
    },
    {
        'name': 'data.gov.in District Stats Sync (Weekly Monday 5 AM IST)',
        'task': 'apps.data_ingestion.tasks.sync_datagov_district_stats',
        'crontab': {'hour': '5', 'minute': '0', 'day_of_week': '1',
                    'day_of_month': '*', 'month_of_year': '*'},
        'kwargs': '{}',
        'description': 'Fetch MGNREGA/JJM district stats from data.gov.in API',
    },
]


class Command(BaseCommand):
    help = 'Seed Celery Beat periodic tasks into the database (idempotent — safe to re-run)'

    def handle(self, *args, **options):
        created_count = 0
        updated_count = 0

        for task_def in TASKS:
            crontab_params = task_def['crontab']
            crontab_params['timezone'] = 'Asia/Kolkata'
            schedule, _ = CrontabSchedule.objects.get_or_create(**crontab_params)

            obj, created = PeriodicTask.objects.update_or_create(
                name=task_def['name'],
                defaults={
                    'task': task_def['task'],
                    'crontab': schedule,
                    'kwargs': task_def.get('kwargs', '{}'),
                    'enabled': True,
                    'description': task_def.get('description', ''),
                },
            )

            if created:
                created_count += 1
                self.stdout.write(self.style.SUCCESS(f'  [CREATED] {obj.name}'))
            else:
                updated_count += 1
                self.stdout.write(self.style.WARNING(f'  [UPDATED] {obj.name}'))

        self.stdout.write(
            self.style.SUCCESS(
                f'\nDone: {created_count} tasks created, {updated_count} tasks updated.\n'
                f'Manage tasks at /admin/django_celery_beat/periodictask/'
            )
        )
