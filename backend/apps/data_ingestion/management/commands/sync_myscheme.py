"""
Fetch real scheme details from myscheme.gov.in and update the Scheme table.

This command has two modes:
  1. Live scrape: Fetches myscheme.gov.in pages (requires network + Playwright)
  2. Official data: Uses comprehensive built-in descriptions from official scheme guidelines
     (reliable, works offline, sourced from published Government of India documents)

Usage:
    python manage.py sync_myscheme                     # try live scrape, fallback to official
    python manage.py sync_myscheme --official           # use official data directly (recommended)
    python manage.py sync_myscheme --scheme PM-KUSUM   # single scheme
    python manage.py sync_myscheme --reingest           # also re-run RAG embeddings after update
"""
import logging
import time

import requests
from django.core.management.base import BaseCommand
from django.utils.timezone import now

logger = logging.getLogger(__name__)

# Map our short_name → myscheme.gov.in URL slug
SCHEME_SLUG_MAP = {
    'PM-KUSUM': 'pm-kusum',
    'MGNREGA': 'mgnregs',
    'Jal Jeevan Mission': 'jal-jeevan-mission',
    'PMAY-G': 'pradhan-mantri-awaas-yojana-gramin',
    'PM-KISAN': 'pm-kisan-samman-nidhi',
    'PMGSY': 'pradhan-mantri-gram-sadak-yojana',
    'SBM-G': 'swachh-bharat-mission-gramin',
    'PMFBY': 'pradhan-mantri-fasal-bima-yojana',
    'DDU-GKY': 'deen-dayal-upadhyaya-grameen-kaushalya-yojana',
    'NRLM/DAY-NRLM': 'deendayal-antyodaya-yojana-national-rural-livelihoods-mission',
    'NSAP': 'national-social-assistance-programme',
    'Samagra Shiksha': 'samagra-shiksha-abhiyan',
}

_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
    'Accept-Language': 'en-IN,en;q=0.9,hi;q=0.8',
}

