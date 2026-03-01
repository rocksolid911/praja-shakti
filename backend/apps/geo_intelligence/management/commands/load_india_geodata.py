"""
Load all Indian states, union territories, and districts into the database.
Uses official state LGD codes; district LGD codes are generated as
GEN{state_code}{seq:04d} when not already present.

Usage:
    python manage.py load_india_geodata
    python manage.py load_india_geodata --state 21   # reload only Odisha
"""
from django.core.management.base import BaseCommand
from apps.geo_intelligence.models import State, District, Block, Panchayat


# ── India Administrative Data ────────────────────────────────────────────
# Official Census LGD state/UT codes (2023). Each dict has:
#   state_lgd : official 2-digit code
#   state_name: official name
#   districts : list of district names (post-2023 reorganisations included)

INDIA_GEO = [
    {
        'state_lgd': '28', 'state_name': 'Andhra Pradesh',
        'districts': [
            'Alluri Sitharama Raju', 'Anakapalli', 'Anantapur', 'Annamayya',
            'Bapatla', 'Chittoor', 'East Godavari', 'Eluru', 'Guntur',
            'Kakinada', 'Konaseema', 'Krishna', 'Kurnool', 'Manyam',
            'NTR', 'Nandyal', 'Palnadu', 'Prakasam', 'Sri Balaji',
            'Sri Sathya Sai', 'Srikakulam', 'Tirupati', 'Visakhapatnam',
            'Vizianagaram', 'West Godavari', 'YSR (Kadapa)',
        ],
    },
    {
        'state_lgd': '12', 'state_name': 'Arunachal Pradesh',
        'districts': [
            'Anjaw', 'Changlang', 'Dibang Valley', 'East Kameng', 'East Siang',
            'Kamle', 'Kra Daadi', 'Kurung Kumey', 'Lepa Rada', 'Lohit',
            'Longding', 'Lower Dibang Valley', 'Lower Siang', 'Lower Subansiri',
            'Namsai', 'Pakke Kessang', 'Papum Pare', 'Shi Yomi', 'Siang',
            'Tawang', 'Tirap', 'Upper Dibang Valley', 'Upper Siang',
            'Upper Subansiri', 'West Kameng', 'West Siang',
        ],
    },
    {
        'state_lgd': '18', 'state_name': 'Assam',
        'districts': [
            'Bajali', 'Baksa', 'Barpeta', 'Biswanath', 'Bongaigaon', 'Cachar',
            'Charaideo', 'Chirang', 'Darrang', 'Dhemaji', 'Dhubri', 'Dibrugarh',
            'Dima Hasao', 'Goalpara', 'Golaghat', 'Hailakandi', 'Hojai',
            'Jorhat', 'Kamrup', 'Kamrup Metropolitan', 'Karbi Anglong',
            'Karimganj', 'Kokrajhar', 'Lakhimpur', 'Majuli', 'Morigaon',
            'Nagaon', 'Nalbari', 'Sivasagar', 'Sonitpur',
            'South Salmara-Mankachar', 'Tamulpur', 'Tinsukia', 'Udalguri',
            'West Karbi Anglong',
        ],
    },
    {
        'state_lgd': '10', 'state_name': 'Bihar',
        'districts': [
            'Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai', 'Bhagalpur',
            'Bhojpur', 'Buxar', 'Darbhanga', 'East Champaran', 'Gaya',
            'Gopalganj', 'Jamui', 'Jehanabad', 'Kaimur', 'Katihar', 'Khagaria',
            'Kishanganj', 'Lakhisarai', 'Madhepura', 'Madhubani', 'Munger',
            'Muzaffarpur', 'Nalanda', 'Nawada', 'Patna', 'Purnia', 'Rohtas',
            'Saharsa', 'Samastipur', 'Saran', 'Sheikhpura', 'Sheohar',
            'Sitamarhi', 'Siwan', 'Supaul', 'Vaishali', 'West Champaran',
        ],
    },
    {
        'state_lgd': '22', 'state_name': 'Chhattisgarh',
        'districts': [
            'Balod', 'Baloda Bazar', 'Balrampur', 'Bastar', 'Bemetara',
            'Bijapur', 'Bilaspur', 'Dantewada', 'Dhamtari', 'Durg',
            'Gariaband', 'Gaurela-Pendra-Marwahi', 'Janjgir-Champa', 'Jashpur',
            'Kabirdham', 'Kanker', 'Kondagaon', 'Korba', 'Koriya',
            'Mahasamund', 'Manendragarh', 'Mohla-Manpur', 'Mungeli',
            'Narayanpur', 'Raigarh', 'Raipur', 'Rajnandgaon', 'Sakti',
            'Sarangarh-Bilaigarh', 'Sukma', 'Surajpur', 'Surguja',
            'Khairagarh-Chhuikhadan-Gandai',
        ],
    },
    {
        'state_lgd': '30', 'state_name': 'Goa',
        'districts': ['North Goa', 'South Goa'],
    },
    {
        'state_lgd': '24', 'state_name': 'Gujarat',
        'districts': [
            'Ahmedabad', 'Amreli', 'Anand', 'Aravalli', 'Banaskantha',
            'Bharuch', 'Bhavnagar', 'Botad', 'Chhota Udaipur', 'Dahod',
            'Dang', 'Devbhoomi Dwarka', 'Gandhinagar', 'Gir Somnath',
            'Jamnagar', 'Junagadh', 'Kheda', 'Kutch', 'Mahisagar', 'Mehsana',
            'Morbi', 'Narmada', 'Navsari', 'Panchmahal', 'Patan', 'Porbandar',
            'Rajkot', 'Sabarkantha', 'Surat', 'Surendranagar', 'Tapi',
            'Vadodara', 'Valsad',
        ],
    },
    {
        'state_lgd': '06', 'state_name': 'Haryana',
        'districts': [
            'Ambala', 'Bhiwani', 'Charkhi Dadri', 'Faridabad', 'Fatehabad',
            'Gurugram', 'Hisar', 'Jhajjar', 'Jind', 'Kaithal', 'Karnal',
            'Kurukshetra', 'Mahendragarh', 'Nuh', 'Palwal', 'Panchkula',
            'Panipat', 'Rewari', 'Rohtak', 'Sirsa', 'Sonipat', 'Yamunanagar',
        ],
    },
    {
        'state_lgd': '02', 'state_name': 'Himachal Pradesh',
        'districts': [
            'Bilaspur', 'Chamba', 'Hamirpur', 'Kangra', 'Kinnaur', 'Kullu',
            'Lahaul And Spiti', 'Mandi', 'Shimla', 'Sirmaur', 'Solan', 'Una',
        ],
    },
    {
        'state_lgd': '20', 'state_name': 'Jharkhand',
        'districts': [
            'Bokaro', 'Chatra', 'Deoghar', 'Dhanbad', 'Dumka',
            'East Singhbhum', 'Garhwa', 'Giridih', 'Godda', 'Gumla',
            'Hazaribagh', 'Jamtara', 'Khunti', 'Koderma', 'Latehar',
            'Lohardaga', 'Pakur', 'Palamu', 'Ramgarh', 'Ranchi', 'Sahebganj',
            'Seraikela Kharsawan', 'Simdega', 'West Singhbhum',
        ],
    },
    {
        'state_lgd': '29', 'state_name': 'Karnataka',
        'districts': [
            'Bagalkot', 'Ballari', 'Belagavi', 'Bengaluru Rural',
            'Bengaluru Urban', 'Bidar', 'Chamarajanagar', 'Chikballapur',
            'Chikkamagaluru', 'Chitradurga', 'Dakshina Kannada', 'Davanagere',
            'Dharwad', 'Gadag', 'Hassan', 'Haveri', 'Kalaburagi', 'Kodagu',
            'Kolar', 'Koppal', 'Mandya', 'Mysuru', 'Raichur', 'Ramanagara',
            'Shivamogga', 'Tumakuru', 'Udupi', 'Uttara Kannada', 'Vijayapura',
            'Yadgir', 'Vijayanagara',
        ],
    },
    {
        'state_lgd': '32', 'state_name': 'Kerala',
        'districts': [
            'Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasaragod',
            'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad',
            'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad',
        ],
    },
    {
        'state_lgd': '23', 'state_name': 'Madhya Pradesh',
        'districts': [
            'Agar Malwa', 'Alirajpur', 'Anuppur', 'Ashoknagar', 'Balaghat',
            'Barwani', 'Betul', 'Bhind', 'Bhopal', 'Burhanpur', 'Chhatarpur',
            'Chhindwara', 'Damoh', 'Datia', 'Dewas', 'Dhar', 'Dindori',
            'Guna', 'Gwalior', 'Harda', 'Narmadapuram', 'Indore', 'Jabalpur',
            'Jhabua', 'Katni', 'Khandwa', 'Khargone', 'Maihar', 'Mandla',
            'Mandsaur', 'Mauganj', 'Morena', 'Narsinghpur', 'Neemuch',
            'Niwari', 'Pandhurna', 'Panna', 'Raisen', 'Rajgarh', 'Ratlam',
            'Rewa', 'Sagar', 'Satna', 'Sehore', 'Seoni', 'Shahdol',
            'Shajapur', 'Sheopur', 'Shivpuri', 'Sidhi', 'Singrauli',
            'Tikamgarh', 'Ujjain', 'Umaria', 'Vidisha',
        ],
    },
    {
        'state_lgd': '27', 'state_name': 'Maharashtra',
        'districts': [
            'Ahmadnagar', 'Akola', 'Amravati', 'Chhatrapati Sambhajinagar',
            'Beed', 'Bhandara', 'Buldhana', 'Chandrapur', 'Dhule',
            'Gadchiroli', 'Gondia', 'Hingoli', 'Jalgaon', 'Jalna',
            'Kolhapur', 'Latur', 'Mumbai City', 'Mumbai Suburban', 'Nagpur',
            'Nanded', 'Nandurbar', 'Nashik', 'Dharashiv', 'Palghar',
            'Parbhani', 'Pune', 'Raigad', 'Ratnagiri', 'Sangli', 'Satara',
            'Sindhudurg', 'Solapur', 'Thane', 'Wardha', 'Washim', 'Yavatmal',
        ],
    },
    {
        'state_lgd': '14', 'state_name': 'Manipur',
        'districts': [
            'Bishnupur', 'Chandel', 'Churachandpur', 'Imphal East',
            'Imphal West', 'Jiribam', 'Kakching', 'Kamjong', 'Kangpokpi',
            'Noney', 'Pherzawl', 'Senapati', 'Tamenglong', 'Tengnoupal',
            'Thoubal', 'Ukhrul',
        ],
    },
    {
        'state_lgd': '17', 'state_name': 'Meghalaya',
        'districts': [
            'East Garo Hills', 'East Jaintia Hills', 'East Khasi Hills',
            'Eastern West Khasi Hills', 'North Garo Hills', 'Ri Bhoi',
            'South Garo Hills', 'South West Garo Hills', 'South West Khasi Hills',
            'West Garo Hills', 'West Jaintia Hills', 'West Khasi Hills',
        ],
    },
    {
        'state_lgd': '15', 'state_name': 'Mizoram',
        'districts': [
            'Aizawl', 'Champhai', 'Hnahthial', 'Khawzawl', 'Kolasib',
            'Lawngtlai', 'Lunglei', 'Mamit', 'Saiha', 'Saitual', 'Serchhip',
        ],
    },
    {
        'state_lgd': '13', 'state_name': 'Nagaland',
        'districts': [
            'Chumoukedima', 'Dimapur', 'Kiphire', 'Kohima', 'Longleng',
            'Mokokchung', 'Mon', 'Niuland', 'Noklak', 'Peren', 'Phek',
            'Shamator', 'Tseminyu', 'Tuensang', 'Wokha', 'Zunheboto',
        ],
    },
    {
        'state_lgd': '21', 'state_name': 'Odisha',
        'districts': [
            'Angul', 'Balangir', 'Balasore', 'Bargarh', 'Bhadrak', 'Boudh',
            'Cuttack', 'Deogarh', 'Dhenkanal', 'Gajapati', 'Ganjam',
            'Jagatsinghpur', 'Jajpur', 'Jharsuguda', 'Kalahandi', 'Kandhamal',
            'Kendrapara', 'Keonjhar', 'Khordha', 'Koraput', 'Malkangiri',
            'Mayurbhanj', 'Nabarangpur', 'Nayagarh', 'Nuapada', 'Puri',
            'Rayagada', 'Sambalpur', 'Sonepur', 'Sundargarh',
        ],
    },
    {
        'state_lgd': '03', 'state_name': 'Punjab',
        'districts': [
            'Amritsar', 'Barnala', 'Bathinda', 'Faridkot', 'Fatehgarh Sahib',
            'Fazilka', 'Ferozepur', 'Gurdaspur', 'Hoshiarpur', 'Jalandhar',
            'Kapurthala', 'Ludhiana', 'Malerkotla', 'Mansa', 'Moga',
            'Mohali', 'Muktsar', 'Pathankot', 'Patiala', 'Rupnagar',
            'Sangrur', 'Shaheed Bhagat Singh Nagar', 'Tarn Taran',
        ],
    },
    {
        'state_lgd': '08', 'state_name': 'Rajasthan',
        'districts': [
            'Ajmer', 'Alwar', 'Anupgarh', 'Balotra', 'Banswara', 'Baran',
            'Barmer', 'Beawar', 'Bharatpur', 'Bhilwara', 'Bikaner', 'Bundi',
            'Chittorgarh', 'Churu', 'Dausa', 'Deeg', 'Dholpur',
            'Didwana-Kuchaman', 'Dungarpur', 'Ganganagar', 'Gangapur City',
            'Hanumangarh', 'Jaipur', 'Jaipur Rural', 'Jaisalmer', 'Jalore',
            'Jhalawar', 'Jhunjhunu', 'Jodhpur', 'Jodhpur Rural', 'Karauli',
            'Kekri', 'Khairthal-Tijara', 'Kotputli-Behror', 'Kota', 'Nagaur',
            'Neem Ka Thana', 'Pali', 'Phalodi', 'Pratapgarh', 'Rajsamand',
            'Salumbar', 'Sanchore', 'Sawai Madhopur', 'Shahpura', 'Sikar',
            'Sirohi', 'Tonk', 'Udaipur', 'Udaipur Rural',
        ],
    },
    {
        'state_lgd': '11', 'state_name': 'Sikkim',
        'districts': [
            'East Sikkim', 'North Sikkim', 'Pakyong', 'Soreng',
            'South Sikkim', 'West Sikkim',
        ],
    },
    {
        'state_lgd': '33', 'state_name': 'Tamil Nadu',
        'districts': [
            'Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore',
            'Dharmapuri', 'Dindigul', 'Erode', 'Kallakurichi', 'Kancheepuram',
            'Kanyakumari', 'Karur', 'Krishnagiri', 'Madurai', 'Mayiladuthurai',
            'Nagapattinam', 'Namakkal', 'Nilgiris', 'Perambalur', 'Pudukkottai',
            'Ramanathapuram', 'Ranipet', 'Salem', 'Sivaganga', 'Tenkasi',
            'Thanjavur', 'Theni', 'Thoothukudi', 'Tiruchirappalli',
            'Tirunelveli', 'Tirupathur', 'Tiruppur', 'Tiruvallur',
            'Tiruvannamalai', 'Tiruvarur', 'Vellore', 'Viluppuram',
            'Virudhunagar',
        ],
    },
    {
        'state_lgd': '36', 'state_name': 'Telangana',
        'districts': [
            'Adilabad', 'Bhadradri Kothagudem', 'Hanumakonda', 'Hyderabad',
            'Jagtial', 'Jangaon', 'Jayashankar Bhupalpally',
            'Jogulamba Gadwal', 'Kamareddy', 'Karimnagar', 'Khammam',
            'Kumuram Bheem Asifabad', 'Mahabubabad', 'Mahabubnagar',
            'Mancherial', 'Medak', 'Medchal-Malkajgiri', 'Mulugu',
            'Nagarkurnool', 'Nalgonda', 'Narayanpet', 'Nirmal', 'Nizamabad',
            'Peddapalli', 'Rajanna Sircilla', 'Rangareddy', 'Sangareddy',
            'Siddipet', 'Suryapet', 'Vikarabad', 'Wanaparthy',
            'Warangal Rural', 'Yadadri Bhuvanagiri',
        ],
    },
    {
        'state_lgd': '16', 'state_name': 'Tripura',
        'districts': [
            'Dhalai', 'Gomati', 'Khowai', 'North Tripura', 'Sepahijala',
            'South Tripura', 'Unakoti', 'West Tripura',
        ],
    },
    {
        'state_lgd': '09', 'state_name': 'Uttar Pradesh',
        'districts': [
            'Agra', 'Aligarh', 'Ambedkar Nagar', 'Amethi', 'Amroha',
            'Auraiya', 'Ayodhya', 'Azamgarh', 'Baghpat', 'Bahraich', 'Ballia',
            'Balrampur', 'Banda', 'Barabanki', 'Bareilly', 'Basti', 'Bhadohi',
            'Bijnor', 'Budaun', 'Bulandshahr', 'Chandauli', 'Chitrakoot',
            'Deoria', 'Etah', 'Etawah', 'Farrukhabad', 'Fatehpur',
            'Firozabad', 'Gautam Buddha Nagar', 'Ghaziabad', 'Ghazipur',
            'Gonda', 'Gorakhpur', 'Hamirpur', 'Hapur', 'Hardoi', 'Hathras',
            'Jalaun', 'Jaunpur', 'Jhansi', 'Kannauj', 'Kanpur Dehat',
            'Kanpur Nagar', 'Kasganj', 'Kaushambi', 'Lakhimpur Kheri',
            'Kushinagar', 'Lalitpur', 'Lucknow', 'Maharajganj', 'Mahoba',
            'Mainpuri', 'Mathura', 'Mau', 'Meerut', 'Mirzapur', 'Moradabad',
            'Muzaffarnagar', 'Pilibhit', 'Pratapgarh', 'Prayagraj',
            'Rae Bareli', 'Rampur', 'Saharanpur', 'Sambhal', 'Sant Kabir Nagar',
            'Shahjahanpur', 'Shamli', 'Shravasti', 'Siddharthnagar', 'Sitapur',
            'Sonbhadra', 'Sultanpur', 'Unnao', 'Varanasi',
        ],
    },
    {
        'state_lgd': '05', 'state_name': 'Uttarakhand',
        'districts': [
            'Almora', 'Bageshwar', 'Chamoli', 'Champawat', 'Dehradun',
            'Haridwar', 'Nainital', 'Pauri Garhwal', 'Pithoragarh',
            'Rudraprayag', 'Tehri Garhwal', 'Udham Singh Nagar', 'Uttarkashi',
        ],
    },
    {
        'state_lgd': '19', 'state_name': 'West Bengal',
        'districts': [
            'Alipurduar', 'Bankura', 'Birbhum', 'Cooch Behar',
            'Dakshin Dinajpur', 'Darjeeling', 'Hooghly', 'Howrah',
            'Jalpaiguri', 'Jhargram', 'Kalimpong', 'Kolkata', 'Malda',
            'Murshidabad', 'Nadia', 'North 24 Parganas', 'Paschim Bardhaman',
            'Paschim Medinipur', 'Purba Bardhaman', 'Purba Medinipur',
            'Purulia', 'South 24 Parganas', 'Uttar Dinajpur',
        ],
    },
    # ── Union Territories ────────────────────────────────────────────────
    {
        'state_lgd': '35', 'state_name': 'Andaman And Nicobar Islands',
        'districts': [
            'North And Middle Andaman', 'Nicobar', 'South Andaman',
        ],
    },
    {
        'state_lgd': '04', 'state_name': 'Chandigarh',
        'districts': ['Chandigarh'],
    },
    {
        'state_lgd': '26', 'state_name': 'Dadra And Nagar Haveli And Daman And Diu',
        'districts': ['Dadra And Nagar Haveli', 'Daman', 'Diu'],
    },
    {
        'state_lgd': '07', 'state_name': 'Delhi',
        'districts': [
            'Central Delhi', 'East Delhi', 'New Delhi', 'North Delhi',
            'North East Delhi', 'North West Delhi', 'Shahdara', 'South Delhi',
            'South East Delhi', 'South West Delhi', 'West Delhi',
        ],
    },
    {
        'state_lgd': '01', 'state_name': 'Jammu And Kashmir',
        'districts': [
            'Anantnag', 'Bandipora', 'Baramulla', 'Budgam', 'Doda',
            'Ganderbal', 'Jammu', 'Kathua', 'Kishtwar', 'Kulgam', 'Kupwara',
            'Poonch', 'Pulwama', 'Rajouri', 'Ramban', 'Reasi', 'Samba',
            'Shopian', 'Srinagar', 'Udhampur',
        ],
    },
    {
        'state_lgd': '38', 'state_name': 'Ladakh',
        'districts': ['Kargil', 'Leh'],
    },
    {
        'state_lgd': '31', 'state_name': 'Lakshadweep',
        'districts': ['Lakshadweep'],
    },
    {
        'state_lgd': '34', 'state_name': 'Puducherry',
        'districts': ['Karaikal', 'Mahe', 'Puducherry', 'Yanam'],
    },
]


