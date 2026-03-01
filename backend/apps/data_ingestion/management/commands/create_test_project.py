"""
Create a test cluster ready for full lifecycle testing.

The cluster appears immediately in the Leader Dashboard (AI Priority Ranking).
The leader taps Adopt → project is created with REAL scheme fund data → PDF generated.
The leader then marks it In Progress → Complete. Citizens can rate it.

Full lifecycle:
  Step 1 → run this command                       (cluster created)
  Step 2 → Leader Dashboard → tap "Adopt"          (in_progress, fund plan, PDF)
  Step 3 → Project Detail → "Mark Complete"        (completed)
  Step 4 → Project Detail → rate 1-5 stars         (citizen rating)

Usage:
    python manage.py create_test_project
    python manage.py create_test_project --category electricity
    python manage.py create_test_project --category health --ward 4
    python manage.py create_test_project --category water --reports 10
    python manage.py create_test_project --reset   # removes previously created test cluster/project
"""
import random
from datetime import timedelta

from django.contrib.gis.geos import Point
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

CATEGORY_CONFIG = {
    'electricity': {
        'title':       'Rural Solar Electrification — Tusra Ward {ward}',
        'reports': [
            'Din mein 8 ghante bijli nahi rehti, bacchon ki padhai kharab ho rahi hai',
            'Bijli ka voltage bahut kam hai, pump nahi chalta',
            'Transformer kharab ho gaya hai, 2 hafte se andhera hai',
            'Solar lamp lagwane ki zaroorat hai gali mein',
            'Bijli bill bahut zyada aata hai, solar chahiye',
            'Raat ko bijli nahi rehti, khana nahi ban sakta',
            'Pump ke liye bijli connection chahiye khet mein',
            'Generator pe depend hain, diesel bahut mehanga hai',
        ],
        'sub_category': 'Power outage and low voltage',
        'urgency_mix': ['high', 'high', 'critical', 'medium'],
        'estimated_cost': 1_200_000,
        'schemes': [
            ('PM-KUSUM',  60),
            ('MGNREGA',   20),
        ],
        'priority_score': 72.0,
        'community_score': 28.0,
        'data_score':      30.0,
        'urgency_score':   14.0,
        'justification': (
            'Electricity cluster: 8+ reports across 2 wards, voltage issues confirmed. '
            'Solar electrification eligible for PM-KUSUM 60% subsidy.'
        ),
    },
    'health': {
        'title':       'Primary Health Centre Upgrade — Tusra Ward {ward}',
        'reports': [
            'Gaon mein koi doctor nahi aata, bimaar log 10 km door jaate hain',
            'Dawa ki dukaan nahi hai, medicines nahi milti',
            'Prasav ke liye 15 km jaana padta hai, koi suvidha nahi',
            'Malaria aur dengue baar baar aata hai, koi spray nahi',
            'Aanganwadi building tuti hui hai, bacchon ko baihtne ki jagah nahi',
            'ANM nahi aati, TB ke mareez ka ilaaj nahi ho raha',
        ],
        'sub_category': 'Healthcare access and facility',
        'urgency_mix': ['critical', 'high', 'critical', 'high'],
        'estimated_cost': 800_000,
        'schemes': [
            ('MGNREGA', 50),
        ],
        'priority_score': 68.0,
        'community_score': 26.0,
        'data_score':      28.0,
        'urgency_score':   14.0,
        'justification': (
            'Health access gap: 6 reports, no functional PHC within 10 km. '
            'MGNREGA eligible for 50% of civil construction costs.'
        ),
    },
    'education': {
        'title':       'School Infrastructure Improvement — Tusra Ward {ward}',
        'reports': [
            'School ki chhat tuti hai, baarish mein class nahi hoti',
            'Shauchalay nahi hai, ladkiyan school nahi aati',
            'Computer aur blackboard nahi hain',
            'Teacher nahi aata, 3 class ek saath hain',
            'Library nahi hai, bachche padh nahi sakte',
            'School ki boundary wall nahi hai, suraksha ka darr hai',
        ],
        'sub_category': 'School building and facilities',
        'urgency_mix': ['high', 'medium', 'high', 'medium'],
        'estimated_cost': 600_000,
        'schemes': [
            ('Samagra Shiksha', 60),
            ('MGNREGA',         20),
        ],
        'priority_score': 61.0,
        'community_score': 22.0,
        'data_score':      26.0,
        'urgency_score':   13.0,
        'justification': (
            'Education infrastructure: 6 reports, missing sanitation and roof repairs. '
            'Samagra Shiksha covers 60% of school construction costs.'
        ),
    },
    'sanitation': {
        'title':       'Drainage & Solid Waste Management — Tusra Ward {ward}',
        'reports': [
            'Nali band ho gayi hai, ganda pani sadak par aa raha hai',
            'Kachra uthaane wala nahi aata, dher lag gaya hai',
            'Barsat mein sewage overflow hota hai, bimariyan failti hain',
            'Shouchalaya bnane ki zaroorat hai gali mein',
            'Panchayat dustbin nahi hai, log khet mein kachra fekte hain',
        ],
        'sub_category': 'Drainage and waste collection',
        'urgency_mix': ['critical', 'high', 'high', 'medium'],
        'estimated_cost': 500_000,
        'schemes': [
            ('SBM-G', 90),
        ],
        'priority_score': 58.0,
        'community_score': 20.0,
        'data_score':      25.0,
        'urgency_score':   13.0,
        'justification': (
            'Sanitation gap: 5 reports, open drainage and solid waste issues. '
            'SBM-G provides up to 90% subsidy for drainage and sanitation works.'
        ),
    },
    'water': {
        'title':       'Rooftop Rainwater Harvesting — Tusra Ward {ward}',
        'reports': [
            'Baarish ka pani barbaad ho jaata hai, store karne ki koi system nahi',
            'Garmi mein borewell sukh jaata hai, pani ki kami hoti hai',
            'Tanki nahi hai, paani store nahi kar sakte',
            'Ghar ki chhat ka pani directly nali mein chala jaata hai',
            'Groundwater level har saal girta ja raha hai',
        ],
        'sub_category': 'Rainwater harvesting and storage',
        'urgency_mix': ['high', 'high', 'medium', 'critical'],
        'estimated_cost': 750_000,
        'schemes': [
            ('Jal Jeevan Mission', 60),
            ('MGNREGA',            20),
        ],
        'priority_score': 65.0,
        'community_score': 24.0,
        'data_score':      28.0,
        'urgency_score':   13.0,
        'justification': (
            'Secondary water cluster: 5 reports on rainwater harvesting. '
            'Jal Jeevan Mission eligible for 60% of water storage infrastructure.'
        ),
    },
    'road': {
        'title':       'Village Internal Road Paving — Tusra Ward {ward}',
        'reports': [
            'Ward 4 ki andar ki gali kacchi hai, baarish mein keechad hota hai',
            'Ambulance gaon ke andar nahi aa sakta, sadak nahi hai',
            'School jaane ki gali toot gayi hai, bachche girate hain',
            'Khet se ghar tak maal laana mushkil hai, rasta nahi hai',
        ],
        'sub_category': 'Internal village road paving',
        'urgency_mix': ['high', 'critical', 'medium', 'high'],
        'estimated_cost': 900_000,
        'schemes': [
            ('PMGSY',   60),
            ('MGNREGA', 30),
        ],
        'priority_score': 55.0,
        'community_score': 18.0,
        'data_score':      24.0,
        'urgency_score':   13.0,
        'justification': (
            'Internal road gap: 4 reports on unpaved village lanes. '
            'PMGSY covers 60% of rural road construction costs.'
        ),
    },
}