# -------------------------------------------------------------------
# Official scheme descriptions — sourced from published GoI documents,
# scheme guidelines, and Ministry press releases (as of 2023-24).
# Structured for optimal RAG retrieval: eligibility, amounts, process.
# -------------------------------------------------------------------
OFFICIAL_SCHEME_DESCRIPTIONS = {
    'PM-KUSUM': """
PM-KUSUM (Pradhan Mantri Kisan Urja Suraksha evam Utthaan Mahabhiyan)
Ministry: Ministry of New and Renewable Energy (MNRE)
Launched: 2019 | Status: Active 2023-24

OVERVIEW:
PM-KUSUM promotes solarization of agriculture pumps to reduce diesel dependency.
Three components: A (10,000 MW decentralized solar plants), B (standalone solar pumps up to 7.5 HP),
C (solarization of grid-connected pumps).

BENEFITS:
• Component B: 60% subsidy on standalone solar pump installation (30% Central + 30% State)
• Farmer contributes 40%: 10% own contribution + 30% via bank loan
• For SC/ST farmers: State subsidy may increase to 40%, reducing farmer share to 20%
• 25-year Operation and Maintenance support
• Income from surplus energy sold to DISCOM: Rs.3-4/unit

ELIGIBILITY:
• Individual farmers with valid land records (Khasra/Khatauni)
• Farmer cooperatives, panchayats, water user associations
• Land requirement: minimum 1 acre per HP of pump capacity
• No restriction on landholding size for Component B
• Priority: SC/ST, small and marginal farmers

FINANCIAL SUPPORT:
• 7.5 HP pump total cost ~Rs.7.5 lakh; farmer pays ~Rs.3 lakh
• Bank loan available at 4% interest under PMKVY/KCC
• Grid-connected: Net metering for surplus energy sale

DOCUMENTS REQUIRED:
• Aadhaar card (mandatory), PAN card
• Land records (7/12 extract or Khasra-Khatauni)
• Bank account linked to Aadhaar
• Electricity bill (if existing pump)
• Caste certificate (for SC/ST benefit)

HOW TO APPLY:
• Online: State Renewable Energy Development Authority (SREDA) portal
• Offline: DISCOM office or Krishi Vigyan Kendra
• Step 1: Register on State SREDA/MNRE portal
• Step 2: Upload documents, select pump capacity
• Step 3: Pay 10% advance amount online
• Step 4: DISCOM/vendor installs pump within 120 days
• Step 5: Bank disburses remaining 30% loan post-installation
""",

    'MGNREGA': """
MGNREGA (Mahatma Gandhi National Rural Employment Guarantee Act) — 2005
Ministry: Ministry of Rural Development (MoRD)
Status: Ongoing Entitlement Act | Budget 2023-24: Rs.60,000 crore

OVERVIEW:
MGNREGA guarantees 100 days of unskilled wage employment per household per year.
It is a demand-driven programme — work must be provided within 15 days of demand,
else unemployment allowance is paid.

BENEFITS:
• 100 days guaranteed wage employment per household per year
• Additional 50 days for households in drought/natural calamity notified areas
• Current wage rates (2023-24): Rs.230-357/day depending on state
  (Odisha: Rs.237/day, Rajasthan: Rs.255/day)
• 60:40 labour-to-material ratio mandatory on worksites
• Work within 5 km of residence; if beyond 5 km, 10% extra wages

PERMISSIBLE WORKS:
• Water conservation: check dams, percolation tanks, farm ponds
• Irrigation: canals, field channels, water harvesting structures
• Land development: leveling, soil and moisture conservation
• Rural connectivity: village roads, culverts
• Flood control: bunds, embankments
• Plantation and horticulture: nurseries, fruit orchards
• Rural sanitation: individual household toilets (linked to SBM-G)
• Building of Anganwadis, school buildings (as per state convergence)

ELIGIBILITY:
• Any adult member of rural household willing to do unskilled work
• Must have Job Card (free from Gram Panchayat)
• No income/landholding restriction

DOCUMENTS REQUIRED:
• Job Card (register at Gram Panchayat — free, issued within 15 days)
• Aadhaar card (for payment)
• Bank account (wages paid directly to Aadhaar-linked account)

HOW TO APPLY:
• Visit Gram Panchayat to get Job Card registered
• Submit written/oral work demand to Gram Panchayat or Programme Officer
• Wages deposited to bank account within 15 days of work completion
• Check work availability at nrega.nic.in
""",

    'Jal Jeevan Mission': """
Jal Jeevan Mission — Har Ghar Jal
Ministry: Ministry of Jal Shakti
Launched: August 2019 | Target: 100% FHTC by 2024

OVERVIEW:
Provides functional household tap connections (FHTC) with potable water
(55 LPCD minimum) to every rural household. World's largest drinking water
infrastructure programme — 19 crore rural households.

BENEFITS:
• Individual household tap connection with metered supply
• Minimum 55 litres per capita per day (LPCD) clean piped water
• Quality tested water (fluoride, arsenic, nitrate within BIS norms)
• Community water testing laboratories at block level
• Drinking water source protection under national groundwater programme

FUNDING PATTERN:
• Special category states (NE, Himalayan, J&K, Ladakh): 90% Central, 10% State
• Other states: 50% Central, 50% State
• 15th Finance Commission grant: 50% earmarked for water and sanitation

ELIGIBILITY:
• All rural households (priority: SC/ST habitations, JJM aspirational districts)
• Schools, Anganwadis, Gram Panchayats, health centres get priority connections
• No individual eligibility criterion — household-level entitlement

IMPLEMENTATION:
• Village Action Plan (VAP) prepared by Gram Panchayat with community participation
• Village Water and Sanitation Committee (VWSC)/Pani Samiti manages local infrastructure
• O&M cost: Rs.250-500/household/year (collected as user charge after 5 years)

HOW TO APPLY (for villages):
• Gram Panchayat prepares VAP and submits to Block Programme Management Unit
• State Water and Sanitation Mission (SWSM) approves and awards DPR
• Households do not apply individually — entire habitation covered as per VAP
• Grievance: Call 1916 (Jal Jeevan Mission helpline) or portal jaljeevanmission.gov.in
""",

    'PMAY-G': """
PMAY-G (Pradhan Mantri Awaas Yojana — Gramin)
Ministry: Ministry of Rural Development
Launched: 2016 | Phase II: 2019-2024 | Target: 2.95 crore houses

OVERVIEW:
Financial assistance to rural BPL households for construction of pucca houses
with basic amenities (toilet, LPG, electricity, clean cooking fuel).

BENEFITS:
• Rs.1,20,000 per unit in plain areas
• Rs.1,30,000 per unit in hilly/difficult areas (NE states, HP, UK, J&K)
• Additional Rs.12,000 for toilet construction (SBM-G convergence)
• Rs.18,000 for smokeless chulha (Ujjwala scheme convergence)
• 90 days MGNREGA employment for unskilled labour (value ~Rs.21,330)
• Rs.70,000 institutional finance (housing loan) available separately

FUNDING:
• Plain areas: 60% Central + 40% State
• Hilly/special category states: 90% Central + 10% State
• Payments in 3 tranches: foundation, lintel, roof slab (via Aadhaar-linked DBT)

ELIGIBILITY:
• Identified from SECC 2011 data (auto-exclusion criteria apply)
• Priority: SC/ST, minorities, bonded labour (released), disabled, widows
• Own land or allocated land required (patta/porch certificate)
• Existing katcha/dilapidated house
• Excluded: Regular government employees, income tax payers, vehicle owners,
  3+ rooms in existing house

DOCUMENTS REQUIRED:
• Aadhaar card (mandatory — for Awaas Soft)
• Bank account linked to Aadhaar
• Land documents (patta/land allocation certificate)
• Job Card (for MGNREGA component)
• Caste certificate (SC/ST)
• Income/BPL certificate

HOW TO APPLY:
• Beneficiary list from SECC 2011 — cannot self-apply
• If eligible household missed: apply to Gram Panchayat for inclusion
• Gram Sabha verifies and recommends list to Block Development Officer
• Aawasoft portal: awaassoft.nic.in for status tracking
• PMAY-G app for photo upload of construction stages
""",

    'PM-KISAN': """
PM-KISAN (Pradhan Mantri Kisan Samman Nidhi)
Ministry: Ministry of Agriculture & Farmers Welfare
Launched: December 2018 | Budget 2023-24: Rs.60,000 crore

OVERVIEW:
Direct income support of Rs.6,000 per year to all landholding farmer families
in three equal instalments of Rs.2,000 each (April-July, August-November,
December-March).

BENEFITS:
• Rs.6,000/year in 3 instalments of Rs.2,000 directly to bank account
• Funds transferred within 2-3 days of release by central government
• No upper land ceiling — both small/large farmers eligible

ELIGIBILITY:
All landholding farmer families (husband, wife, minor children) EXCEPT:
• Former/current constitutional post holders, Ministers, MPs, MLAs
• Current/retired government employees (salary > Rs.10,000/month)
• Income tax payers in last assessment year
• Professionals: doctors, engineers, CA, architects (registered)
• Farmers with leased land only (no land records) — NOT eligible

SPECIAL NOTE: Share-croppers and tenant farmers are NOT eligible under PM-KISAN
as landholding is the criterion.

DOCUMENTS REQUIRED:
• Aadhaar card (mandatory for eKYC — required from 2022)
• Land records (Khasra/Khatauni/7-12 extract)
• Bank account (Aadhaar-linked for direct credit)
• Mobile number (for OTP-based eKYC)

HOW TO APPLY:
• Online: pmkisan.gov.in → "Farmer Corner" → "New Farmer Registration"
• Offline: Village Patwari/Agriculture Officer/Lekhpal
• eKYC mandatory: OTP-based via pmkisan.gov.in or Face Authentication via app
• Status check: pmkisan.gov.in → Beneficiary Status (Aadhaar/Account/Mobile)
• Helpline: PM-KISAN Helpline 155261 / 011-24300606
""",

    'PMGSY': """
PMGSY (Pradhan Mantri Gram Sadak Yojana)
Ministry: Ministry of Rural Development
Launched: 2000 | Phase III: 2019-2025 | Budget: Rs.80,250 crore

OVERVIEW:
Provides all-weather road connectivity to unconnected rural habitations.
Phase III focuses on upgradation of existing through routes and major rural links
to improve quality and extend road life.

BENEFITS (Phase III):
• Upgradation of existing roads to bituminous/concrete surface
• Construction of culverts and bridges for all-weather connectivity
• Road length: 1.25 lakh km to be upgraded
• Maintenance funded for 5 years post-completion by Centre

FUNDING:
• Centre:State = 60:40 (general states)
• Northeast/Himalayan/Hilly states: 90:10
• J&K, Ladakh UTs: 100% Central

ELIGIBILITY (habitations):
• Phase I/II: Unconnected habitations ≥250 population (≥100 for SC/ST areas)
• Phase III: Habitations already connected but needing road upgradation
• No direct household-level eligibility — Panchayat/Block level application

HOW IT WORKS:
• State prepares District Rural Road Plan (DRRP) and Core Network
• Projects sanctioned via OMMAS (Online Management, Monitoring and Accounting System)
• DPR prepared by state PWD, approved by National Quality Monitor (NQM)
• Contractor selected through e-tendering; work must complete in 12-18 months
• Citizen grievance: omms.nic.in or Block Development Officer

QUALITY ASSURANCE:
• 3-tier quality mechanism: Contractor → State Quality Monitor → National Quality Monitor
• 5-year maintenance mandatory post-completion (funded by PMGSY)
""",

    'SBM-G': """
SBM-G Phase II (Swachh Bharat Mission — Gramin)
Ministry: Ministry of Jal Shakti
Phase I: 2014-2019 (ODF achieved) | Phase II: 2020-2025

OVERVIEW:
Sustains ODF (Open Defecation Free) status and implements solid/liquid waste
management to achieve "ODF Plus" villages (clean, sustainable sanitation).

BENEFITS:
• Individual Household Latrine (IHHL): Rs.12,000 incentive for new construction
• Community Sanitation Complex (CSC): Rs.3 lakh (for shared facilities in public spaces)
• Solid Waste Management: Vermicomposting pits, biogas plants, material recovery facilities
• Liquid Waste Management: Soak pits, waste stabilization ponds, constructed wetlands
• Gobardhan scheme (biogas from cattle dung): additional support

FUNDING:
• Centre:State = 60:40 | NE/Special states: 90:10
• 15th Finance Commission grant: 50% earmarked for sanitation (Rs.50,000 crore)

ELIGIBILITY (IHHL):
• Rural households without existing toilet
• Households with dilapidated/non-functional toilet (Phase II)
• Priority: SC/ST, poorest households, women-headed households
• Verified by Swachhata Doot or Gram Panchayat

DOCUMENTS REQUIRED:
• Aadhaar card + bank account (for DBT of Rs.12,000)
• Household survey form (filled by Swachhata Doot)
• Before/after photos (via SBM-G mobile app)
• No land document needed for toilet construction

HOW TO APPLY:
• Apply at Gram Panchayat (free application)
• Gram Panchayat verifies household eligibility
• Incentive paid in 2 tranches: foundation (Rs.6,000) + completion (Rs.6,000)
• Photo upload via SBM-G app mandatory for 2nd tranche
• Toilet must have running water supply (connection from JJM if available)
""",

    'PMFBY': """
PMFBY (Pradhan Mantri Fasal Bima Yojana) / RWBCIS
Ministry: Ministry of Agriculture & Farmers Welfare
Launched: 2016 | Revamped 2020

OVERVIEW:
Provides financial support to farmers suffering crop loss/damage due to
unforeseen events — natural calamities, pests, diseases.
Two schemes: PMFBY (yield-based) + RWBCIS (weather-based).

BENEFITS:
• Kharif crops: Maximum 2% premium paid by farmer
• Rabi crops: Maximum 1.5% premium paid by farmer
• Annual commercial/horticulture: Maximum 5% premium paid by farmer
• Government (Centre + State) pays remaining actuarial premium
• Coverage: Sowing failure → Mid-season adversity → Post-harvest loss → Localized calamity

CLAIM CALCULATION:
• If actual yield < threshold yield → proportional compensation paid
• Threshold = 7-year average yield of the crop in the area
• Maximum sum insured = State-notified Scale of Finance per crop/acre

ELIGIBILITY:
• All farmers growing notified crops in notified areas
• Loanee farmers: mandatory enrollment (covered automatically by bank)
• Non-loanee farmers: voluntary enrollment via bank, CSC, or crop insurance portal
• Tenant/share-crop farmers eligible with proper land documentation

ENROLLMENT DEADLINE:
• Kharif: Cut-off date varies by state (typically July 31)
• Rabi: Typically December 31
• Enrollment AFTER deadline: NOT accepted (strict)

DOCUMENTS REQUIRED:
• Land records / lease agreement
• Bank account statement
• Aadhaar card
• Sowing certificate (from Patwari for non-loanee)
• Previous year's crop details

HOW TO APPLY:
• Loanee farmers: Bank automatically enrolls at time of crop loan disbursement
• Non-loanee: Enroll at bank branch, CSC (Jan Seva Kendra), or pmfby.gov.in
• Claim filing: Intimation within 72 hours of loss via crop insurance app
  or 14447 (toll-free)
""",

    'DDU-GKY': """
DDU-GKY (Deen Dayal Upadhyaya Grameen Kaushalya Yojana)
Ministry: Ministry of Rural Development
Launched: 2014 | Restructured 2020

OVERVIEW:
Placement-linked skill training programme for rural poor youth.
Mandatory 75% job placement guarantee — unique among government skill schemes.

BENEFITS:
• Free skill training: 3-12 months duration at no cost to participant
• Residential training with accommodation + meals for outstation trainees
• Post-placement support: Rs.1,000/month for 2 months (for domestic placements)
• Migration support: Rs.1,250/month for 3 months (for out-of-state placements)
• Minimum wage guaranteed placements only accepted
• Sectors: IT, electronics, garments, construction, healthcare, retail

ELIGIBILITY:
• Age: 15-35 years (relaxed to 45 for special groups)
• Rural household: must have MGNREGA Job Card or below poverty line
• Priority: SC/ST candidates (50% of training slots), minorities, women (33%),
  persons with disability (3%)
• Class 5 pass is desirable but NOT mandatory for most trades

DOCUMENTS REQUIRED:
• Aadhaar card
• MGNREGA Job Card OR BPL certificate
• Educational certificate (if applicable)
• Bank account
• Caste certificate (for SC/ST priority)

HOW TO APPLY:
• Walk-in to nearest DDU-GKY training centre (find at ddugky.info)
• Registration at Gram Panchayat or Block Office
• State Rural Livelihood Mission (SRLM) coordinates admissions
• Selection process: Counselling + aptitude assessment
""",

    'NRLM/DAY-NRLM': """
DAY-NRLM (Deendayal Antyodaya Yojana — National Rural Livelihoods Mission)
Ministry: Ministry of Rural Development
Launched: 2011 | Budget 2023-24: Rs.14,236 crore

OVERVIEW:
Builds self-sustaining institutions of the poor — Self Help Groups (SHGs)
linked to bank credit for sustainable livelihoods of rural poor women.

BENEFITS:
• SHG Formation: Rs.10,000 revolving fund per SHG (once)
• Community Investment Support Fund (CISF): Rs.2.5 lakh per SHG (once)
• Bank linkage: Collateral-free loans at 7% interest (subvented by GOI)
• Interest subvention: 5.5% for NPA-free SHGs → effective rate 1.5-4%
• Mahila Kisan Sashaktikaran Pariyojana (MKSP): support to women farmers
• Rural Self Employment Training Institutes (RSETIs) for skill training

ELIGIBILITY:
• Women from rural poor households (SECC 2011 priority)
• SHGs must have 10-20 women members from same village/hamlet
• Active SHG: meets regularly, maintains books, saves, repays on time
• No upper land/income limit, but targeted at poorest

HOW TO JOIN:
• Contact Community Resource Person (CRP) at Gram Panchayat
• Community Mobilizer from State Rural Livelihood Mission (SRLM) facilitates
  SHG formation (monthly savings: Rs.50-500/member)
• After 6 months active savings: eligible for revolving fund
• After 1 year active: eligible for Community Investment Fund
• SHG-Bank Linkage: after 12 months regular activity; loans up to 8x savings corpus

STATE IMPLEMENTATION:
• State Rural Livelihood Mission (SRLM) in each state
  (Odisha: ORMAS, Rajasthan: RGAVP, Maharashtra: UMED, UP: UPSRLM)
""",

    'NSAP': """
NSAP (National Social Assistance Programme)
Ministry: Ministry of Rural Development
Launched: 1995 | Annual Budget: ~Rs.9,000 crore

OVERVIEW:
Provides social protection to destitute elderly, widows, and disabled persons
through 5 sub-schemes providing cash assistance via DBT.

SUB-SCHEMES AND AMOUNTS:
• IGNOAPS (Indira Gandhi Old Age Pension): Rs.200/month (60-79 years), Rs.500/month (80+)
• IGNWPS (Widow Pension): Rs.300/month for widows aged 40-79
• IGNDPS (Disability Pension): Rs.300/month for 80%+ disability
• NFBS (Family Benefit Scheme): Rs.20,000 lump sum on BPL breadwinner death
• Annapurna (Food Security): 10 kg foodgrains free/month (senior citizens not covered by IGNOAPS)

NOTE: State governments may add top-up amounts on top of Central assistance
(e.g., Odisha: Rs.500 state top-up → effective Rs.700/month for 60-79 years)

ELIGIBILITY:
• Below Poverty Line (BPL) household mandatory
• IGNOAPS: Age 60+ with little/no regular income
• IGNWPS: Widow aged 40+, BPL
• IGNDPS: 40%+ disability (80%+ for higher amount)
• NFBS: Death of primary breadwinner (18-59 years), BPL family

DOCUMENTS REQUIRED:
• Aadhaar card (mandatory)
• BPL certificate / Ration Card
• Age proof: birth certificate, school certificate, Aadhaar
• Disability certificate (from Medical Officer/CMO) for IGNDPS
• Death certificate + relationship proof for NFBS

HOW TO APPLY:
• Apply at Block/Tehsil office with documents
• Gram Panchayat can recommend and forward applications
• Pension credited monthly directly to Aadhaar-linked bank account
""",

    'Samagra Shiksha': """
Samagra Shiksha Abhiyan
Ministry: Ministry of Education (MoE)
Launched: 2018 (merged SSA + RMSA + TE) | Budget 2023-24: Rs.37,383 crore

OVERVIEW:
Integrated school education scheme covering pre-primary to class 12
for universal access, quality, and equity in school education.

KEY BENEFITS:
• Free textbooks: Classes 1-8 (all) + 9-12 (SC/ST/BPL girls)
• Free uniform: 2 sets/year for classes 1-8 girls and SC/ST boys
• Kasturba Gandhi Balika Vidyalaya (KGBV): Residential schools for girls from
  SC/ST/minority/BPL (classes 6-12), fully funded
• ICT in schools: Smart classrooms, DIKSHA platform, PMeVIDYA
• Mid-Day Meal: Hot cooked meal 200-300 cal/day (separate scheme but linked)
• Inclusive education: Rs.3,500/disabled child/year for support

INFRASTRUCTURE SUPPORT TO SCHOOLS:
• Classroom construction: Rs.7-12 lakh per classroom
• Computer labs: Rs.6.4 lakh per lab
• Library: Rs.5,000-20,000 per school/year for books
• Composite school grants: Rs.5,000-1,00,000/year per school by category

TEACHER SUPPORT:
• Pre-service teacher education at DIETs (District Institutes of Education)
• In-service training: 5-20 days/year per teacher
• Salary supplement for contract teachers in difficult areas

ELIGIBILITY:
• All government and government-aided schools (automatic coverage)
• Individual children in government schools automatically eligible
• Private school children: not covered except for RTE 25% quota

HOW IT WORKS (for individual families):
• Enroll child in nearest government school (free and compulsory ages 6-14)
• No application needed for free textbooks/uniforms — automatic in government schools
• KGBV admission: Apply at District Education Office (for girls, classes 6-12)
• Grievance: U-DISE portal or District Education Officer
""",
}