class Command(BaseCommand):
    help = 'Load all Indian states/UTs and districts into the database'

    def add_arguments(self, parser):
        parser.add_argument(
            '--state',
            type=str,
            default=None,
            help='Reload only the state with this LGD code (e.g. 21 for Odisha)',
        )

    def handle(self, *args, **options):
        filter_state = options.get('state')
        states_created = districts_created = districts_skipped = 0

        for entry in INDIA_GEO:
            slgd = entry['state_lgd']
            if filter_state and slgd != filter_state:
                continue

            # ── Upsert state ────────────────────────────────────────────
            state_obj, s_created = State.objects.get_or_create(
                lgd_code=slgd,
                defaults={'name': entry['state_name']},
            )
            if s_created:
                states_created += 1
                self.stdout.write(f'  + State: {state_obj.name}')
            else:
                # Update name if it changed
                if state_obj.name != entry['state_name']:
                    state_obj.name = entry['state_name']
                    state_obj.save(update_fields=['name'])

            # ── Upsert districts ────────────────────────────────────────
            for seq, district_name in enumerate(entry['districts'], start=1):
                existing = District.objects.filter(
                    state=state_obj, name=district_name
                ).first()
                if existing:
                    districts_skipped += 1
                    continue

                # Generate a unique LGD code that won't conflict
                lgd_candidate = f"GEN{slgd.zfill(2)}{seq:04d}"
                while District.objects.filter(lgd_code=lgd_candidate).exists():
                    lgd_candidate += 'X'

                District.objects.create(
                    state=state_obj,
                    name=district_name,
                    lgd_code=lgd_candidate,
                )
                districts_created += 1

            self.stdout.write(
                f'  {entry["state_name"]}: '
                f'{len(entry["districts"])} districts '
                f'({districts_created} new so far)'
            )

        self.stdout.write(self.style.SUCCESS(
            f'\nDone! States: +{states_created}, '
            f'Districts: +{districts_created} new, '
            f'{districts_skipped} already existed'
        ))
