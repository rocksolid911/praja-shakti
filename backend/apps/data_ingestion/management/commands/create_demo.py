"""
Create demo data for hackathon: Tusra village, Balangir district, Odisha.

Usage: python manage.py create_demo
"""
import random
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.contrib.gis.geos import Point, MultiPolygon, Polygon
from django.utils import timezone


class Command(BaseCommand):
    help = 'Create demo data for Tusra village, Balangir, Odisha'

    def handle(self, *args, **options):
        self.stdout.write("Creating demo data for PrajaShakti AI...")

        self._create_geography()
        self._create_users()
        self._link_firebase_test_phones()
        self._create_schemes()
        self._create_reports()
        self._create_clusters()
        self._create_projects()
        self._create_infrastructure()

        self.stdout.write(self.style.SUCCESS("Demo data created successfully!"))

    def _create_geography(self):
        from apps.geo_intelligence.models import State, District, Block, Panchayat, Village

        state, _ = State.objects.update_or_create(
            lgd_code='21', defaults={'name': 'Odisha'}
        )
        district, _ = District.objects.update_or_create(
            lgd_code='2115', defaults={'name': 'Balangir', 'state': state}
        )
        block, _ = Block.objects.update_or_create(
            lgd_code='211501', defaults={'name': 'Tusura', 'district': district}
        )
        panchayat, _ = Panchayat.objects.update_or_create(
            lgd_code='21150101', defaults={
                'name': 'Tusra',
                'block': block,
                'population': 5200,
                'households': 980,
                'area_sq_km': 8.5,
                'fund_available_inr': 1500000,
            }
        )

        # Tusra village — approximate coordinates in Balangir
        center_lat, center_lon = 20.7382, 83.1607
        village, _ = Village.objects.update_or_create(
            lgd_code='2115010101', defaults={
                'name': 'Tusra',
                'panchayat': panchayat,
                'location': Point(center_lon, center_lat, srid=4326),
                'population': 4800,
                'households': 890,
                'agricultural_households': 340,
                'groundwater_depth_m': 14.2,
                'ndvi_score': 0.12,
                'ndvi_updated_at': timezone.now() - timedelta(days=3),
            }
        )

        self.village = village
        self.panchayat = panchayat
        self.stdout.write(f"  Created geography: {village.name}, {district.name}, {state.name}")

    def _create_users(self):
        from django.contrib.auth import get_user_model
        User = get_user_model()

        # Note: phone 9876543210 is reserved for Firebase test user (Sabal Sharma)
        # First clean up any old demo user on that phone
        User.objects.filter(phone='9876543210', username='citizen_demo').update(
            phone='9876500000', username='ramesh_demo',
        )
        self.citizen, _ = User.objects.update_or_create(
            phone='9876500000', defaults={
                'username': 'ramesh_demo',
                'first_name': 'Ramesh',
                'last_name': 'Sahu',
                'role': 'citizen',
                'panchayat': self.panchayat,
                'ward': 3,
                'language_preference': 'or',
            }
        )
        self.citizen.set_password('demo123')
        self.citizen.save()

        self.leader, _ = User.objects.update_or_create(
            phone='9876543211', defaults={
                'username': 'leader_demo',
                'first_name': 'Sushila',
                'last_name': 'Nayak',
                'role': 'leader',
                'panchayat': self.panchayat,
                'ward': None,
                'language_preference': 'or',
            }
        )
        self.leader.set_password('demo123')
        self.leader.save()

        self.admin_user, _ = User.objects.update_or_create(
            phone='9876543212', defaults={
                'username': 'admin_demo',
                'first_name': 'Admin',
                'last_name': 'PrajaShakti',
                'role': 'admin',
                'panchayat': self.panchayat,
                'is_staff': True,
                'is_superuser': True,
            }
        )
        self.admin_user.set_password('admin123')
        self.admin_user.save()

        # Extra citizens for voting diversity
        self.extra_citizens = []
        names = [
            ('Lakshmi', 'Behera'), ('Mohan', 'Majhi'), ('Priti', 'Patel'),
            ('Bikash', 'Suna'), ('Gitanjali', 'Bag'), ('Suresh', 'Meher'),
            ('Parbati', 'Nag'), ('Dinesh', 'Sahu'), ('Anjali', 'Dash'),
            ('Ranjan', 'Pradhan'),
        ]
        for i, (first, last) in enumerate(names):
            user, _ = User.objects.update_or_create(
                phone=f'98765432{20+i}', defaults={
                    'username': f'citizen_{i}',
                    'first_name': first, 'last_name': last,
                    'role': 'citizen', 'panchayat': self.panchayat,
                    'ward': random.choice([3, 5]),
                }
            )
            self.extra_citizens.append(user)

        self.stdout.write(f"  Created {3 + len(self.extra_citizens)} users")

    def _link_firebase_test_phones(self):
        """Create / update users matching the 5 Firebase Auth test phone numbers."""
        from django.contrib.auth import get_user_model
        User = get_user_model()

        firebase_test_users = [
            {
                'phone': '9123456780',
                'defaults': {
                    'username': 'firebase_citizen_1',
                    'first_name': 'Mahesh',
                    'last_name': 'Raman',
                    'role': 'citizen',
                    'panchayat': self.panchayat,
                    'ward': 3,
                    'language_preference': 'hi',
                },
            },
            {
                'phone': '9876543210',
                'defaults': {
                    'username': 'firebase_govt_1',
                    'first_name': 'Sabal',
                    'last_name': 'Sharma',
                    'role': 'government',
                    'panchayat': self.panchayat,
                    'language_preference': 'hi',
                },
            },
            {
                'phone': '9999911111',
                'defaults': {
                    'username': 'firebase_citizen_2',
                    'first_name': 'Kunal',
                    'last_name': 'Sharma',
                    'role': 'citizen',
                    'panchayat': self.panchayat,
                    'ward': 5,
                    'language_preference': 'hi',
                },
            },
            {
                'phone': '9090291939',
                'defaults': {
                    'username': 'firebase_leader',
                    'first_name': 'Siddharth',
                    'last_name': 'Leader',
                    'role': 'leader',
                    'panchayat': self.panchayat,
                    'language_preference': 'hi',
                },
            },
            {
                'phone': '8149443114',
                'defaults': {
                    'username': 'firebase_govt_2',
                    'first_name': 'Government',
                    'last_name': 'Officer',
                    'role': 'government',
                    'panchayat': self.panchayat,
                    'language_preference': 'hi',
                },
            },
        ]

        for entry in firebase_test_users:
            User.objects.update_or_create(
                phone=entry['phone'],
                defaults=entry['defaults'],
            )

        self.stdout.write(f"  Linked {len(firebase_test_users)} Firebase test phone users")

    def _create_schemes(self):
        from apps.scheme_rag.models import Scheme

        schemes_data = [
            {'short_name': 'PM-KUSUM', 'name': 'Pradhan Mantri Kisan Urja Suraksha evam Utthaan Mahabhiyan',
             'ministry': 'MNRE', 'category': 'water',
             'description': 'PM-KUSUM provides subsidized solar water pumps for farmers. Component-B: standalone solar pumps up to 7.5 HP with 60% subsidy (30% Central + 30% State). Farmers contribute 40% (can get bank loan for 30%). Eligible: individual farmers with land ownership.',
             'max_subsidy_pct': 60},
            {'short_name': 'MGNREGA', 'name': 'Mahatma Gandhi National Rural Employment Guarantee Act',
             'ministry': 'MoRD', 'category': 'infrastructure',
             'description': 'MGNREGA guarantees 100 days of wage employment per household per year. Works include: road construction, water conservation structures, irrigation channels, land development, flood control. 100% central funding for material and labor.',
             'max_subsidy_pct': 100},
            {'short_name': 'Jal Jeevan Mission', 'name': 'Jal Jeevan Mission (Har Ghar Jal)',
             'ministry': 'Ministry of Jal Shakti', 'category': 'water',
             'description': 'Jal Jeevan Mission aims to provide functional household tap connections (FHTC) to every rural household by 2024. Central:State funding 90:10 for special category states, 50:50 for others. Minimum 55 LPCD water supply.',
             'max_subsidy_pct': 90},
            {'short_name': 'PMAY-G', 'name': 'Pradhan Mantri Awaas Yojana - Gramin',
             'ministry': 'MoRD', 'category': 'housing',
             'description': 'PMAY-G provides financial assistance for construction of pucca house with basic amenities. Rs.1.20 lakh in plain areas, Rs.1.30 lakh in hilly/difficult areas. Beneficiary identified through SECC data.',
             'max_subsidy_pct': 100},
            {'short_name': 'PM-KISAN', 'name': 'Pradhan Mantri Kisan Samman Nidhi',
             'ministry': 'MoA&FW', 'category': 'agriculture',
             'description': 'PM-KISAN provides income support of Rs.6000 per year to farmer families in three equal installments. All landholding farmer families eligible (subject to exclusion criteria).',
             'max_subsidy_pct': 100},
            {'short_name': 'PMGSY', 'name': 'Pradhan Mantri Gram Sadak Yojana',
             'ministry': 'MoRD', 'category': 'road',
             'description': 'PMGSY provides all-weather road connectivity to unconnected habitations. Phase-III covers upgradation of existing roads. Funding: 60:40 (Centre:State) ratio.',
             'max_subsidy_pct': 60},
            {'short_name': 'SBM-G', 'name': 'Swachh Bharat Mission - Gramin',
             'ministry': 'Ministry of Jal Shakti', 'category': 'sanitation',
             'description': 'SBM-G Phase II focuses on ODF Plus: managing solid and liquid waste. Rs.12000 incentive for individual household latrines. Community sanitation complexes funded up to Rs.3 lakh.',
             'max_subsidy_pct': 100},
            {'short_name': 'PMFBY', 'name': 'Pradhan Mantri Fasal Bima Yojana',
             'ministry': 'MoA&FW', 'category': 'insurance',
             'description': 'PMFBY provides crop insurance at low premium: 2% for Kharif, 1.5% for Rabi, 5% for commercial/horticulture crops. Government pays remaining premium. Covers yield losses, prevented sowing, post-harvest losses.',
             'max_subsidy_pct': 95},
            {'short_name': 'DDU-GKY', 'name': 'Deen Dayal Upadhyaya Grameen Kaushalya Yojana',
             'ministry': 'MoRD', 'category': 'skill',
             'description': 'DDU-GKY provides skill training and placement to rural poor youth aged 15-35 years. Training duration: 3-12 months. Mandatory 75% placement. Focus on SC/ST/women/minorities.',
             'max_subsidy_pct': 100},
            {'short_name': 'NRLM/DAY-NRLM', 'name': 'Deendayal Antyodaya Yojana - NRLM',
             'ministry': 'MoRD', 'category': 'livelihood',
             'description': 'DAY-NRLM promotes self-employment through SHGs. Revolving fund of Rs.10000-15000 per SHG. Community Investment Fund up to Rs.2.5 lakh per SHG. Interest subvention on loans up to Rs.3 lakh.',
             'max_subsidy_pct': 100},
            {'short_name': 'Samagra Shiksha', 'name': 'Samagra Shiksha Abhiyan',
             'ministry': 'MoE', 'category': 'education',
             'description': 'Samagra Shiksha is an overarching programme for school education from pre-school to class 12. Covers infrastructure grants, teacher training, ICT labs, inclusive education. Funding: 60:40 (Centre:State).',
             'max_subsidy_pct': 60},
            {'short_name': 'NSAP', 'name': 'National Social Assistance Programme',
             'ministry': 'MoRD', 'category': 'social_security',
             'description': 'NSAP provides social security pensions: Old age (Rs.200-500/month), widow pension, disability pension. For BPL families. States add top-up amounts.',
             'max_subsidy_pct': 100},
        ]

        for s_data in schemes_data:
            Scheme.objects.update_or_create(
                short_name=s_data['short_name'],
                defaults=s_data,
            )

        self.stdout.write(f"  Created {len(schemes_data)} schemes")

    def _create_reports(self):
        from apps.community.models import Report, Vote

        center_lat, center_lon = 20.7382, 83.1607
        now = timezone.now()
        all_users = [self.citizen] + self.extra_citizens

        # Create 59 water reports in Ward 3 and 5
        water_descriptions = [
            "Handpump kharab ho gaya hai, pani nahi aa raha",
            "Village mein pani ki bahut kami hai, borwell sukh gaya",
            "Ghar tak paani ki pipeline nahi hai, door se laana padta hai",
            "Borewell ka pani khatam ho gaya, naya borewell chahiye",
            "Bachche ko pani ki wajah se bimari ho gayi",
            "Khet mein sinchai ke liye pani nahi mil raha",
            "Nadi ka pani ganda ho gaya hai, peene layak nahi",
            "Handpump mein iron ka pani aa raha hai",
            "Summer mein pani ki bahut tangi hoti hai",
            "Mahilaon ko 2 km door se pani laana padta hai",
            "Tanker se pani aata hai lekin kaafi nahi hai",
            "Solar pump lagane ki zaroorat hai khet mein",
            "Panchayat ka overhead tank kharab hai",
            "Pani mein fluoride bahut zyada hai",
            "Baarish ka pani store karne ki koi vyavastha nahi",
        ]

        self.reports = []
        for i in range(59):
            lat = center_lat + random.uniform(-0.003, 0.003)
            lon = center_lon + random.uniform(-0.003, 0.003)
            ward = random.choice([3, 5])
            reporter = random.choice(all_users)
            desc = random.choice(water_descriptions)

            report = Report.objects.create(
                reporter=reporter,
                village=self.village,
                category='water',
                sub_category='Water scarcity and access',
                description_text=desc,
                description_hindi=desc,
                location=Point(lon, lat, srid=4326),
                ward=ward,
                urgency=random.choice(['high', 'critical', 'high', 'medium']),
                status='reported',
                ai_confidence=random.uniform(0.75, 0.95),
                is_gram_sabha=(i < 5),
                created_at=now - timedelta(days=random.randint(1, 30)),
            )
            self.reports.append(report)

        # Add votes (47 total across reports)
        vote_count = 0
        for report in self.reports[:30]:
            voters = random.sample(all_users, random.randint(1, 4))
            for voter in voters:
                try:
                    Vote.objects.create(report=report, voter=voter)
                    vote_count += 1
                except Exception:
                    pass
            report.vote_count = report.votes.count()
            report.save(update_fields=['vote_count'])

        # Add some reports for other categories
        other_reports = [
            {'category': 'road', 'desc': 'Main road mein bahut gadde hain, accident hota hai', 'urgency': 'high', 'ward': 3},
            {'category': 'road', 'desc': 'Barsat mein sadak bahut kharab ho jaati hai', 'urgency': 'medium', 'ward': 5},
            {'category': 'health', 'desc': 'Gaon mein koi doctor nahi aata', 'urgency': 'high', 'ward': 3},
            {'category': 'education', 'desc': 'School ki building bahut purani hai, darwaze tute hain', 'urgency': 'medium', 'ward': 5},
            {'category': 'electricity', 'desc': 'Din mein 6 ghante bijli nahi rehti', 'urgency': 'high', 'ward': 3},
            {'category': 'sanitation', 'desc': 'Nali band ho gayi hai, ganda pani sadak par aa raha', 'urgency': 'critical', 'ward': 5},
        ]
        for item in other_reports:
            lat = center_lat + random.uniform(-0.003, 0.003)
            lon = center_lon + random.uniform(-0.003, 0.003)
            Report.objects.create(
                reporter=random.choice(all_users),
                village=self.village,
                category=item['category'],
                description_text=item['desc'],
                description_hindi=item['desc'],
                location=Point(lon, lat, srid=4326),
                ward=item['ward'],
                urgency=item['urgency'],
                status='reported',
                ai_confidence=0.85,
            )

        self.stdout.write(f"  Created {59 + len(other_reports)} reports, {vote_count} votes")

    def _create_clusters(self):
        from apps.community.models import Report, ReportCluster
        from apps.ai_engine.models import PriorityScore

        center_lat, center_lon = 20.7382, 83.1607

        # Main water cluster
        water_cluster, _ = ReportCluster.objects.update_or_create(
            village=self.village,
            category='water',
            defaults={
                'centroid': Point(center_lon + 0.001, center_lat - 0.001, srid=4326),
                'radius_km': 0.5,
                'report_count': 59,
                'ward_count': 2,
                'upvote_count': 47,
                'estimated_households': 320,
                'community_priority_score': 94.0,
            }
        )

        # Assign water reports to cluster
        Report.objects.filter(village=self.village, category='water').update(cluster=water_cluster)

        # Create priority score for water cluster
        PriorityScore.objects.update_or_create(
            cluster=water_cluster,
            defaults={
                'community_score': 37.6,
                'data_score': 38.4,
                'urgency_score': 18.0,
                'total_score': 94.0,
                'report_count_pts': 25.0,
                'geographic_spread_pts': 10.0,
                'upvote_pts': 22.0,
                'gram_sabha_bonus': 20.0,
                'satellite_pts': 25.0,
                'data_gap_pts': 25.0,
                'demographic_pts': 18.0,
                'economic_pts': 21.0,
                'seasonal_pts': 0.0,
                'safety_pts': 8.0,
                'worsening_trend_pts': 10.0,
                'justification': (
                    'Priority Score: 94/100 for water issues in Tusra. '
                    'Community voice is strong with 59 reports across 2 wards and 47 upvotes, '
                    'including 5 Gram Sabha mentions. Satellite data confirms severe vegetation '
                    'stress (NDVI 0.12) and groundwater depth at 14.2m validates community concerns. '
                    'No active water project exists — critical gap. Immediate attention recommended.'
                ),
                'score_breakdown': {
                    'community': {'reports': 25.0, 'geographic_spread': 10.0, 'upvotes': 22.0, 'gram_sabha': 20.0},
                    'data': {'satellite': 25.0, 'gap': 25.0, 'demographic': 18.0, 'economic': 21.0},
                    'urgency': {'seasonal': 0.0, 'safety': 8.0, 'worsening': 10.0},
                },
            }
        )

        # Road cluster (smaller)
        road_cluster, _ = ReportCluster.objects.update_or_create(
            village=self.village,
            category='road',
            defaults={
                'centroid': Point(center_lon - 0.002, center_lat + 0.001, srid=4326),
                'radius_km': 0.3,
                'report_count': 2,
                'ward_count': 2,
                'upvote_count': 5,
                'estimated_households': 150,
                'community_priority_score': 45.0,
            }
        )
        Report.objects.filter(village=self.village, category='road').update(cluster=road_cluster)

        PriorityScore.objects.update_or_create(
            cluster=road_cluster,
            defaults={
                'community_score': 12.0, 'data_score': 18.0, 'urgency_score': 15.0,
                'total_score': 45.0,
                'report_count_pts': 2.5, 'geographic_spread_pts': 10.0,
                'upvote_pts': 2.5, 'gram_sabha_bonus': 0.0,
                'satellite_pts': 0.0, 'data_gap_pts': 25.0,
                'demographic_pts': 8.0, 'economic_pts': 5.0,
                'seasonal_pts': 0.0, 'safety_pts': 10.0, 'worsening_trend_pts': 5.0,
                'justification': 'Road safety concerns reported by 2 community members.',
            }
        )

        self.water_cluster = water_cluster
        self.stdout.write("  Created 2 clusters with priority scores")

    def _create_projects(self):
        from apps.projects.models import Project, ProjectRating
        from apps.scheme_rag.models import Scheme, FundConvergencePlan

        center_lat, center_lon = 20.7382, 83.1607

        # Fetch scheme objects once for fund plan references
        pm_kusum = Scheme.objects.filter(short_name='PM-KUSUM').first()
        mgnrega  = Scheme.objects.filter(short_name='MGNREGA').first()
        jjm      = Scheme.objects.filter(short_name='Jal Jeevan Mission').first()
        pmgsy    = Scheme.objects.filter(short_name='PMGSY').first()
        sbm      = Scheme.objects.filter(short_name='SBM-G').first()

        # ── 1. Solar Borewell (water · recommended → leader adopts via dashboard) ──────
        solar_project, _ = Project.objects.update_or_create(
            village=self.village,
            title='Solar Borewell with Piped Supply - Tusra Ward 3 & 5',
            defaults=dict(
                cluster=self.water_cluster,
                description=(
                    'Install a solar-powered borewell with a piped water supply network '
                    'to serve 320+ households across Wards 3 and 5 of Tusra village. '
                    'Community reported 59 water-access issues with 47 upvotes; 5 issues '
                    'were raised at the Gram Sabha. Satellite NDVI of 0.12 confirms severe '
                    'vegetation stress and CGWB groundwater depth of 14.2 m confirms '
                    'borewell feasibility. Scope: borewell drilling (60 m), 5 HP solar pump, '
                    '2 km distribution pipeline, 3 community stand-posts, and one 10,000 L '
                    'overhead tank. No active water project exists — critical infrastructure gap.'
                ),
                category='water',
                location=Point(center_lon + 0.001, center_lat - 0.001, srid=4326),
                estimated_cost_inr=450000,
                beneficiary_count=320,
                impact_projection={
                    'households_served': 320,
                    'water_distance_km': 0.3,
                    'daily_water_liters': 17600,
                    'crop_yield_increase_pct': 25,
                    'income_increase_per_hh_inr': 33000,
                    'groundwater_depth_m': 14.2,
                },
                priority_score=94.0,
                ai_confidence=0.92,
                status='recommended',
            ),
        )

        solar_project.fund_convergence_plans.all().delete()
        FundConvergencePlan.objects.create(
            project=solar_project,
            total_cost_inr=450000,
            panchayat_contribution_inr=45000,
            savings_pct=90.0,
            schemes_used=[
                {'scheme_id': pm_kusum.id if pm_kusum else 1, 'scheme_name': 'PM-KUSUM',
                 'amount_inr': 270000, 'pct_covered': 60.0},
                {'scheme_id': mgnrega.id if mgnrega else 2, 'scheme_name': 'MGNREGA',
                 'amount_inr': 90000, 'pct_covered': 20.0},
                {'scheme_id': jjm.id if jjm else 3, 'scheme_name': 'Jal Jeevan Mission',
                 'amount_inr': 45000, 'pct_covered': 10.0},
            ],
        )

        # ── 2. Community Toilet Block (sanitation · completed) ───────────────────────
        completed_project, created = Project.objects.update_or_create(
            village=self.village,
            title='Community Toilet Block - Tusra Ward 5',
            defaults=dict(
                description=(
                    'Constructed a community sanitation complex with 6 toilet units (3 male / '
                    '3 female) under the Swachh Bharat Mission-Gramin (SBM-G) scheme in '
                    'Ward 5, Tusra. The facility includes a hand-washing station, septic tank, '
                    'and solar-powered LED lighting for night safety. Construction used MGNREGA '
                    'labour, providing 420 person-days of employment to local families. '
                    'The facility achieved Open Defecation Free (ODF) status for 150 households '
                    'and has been rated 4.2/5 by community members.'
                ),
                category='sanitation',
                location=Point(center_lon - 0.001, center_lat + 0.002, srid=4326),
                estimated_cost_inr=180000,
                beneficiary_count=150,
                impact_projection={
                    'households_served': 150,
                    'toilet_units_built': 6,
                    'odf_households_pct': 100,
                    'mgnrega_person_days': 420,
                    'disease_reduction_pct': 40,
                    'women_night_safety': 'Improved',
                },
                status='completed',
                adopted_by=self.leader,
                adopted_at=timezone.now() - timedelta(days=90),
                started_at=timezone.now() - timedelta(days=75),
                completed_at=timezone.now() - timedelta(days=10),
                expected_completion=(timezone.now() - timedelta(days=12)).date(),
                avg_citizen_rating=4.2,
            ),
        )

        # Fund plan for toilet block — SBM-G 90 % + Panchayat 10 %
        completed_project.fund_convergence_plans.all().delete()
        FundConvergencePlan.objects.create(
            project=completed_project,
            total_cost_inr=180000,
            panchayat_contribution_inr=18000,
            savings_pct=90.0,
            schemes_used=[
                {'scheme_id': sbm.id if sbm else 7, 'scheme_name': 'SBM-G',
                 'amount_inr': 162000, 'pct_covered': 90.0},
            ],
        )

        # Ratings — only add if just created to stay idempotent
        if created:
            for user in self.extra_citizens[:5]:
                ProjectRating.objects.get_or_create(
                    project=completed_project, citizen=user,
                    defaults=dict(
                        rating=random.choice([4, 5, 4, 3, 5]),
                        review=random.choice([
                            'Bahut accha kaam hua', 'Samay pe poora hua',
                            'Quality thodi aur better ho sakti thi', 'Parivaar ko labh mila',
                            'Shauchalaya ban gaya, ab door nahi jaana padta',
                        ]),
                    ),
                )

        # ── 3. Road Repair (road · in_progress) ─────────────────────────────────────
        road_project, _ = Project.objects.update_or_create(
            village=self.village,
            title='Road Repair - Tusra to Block HQ',
            defaults=dict(
                description=(
                    'Repair and upgrade the 3.5 km kaccha road connecting Tusra village to '
                    'Tusura Block Headquarters under PMGSY Phase-III. The road is the sole '
                    'motorable link for 500 households; it becomes impassable during the monsoon, '
                    'cutting off access to the primary health centre and weekly market. '
                    'Scope: granular sub-base, water-bound macadam surface, 4 culverts, and '
                    'two concrete causeways. MGNREGA labour contributes 30 % of civil works. '
                    'Expected completion in 45 days. Community reported 2 road-safety incidents '
                    'on this stretch in the past 6 months.'
                ),
                category='road',
                location=Point(center_lon + 0.003, center_lat, srid=4326),
                estimated_cost_inr=350000,
                beneficiary_count=500,
                impact_projection={
                    'households_connected': 500,
                    'road_length_km': 3.5,
                    'travel_time_reduction_min': 25,
                    'market_access': 'All-weather',
                    'mgnrega_person_days': 630,
                    'income_increase_per_hh_inr': 15000,
                },
                status='in_progress',
                adopted_by=self.leader,
                adopted_at=timezone.now() - timedelta(days=30),
                started_at=timezone.now() - timedelta(days=15),
                expected_completion=timezone.now().date() + timedelta(days=45),
            ),
        )

        # Fund plan for road — PMGSY 60 % + MGNREGA 30 % + Panchayat 10 %
        road_project.fund_convergence_plans.all().delete()
        FundConvergencePlan.objects.create(
            project=road_project,
            total_cost_inr=350000,
            panchayat_contribution_inr=35000,
            savings_pct=90.0,
            schemes_used=[
                {'scheme_id': pmgsy.id if pmgsy else 6, 'scheme_name': 'PMGSY',
                 'amount_inr': 210000, 'pct_covered': 60.0},
                {'scheme_id': mgnrega.id if mgnrega else 2, 'scheme_name': 'MGNREGA',
                 'amount_inr': 105000, 'pct_covered': 30.0},
            ],
        )

        self.stdout.write("  Created 3 projects with descriptions, impact projections, and fund plans")

    def _create_infrastructure(self):
        from apps.geo_intelligence.models import Infrastructure

        center_lat, center_lon = 20.7382, 83.1607

        infra_data = [
            {'type': 'school', 'name': 'Tusra Primary School', 'lat': center_lat + 0.002, 'lon': center_lon - 0.001, 'dist': 0.3},
            {'type': 'school', 'name': 'Tusra Upper Primary School', 'lat': center_lat - 0.003, 'lon': center_lon + 0.002, 'dist': 0.5},
            {'type': 'hospital', 'name': 'Tusra Health Sub-Centre', 'lat': center_lat + 0.001, 'lon': center_lon + 0.003, 'dist': 0.4},
            {'type': 'water_source', 'name': 'Community Handpump Ward 3', 'lat': center_lat - 0.001, 'lon': center_lon - 0.002, 'dist': 0.2},
            {'type': 'water_source', 'name': 'Borewell (Non-functional)', 'lat': center_lat + 0.002, 'lon': center_lon + 0.001, 'dist': 0.3},
            {'type': 'market', 'name': 'Weekly Haat Bazaar', 'lat': center_lat, 'lon': center_lon + 0.004, 'dist': 0.5},
            {'type': 'road', 'name': 'NH-26 Junction', 'lat': center_lat + 0.005, 'lon': center_lon - 0.003, 'dist': 1.2},
        ]

        for item in infra_data:
            Infrastructure.objects.update_or_create(
                village=self.village,
                name=item['name'],
                defaults={
                    'infra_type': item['type'],
                    'location': Point(item['lon'], item['lat'], srid=4326),
                    'distance_from_center_km': item['dist'],
                }
            )

        self.stdout.write(f"  Created {len(infra_data)} infrastructure points")