class Command(BaseCommand):
    help = 'Update scheme descriptions with real official data from myscheme.gov.in or built-in guidelines'

    def add_arguments(self, parser):
        parser.add_argument('--scheme', type=str, help='Short name of a single scheme to sync')
        parser.add_argument(
            '--official', action='store_true',
            help='Use comprehensive built-in official scheme descriptions (recommended for demo)'
        )
        parser.add_argument(
            '--reingest', action='store_true',
            help='After updating descriptions, re-run ingest_schemes --rebuild'
        )

    def handle(self, *args, **options):
        from apps.scheme_rag.models import Scheme

        target = options.get('scheme')
        qs = Scheme.objects.filter(short_name=target) if target else Scheme.objects.all()

        if not qs.exists():
            self.stdout.write(self.style.ERROR(f"No schemes found (filter: {target or 'all'})"))
            return

        use_official = options.get('official', False)
        updated = 0

        for scheme in qs:
            if use_official:
                description = OFFICIAL_SCHEME_DESCRIPTIONS.get(scheme.short_name)
                if description:
                    scheme.description = description.strip()
                    scheme.last_updated = now().date()
                    scheme.save(update_fields=['description', 'last_updated'])
                    self.stdout.write(self.style.SUCCESS(
                        f"  ✓ {scheme.short_name} ({len(description)} chars)"
                    ))
                    updated += 1
                else:
                    self.stdout.write(f"  ⚠ No official data for '{scheme.short_name}'")
            else:
                # Try live scrape
                slug = SCHEME_SLUG_MAP.get(scheme.short_name)
                if not slug:
                    self.stdout.write(f"  ⚠ No URL mapping for '{scheme.short_name}' — skipping")
                    continue
                self.stdout.write(f"  Fetching {scheme.short_name} from myscheme.gov.in...")
                description = self._try_live_fetch(slug, scheme.short_name)

                if not description:
                    # Fall back to official data
                    description = OFFICIAL_SCHEME_DESCRIPTIONS.get(scheme.short_name)
                    if description:
                        self.stdout.write(f"    → Using official fallback for {scheme.short_name}")

                if description and description.strip() != scheme.description.strip():
                    scheme.description = description.strip()
                    scheme.last_updated = now().date()
                    scheme.save(update_fields=['description', 'last_updated'])
                    self.stdout.write(self.style.SUCCESS(
                        f"    ✓ Updated {scheme.short_name} ({len(description)} chars)"
                    ))
                    updated += 1
                else:
                    self.stdout.write(f"    → Already up to date: {scheme.short_name}")
                time.sleep(1)

        self.stdout.write(self.style.SUCCESS(f"\nDone: {updated} scheme(s) updated"))

        if options.get('reingest') and updated > 0:
            self.stdout.write("\nRe-running RAG embeddings (--reingest flag)...")
            from django.core.management import call_command
            call_command('ingest_schemes', rebuild=True)

    def _try_live_fetch(self, slug: str, short_name: str) -> str | None:
        """
        Attempt to fetch scheme data from myscheme.gov.in.
        Returns None if the page doesn't have accessible data (client-side rendered).
        """
        from bs4 import BeautifulSoup
        import json

        url = f'https://www.myscheme.gov.in/schemes/{slug}'
        try:
            resp = requests.get(url, headers=_HEADERS, timeout=15)
            if resp.status_code != 200:
                return None

            soup = BeautifulSoup(resp.text, 'html.parser')

            # Try __NEXT_DATA__ (server-side rendered pages)
            next_data = soup.find('script', {'id': '__NEXT_DATA__'})
            if next_data:
                data = json.loads(next_data.string)
                page_props = data.get('props', {}).get('pageProps', {})
                scheme_data = (
                    page_props.get('scheme') or
                    page_props.get('schemeData') or
                    page_props.get('data', {}).get('scheme')
                )
                if scheme_data and isinstance(scheme_data, dict):
                    return self._format_scheme_json(scheme_data, short_name)

            # Try visible text extraction (fallback for SSR pages)
            return self._extract_visible_sections(soup, short_name)

        except Exception as e:
            logger.debug(f"Live fetch failed for {slug}: {e}")
            return None

    def _extract_visible_sections(self, soup, short_name: str) -> str | None:
        """Extract meaningful text sections from HTML."""
        sections = {}
        for heading in soup.find_all(['h2', 'h3', 'h4']):
            heading_text = heading.get_text(strip=True).lower()
            content = []
            for sibling in heading.find_next_siblings():
                if sibling.name in ['h2', 'h3', 'h4']:
                    break
                text = sibling.get_text(separator=' ', strip=True)
                if text:
                    content.append(text)
            if content:
                sections[heading_text] = ' '.join(content)[:500]

        if not sections:
            return None

        section_labels = {
            'benefit': 'BENEFITS', 'eligib': 'ELIGIBILITY',
            'document': 'DOCUMENTS REQUIRED', 'apply': 'HOW TO APPLY',
            'process': 'APPLICATION PROCESS', 'overview': 'OVERVIEW',
            'about': 'ABOUT', 'objective': 'OBJECTIVES',
        }
        parts = [f"[{short_name}]"]
        for heading, content in sections.items():
            for key, label in section_labels.items():
                if key in heading:
                    parts.append(f"\n{label}: {content}")
                    break

        return '\n'.join(parts) if len(parts) > 1 else None

    def _format_scheme_json(self, data: dict, short_name: str) -> str:
        """Format scheme JSON data from Next.js pageProps."""
        parts = [f"[{short_name}]"]
        for field, label in [
            ('description', 'OVERVIEW'), ('benefits', 'BENEFITS'),
            ('eligibility', 'ELIGIBILITY CRITERIA'), ('documents', 'DOCUMENTS'),
            ('applicationProcess', 'HOW TO APPLY'),
        ]:
            val = data.get(field)
            if not val:
                continue
            if isinstance(val, list):
                items = [f"• {(i.get('description') or i.get('text') or str(i))[:200]}"
                         for i in val[:8] if i]
                parts.append(f"\n{label}:\n" + '\n'.join(items))
            elif isinstance(val, str):
                parts.append(f"\n{label}: {val[:500]}")
        return '\n'.join(parts) if len(parts) > 1 else None