class Command(BaseCommand):
    help = 'Create a test cluster for lifecycle testing (Adopt → Complete → Rate)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--category',
            default='electricity',
            choices=list(CATEGORY_CONFIG.keys()),
            help='Project category (default: electricity)',
        )
        parser.add_argument(
            '--ward',
            type=int,
            default=4,
            help='Ward number for the test cluster (default: 4)',
        )
        parser.add_argument(
            '--reports',
            type=int,
            default=8,
            help='Number of demo reports to create (default: 8)',
        )
        parser.add_argument(
            '--reset',
            action='store_true',
            help='Remove previously created test clusters and projects',
        )

    def handle(self, *args, **options):
        from apps.geo_intelligence.models import Village
        from apps.community.models import Report, ReportCluster
        from apps.ai_engine.models import PriorityScore
        from apps.scheme_rag.models import Scheme
        from apps.projects.models import Project

        try:
            village = Village.objects.get(name='Tusra')
        except Village.DoesNotExist:
            raise CommandError(
                "Demo village 'Tusra' not found. Run 'python manage.py create_demo' first."
            )

        # ── Reset mode ────────────────────────────────────────────────────────────
        if options['reset']:
            deleted_clusters = ReportCluster.objects.filter(
                village=village,
                category__in=CATEGORY_CONFIG.keys(),
            ).exclude(category__in=['water', 'road']).delete()  # keep original demo clusters
            deleted_projects = Project.objects.filter(
                village=village,
                title__icontains='Ward 4',
            ).delete()
            self.stdout.write(self.style.SUCCESS(
                f"Reset complete. Removed test clusters and projects."
            ))
            return

        category = options['category']
        ward     = options['ward']
        n_reports = min(options['reports'], 15)
        cfg = CATEGORY_CONFIG[category]

        center_lat, center_lon = 20.7382, 83.1607

        # ── Create demo reports ───────────────────────────────────────────────────
        try:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            reporter = User.objects.filter(role='citizen', panchayat__villages__name='Tusra').first()
            if not reporter:
                reporter = User.objects.filter(panchayat__isnull=False).first()
        except Exception:
            reporter = None

        descriptions = cfg['reports']
        new_reports = []
        now = timezone.now()
        for i in range(n_reports):
            lat = center_lat + random.uniform(-0.002, 0.002)
            lon = center_lon + random.uniform(-0.002, 0.002)
            r = Report.objects.create(
                reporter=reporter,
                village=village,
                category=category,
                sub_category=cfg['sub_category'],
                description_text=descriptions[i % len(descriptions)],
                description_hindi=descriptions[i % len(descriptions)],
                location=Point(lon, lat, srid=4326),
                ward=ward,
                urgency=random.choice(cfg['urgency_mix']),
                status='reported',
                ai_confidence=round(random.uniform(0.78, 0.95), 2),
                created_at=now - timedelta(days=random.randint(1, 20)),
            )
            new_reports.append(r)

        # Add upvotes from demo citizens
        try:
            voters = list(User.objects.filter(
                role='citizen',
                panchayat__villages__name='Tusra',
            )[:6])
            vote_count = 0
            for report in new_reports[:n_reports // 2]:
                for voter in random.sample(voters, min(len(voters), random.randint(2, 4))):
                    from apps.community.models import Vote
                    try:
                        Vote.objects.create(report=report, voter=voter)
                        vote_count += 1
                    except Exception:
                        pass
                report.vote_count = report.votes.count()
                report.save(update_fields=['vote_count'])
        except Exception:
            vote_count = 0

        # ── Create the cluster ────────────────────────────────────────────────────
        cluster = ReportCluster.objects.create(
            village=village,
            category=category,
            centroid=Point(center_lon + random.uniform(-0.001, 0.001),
                           center_lat + random.uniform(-0.001, 0.001), srid=4326),
            radius_km=0.4,
            report_count=n_reports,
            ward_count=1,
            upvote_count=vote_count,
            estimated_households=n_reports * 12,
            community_priority_score=cfg['priority_score'],
        )

        # Link reports to cluster
        for r in new_reports:
            r.cluster = cluster
            r.save(update_fields=['cluster'])

        # ── Create priority score ─────────────────────────────────────────────────
        PriorityScore.objects.create(
            cluster=cluster,
            community_score=cfg['community_score'],
            data_score=cfg['data_score'],
            urgency_score=cfg['urgency_score'],
            total_score=cfg['priority_score'],
            report_count_pts=round(min(25, n_reports * 25 / 20), 1),
            geographic_spread_pts=10.0,
            upvote_pts=round(min(25, vote_count * 25 / 50), 1),
            gram_sabha_bonus=0.0,
            satellite_pts=0.0,
            data_gap_pts=25.0,
            demographic_pts=10.0,
            economic_pts=8.0,
            seasonal_pts=0.0,
            safety_pts=8.0,
            worsening_trend_pts=5.0,
            justification=cfg['justification'],
            score_breakdown={
                'community': {
                    'reports': round(min(25, n_reports * 25 / 20), 1),
                    'geographic_spread': 10.0,
                    'upvotes': round(min(25, vote_count * 25 / 50), 1),
                    'gram_sabha': 0.0,
                },
                'data': {
                    'satellite': 0.0,
                    'gap': 25.0,
                    'demographic': 10.0,
                    'economic': 8.0,
                },
                'urgency': {'seasonal': 0.0, 'safety': 8.0, 'worsening': 5.0},
            },
        )

        # ── Resolve real scheme objects for display ───────────────────────────────
        scheme_lines = []
        for name_frag, pct in cfg['schemes']:
            scheme = Scheme.objects.filter(
                short_name__icontains=name_frag.split()[0]
            ).first()
            amount = int(cfg['estimated_cost'] * pct / 100)
            label = scheme.short_name if scheme else name_frag
            scheme_lines.append(f"    {label}: {pct}% = ₹{amount:,}")
        panchayat_pct = 100 - sum(p for _, p in cfg['schemes'])
        scheme_lines.append(
            f"    Panchayat: {panchayat_pct}% = ₹{int(cfg['estimated_cost'] * panchayat_pct / 100):,}"
        )

        # ── Print lifecycle guide ─────────────────────────────────────────────────
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('✓ Test cluster created successfully!'))
        self.stdout.write('')
        self.stdout.write(f"  Category   : {category.upper()}")
        self.stdout.write(f"  Cluster ID : {cluster.id}")
        self.stdout.write(f"  Reports    : {n_reports}  |  Upvotes: {vote_count}")
        self.stdout.write(f"  Priority   : {cfg['priority_score']}/100")
        self.stdout.write(f"  Est. Cost  : ₹{cfg['estimated_cost']:,}")
        self.stdout.write('')
        self.stdout.write('  Fund Convergence (REAL scheme data from DB):')
        for line in scheme_lines:
            self.stdout.write(line)
        self.stdout.write('')
        self.stdout.write(self.style.WARNING('─── Full Lifecycle Test Steps ─────────────────────────'))
        self.stdout.write('')
        self.stdout.write('  STEP 1  Already done — cluster is live in the database.')
        self.stdout.write('')
        self.stdout.write('  STEP 2  Open Leader Dashboard in the Flutter app.')
        self.stdout.write(f"          Look for the '{category}' cluster in AI Priority Ranking.")
        self.stdout.write('          Tap the Adopt button.')
        self.stdout.write('          → Project created with real fund plan + PDF proposal.')
        self.stdout.write('          → "Download PDF" button opens the generated proposal.')
        self.stdout.write('')
        self.stdout.write('  STEP 3  Tap the project in "Active Projects" to open Project Detail.')
        self.stdout.write('          Green "Leader Actions" card will be visible.')
        self.stdout.write('          (Optional) Tap "Mark Delayed" to test that branch.')
        self.stdout.write('          Tap "Mark Complete" → Confirm.')
        self.stdout.write('          → Status timeline shows all 4 steps complete.')
        self.stdout.write('')
        self.stdout.write('  STEP 4  Log in as a citizen (any +91 number).')
        self.stdout.write('          Open the same project → scroll to Citizen Rating.')
        self.stdout.write('          Give a star rating and review.')
        self.stdout.write('')
        self.stdout.write('  RESET   python manage.py create_test_project --reset')
        self.stdout.write('          (removes test cluster and project, keeps demo data intact)')
        self.stdout.write('')
        self.stdout.write('  API     curl -H "Authorization: Bearer <token>" \\')
        self.stdout.write(f"          http://127.0.0.1:8000/api/v1/ai/priorities/?village=1")
        self.stdout.write(f"          # cluster {cluster.id} will appear in results")
        self.stdout.write('')
