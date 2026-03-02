# PrajaShakti AI — Running Instructions

> One platform where a farmer's voice note becomes a satellite-confirmed, scheme-matched,
> trackable development project.

---

## Prerequisites

| Requirement | Version | Install |
|---|---|---|
| Python | 3.13+ | `brew install python@3.13` |
| PostgreSQL 16 + PostGIS | 16.x | Docker (recommended) or `brew install postgresql@16 postgis` |
| Redis | 7.x | Docker (recommended) or `brew install redis` |
| Flutter | 3.x | [flutter.dev/install](https://docs.flutter.dev/get-started/install) |
| Docker Desktop | latest | [docker.com](https://www.docker.com/products/docker-desktop/) |

All Python dependencies are pre-installed in `backend/venv/`. AWS, Twilio, and Bhuvan
credentials are already in `backend/.env`.

---

## Quick Start (First Time)

```bash
cd .claude/worktrees/intelligent-booth/backend
make setup
```

This runs: copy `.env`, install deps, start Docker (PostgreSQL + Redis), run migrations,
load demo data.

**Then jump to [Running the Stack](#running-the-stack).**

---

## Manual Setup (Step by Step)

### Step 1 — Start Infrastructure

```bash
cd .claude/worktrees/intelligent-booth/backend

# Start PostgreSQL 16 (PostGIS + pgvector) and Redis 7
docker-compose up -d

# Verify both are healthy
docker-compose ps
```

> **Note:** If you prefer native installs over Docker:
> ```bash
> brew services start postgresql@16
> brew services start redis
> psql prajashakti -c "CREATE EXTENSION IF NOT EXISTS postgis; CREATE EXTENSION IF NOT EXISTS vector;"
> ```

### Step 2 — Activate Virtual Environment

```bash
source venv/bin/activate
```

All subsequent commands assume the venv is active.

### Step 3 — Run Migrations

```bash
python manage.py migrate
```

### Step 4 — Create Superuser (optional, for /admin access)

```bash
python manage.py createsuperuser
# Enter username, email, password when prompted
```

### Step 5 — Load Demo Data (Tusra Village, Balangir, Odisha)

```bash
# Populate village, 65 reports, 2 clusters, 3 projects, 12 schemes, demo users
python manage.py create_demo

# Embed scheme documents into pgvector (Bedrock Titan — requires AWS)
python manage.py ingest_schemes

# Create HNSW vector index for fast similarity search
python manage.py create_hnsw_index

# Register Celery Beat periodic tasks in DB
python manage.py setup_periodic_tasks
```

> `create_demo` is **idempotent** — safe to run multiple times.
> `ingest_schemes` and `create_hnsw_index` only need to run **once**.

---

## Running the Stack

Open **4 terminals**, all in `backend/` with venv active:

### Terminal 1 — Django API Server

```bash
cd .claude/worktrees/intelligent-booth/backend
source venv/bin/activate
python manage.py runserver
```

API available at: **http://127.0.0.1:8000/api/v1/**
Admin panel: **http://127.0.0.1:8000/admin/**

### Terminal 2 — Celery Worker (Async AI Pipeline)

```bash
cd .claude/worktrees/intelligent-booth/backend
source venv/bin/activate
celery -A config worker -l info
```

Handles: voice transcription, Bedrock categorization, spatial clustering,
priority scoring, Gram Sabha AI summaries.

> If Celery is not running, the WhatsApp bot **automatically falls back to background threads**
> so voice transcription still works — just without retry logic.

### Terminal 3 — Celery Beat (Scheduled Tasks)

```bash
cd .claude/worktrees/intelligent-booth/backend
source venv/bin/activate
celery -A config beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler
```

Handles: daily mandi prices, weekly satellite refresh, groundwater sync.

### Terminal 4 — Flutter Web App

#### Step 1 — Install dependencies

```bash
cd .claude/worktrees/intelligent-booth/frontend
flutter pub get
```

#### Step 2 — Verify web support is enabled

```bash
flutter devices
```

You should see `Chrome (web)` in the list. If not, run once:

```bash
flutter create . --platforms web
```

This adds the `web/` directory without touching your Dart code.

#### Step 3 — Run in Chrome

```bash
flutter run -d chrome
```

The app opens automatically at `http://localhost:<random-port>`.
To use a fixed port (useful for bookmarking):

```bash
flutter run -d chrome --web-port 3000
# Opens at http://localhost:3000
```

#### Step 4 — Log in

The app shows a phone number + OTP screen.

1. Enter your mobile number in **international format**: `+919078277159`
2. Tap **Send OTP**
3. In development, SMS is not sent — get the OTP from the Django server terminal:

   ```
   [OTP] +919078277159 → 836118   ← look for this line
   ```

   Or fetch it via curl:

   ```bash
   curl -s -X POST http://127.0.0.1:8000/api/v1/auth/otp/send/ \
     -H "Content-Type: application/json" \
     -d '{"phone": "+919078277159"}' | python3 -m json.tool
   # Look for "otp_debug" in the response
   ```

4. Enter the OTP and tap **Login**
5. You are **automatically redirected** based on your role:
   - **Leader** → Leader Dashboard (Adopt, Fund Status, Active Projects)
   - **Citizen** → Community Feed
   - **Admin** → Government Dashboard

> **Important:** Always use `+91` prefix. The login screen normalises the number —
> the OTP must be requested with the same prefix or it won't match.

#### Step 5 — Hot reload during development

While the app is running, press:

| Key | Action |
|---|---|
| `r` | Hot reload (UI changes — fast) |
| `R` | Hot restart (state changes — slower) |
| `q` | Quit |

Or in VS Code, use the Flutter extension toolbar buttons.

#### Run in release mode (faster, no debug banner)

```bash
flutter run -d chrome --release
```

#### Build a static web bundle (deploy anywhere)

```bash
flutter build web --release
# Output: build/web/  — serve with any static file server
python3 -m http.server 8080 --directory build/web
```

---

## Demo Users (created by `create_demo`)

| Role | Phone | OTP method |
|---|---|---|
| Leader (Suman) | `+919078277159` | `otp_debug` in OTP response or Django terminal |
| Citizen | Any `+91XXXXXXXXXX` | Same — `otp_debug` in response |

To check a user's role or promote to leader:
```bash
python manage.py shell -c "
from apps.auth_service.models import User
u = User.objects.get(phone='+919078277159')
print(u.role, u.panchayat)
# u.role = 'leader'; u.save()  # promote if needed
"
```

---

## Adopt Project Flow

The leader dashboard shows AI-ranked clusters. Clicking **Adopt** on any cluster:

1. Opens a confirmation dialog showing category, report count, and priority score
2. Clicking **Adopt Project** calls `POST /projects/adopt/` — a loading spinner appears
3. The backend:
   - Sets project status to `in_progress`
   - Creates a **Fund Convergence Plan** (category-based scheme mix)
   - Generates a **PDF proposal** via ReportLab and uploads to S3
   - Returns a presigned S3 URL valid for 1 hour
4. The dialog transitions to the **Proposal View** showing:
   - Project title and total cost
   - Scheme allocation table (e.g. PM-KUSUM 60%, MGNREGA 20%, JJM 10%)
   - Panchayat contribution and total savings %
   - **Download PDF** button — opens the S3-hosted proposal in a new browser tab
5. Clicking **Close** refreshes the dashboard — project now appears under **Active Projects**

### Downloading the PDF on Web

The **Download PDF** button opens an S3 presigned URL directly (no auth required, expires in 1 hour).

If S3 upload fails or no key is set, the button falls back to the Django streaming endpoint:
```
GET /api/v1/projects/{id}/proposal/?token=<jwt>
```
This streams the PDF directly from Django. The JWT token is appended automatically by the app.

---

## WhatsApp Bot (Twilio Webhook)

To receive real WhatsApp messages during development, expose the local server with ngrok:

```bash
# Install ngrok if needed: brew install ngrok
ngrok http 8000
```

Copy the `https://xxxx.ngrok-free.app` URL and set it in the
[Twilio Console](https://console.twilio.com/) → Messaging → Sandbox settings:

```
Webhook URL: https://xxxx.ngrok-free.app/api/v1/webhooks/whatsapp/
```

**Test the bot** by sending WhatsApp to `+1 415 523 8886` (Twilio sandbox):

| Message | Response |
|---|---|
| `GAON Tusra` | Sets village — required on first message |
| `GAON Tu` | Lists matching villages if multiple found |
| `WARD 3` | Sets ward number |
| Voice note | AI transcribes + categorises + creates report |
| `Status` | Shows your latest report status and upvote count |
| `Vote 1` | Upvotes report #1 |
| `PM-KUSUM` | Scheme eligibility query via RAG |
| `Help` | Shows all commands in Hindi |

> New users are **blocked from sending reports** until they set their village with `GAON <name>`.
> Existing users with a panchayat set bypass this gate automatically.

---

## Key API Endpoints

Base URL: `http://127.0.0.1:8000/api/v1/`

All endpoints (except auth and webhook) require a JWT `Authorization: Bearer <token>` header.

### Auth

```
POST  /auth/otp/send/           {"phone": "+91XXXXXXXXXX"}
                                → {"message": "OTP sent", "otp_debug": "123456"}
POST  /auth/login/              {"phone": "+91XXXXXXXXXX", "otp": "123456"}
                                → {access, refresh, role, user_id}
GET   /auth/profile/
```

### Reports & Community

```
GET   /reports/?village=1
POST  /reports/
POST  /reports/{id}/vote/
DELETE /reports/{id}/vote/
GET   /reports/clusters/?village=1    # GeoJSON clusters
```

### Map

```
GET   /map/layers/?village=1&layers=reports,satellite,infra,heatmap,projects,demographics,fund_status
GET   /map/tiles/{z}/{x}/{y}.png?village=1&type=ndvi    # Bhuvan NDVI proxy (Redis-cached)
GET   /geo/villages/1/
```

### AI & Intelligence

```
GET   /ai/priorities/?village=1
      → {total_reports, results: [{id, category, report_count, upvote_count, priority_score}]}

GET   /ai/recommendations/?village=1
      → [ProjectSerializer] with fund_plans and proposal_download_url

POST  /ai/scheme-query/
      {"query": "PM-KUSUM eligibility for borewell", "village_id": 1}
      → {answer, sources: [{scheme, section}]}
```

### Projects & Dashboard

```
GET   /dashboard/summary/?panchayat=1
GET   /dashboard/fund-status/?panchayat=1

POST  /projects/adopt/
      {"cluster_id": 1, "recommendation_index": 0}
      → ProjectSerializer with fund_plans[] and proposal_download_url (S3 presigned)

GET   /projects/?village=1&status=in_progress
GET   /projects/{id}/
GET   /projects/{id}/proposal/       Stream PDF directly
                                     Auth: Bearer header OR ?token=<jwt> query param
PATCH /projects/{id}/status/         {"status": "in_progress"}
POST  /projects/{id}/photos/         Multipart upload → S3
POST  /projects/{id}/rating/         {"rating": 4, "review": "Good work"}
```

### Gram Sabha

```
GET   /gramsabha/?village=1
POST  /gramsabha/                     {"village": 1, "title": "...", "scheduled_at": "..."}
POST  /gramsabha/{id}/issues/         {"title": "Water scarcity in Ward 3", "session": id}
POST  /gramsabha/{id}/issues/{issue_id}/vote/
POST  /gramsabha/{id}/end/            → triggers Claude AI summary (async Celery task)
                                        summary saved to session.transcript
```

### WhatsApp

```
POST  /webhooks/whatsapp/       Twilio webhook (AllowAny — no JWT required)
```

---

## Demo Walkthrough (90-Second Hackathon Flow)

```
1. Open Flutter app → Village Intelligence Map → 65 red markers on Tusra village

2. Send WhatsApp voice note ("paani nahi aa raha")
   → AI transcribes Hindi → new marker appears on map

3. Toggle Satellite layer → Bhuvan NDVI overlay → stress zone visible

4. Leader Dashboard → AI Priority Ranking
   → Water cluster: 94/100 (Community: 38, Data: 38, Urgency: 18)

5. Tap "Adopt" on Water cluster
   → Confirmation dialog → click "Adopt Project" → spinner
   → Proposal view appears:
       Solar Borewell with Piped Supply
       Total Cost: ₹4.5L
       PM-KUSUM: ₹2.7L (60%)
       MGNREGA:  ₹0.9L (20%)
       Jal Jeevan Mission: ₹0.45L (10%)
       Panchayat Pays: ₹0.45L
       Savings: 90%
   → "Download PDF" button → opens proposal in browser

6. Close dialog → Dashboard refreshes
   → Active Projects section shows "Solar Borewell with Piped Supply"
   → Map marker: Red → Yellow → Blue
```

---

## Configuration Reference

All config lives in `backend/.env`:

| Variable | Value | Notes |
|---|---|---|
| `DB_HOST` | `127.0.0.1` | Do NOT use `localhost` (IPv6 issue on Apple Silicon) |
| `DB_NAME` | `prajashakti` | |
| `DB_USER` | `siddharthsaraf` | Local macOS user (no password) |
| `REDIS_URL` | `redis://127.0.0.1:6379/0` | |
| `AWS_REGION` | `us-east-1` | Bedrock + Transcribe + S3 |
| `BEDROCK_MODEL_ID` | `global.anthropic.claude-sonnet-4-6` | Inference profile required |
| `BEDROCK_EMBEDDING_MODEL_ID` | `amazon.titan-embed-text-v2:0` | 1024 dimensions |
| `TWILIO_WHATSAPP_NUMBER` | `whatsapp:+14155238886` | Sandbox number |
| `DJANGO_SETTINGS_MODULE` | `config.settings.development` | Default |

---

## Makefile Shortcuts

```bash
make setup    # First-time setup: Docker + migrate + demo data
make run      # Start Django server
make worker   # Start Celery worker
make beat     # Start Celery Beat
make demo     # Reload demo data
make clean    # Stop Docker + wipe volumes
```

---

## Troubleshooting

**`django.db.utils.OperationalError: could not connect to server`**
→ PostgreSQL not running. Run `docker-compose up -d` or `brew services start postgresql@16`.

**`redis.exceptions.ConnectionError`**
→ Redis not running. Run `docker-compose up -d` or `brew services start redis`.

**`GDAL_LIBRARY_PATH` error on macOS**
→ Add to `.env`:
```
GDAL_LIBRARY_PATH=/opt/homebrew/lib/libgdal.dylib
GEOS_LIBRARY_PATH=/opt/homebrew/lib/libgeos_c.dylib
```

**`Error: No module named 'pgvector'`**
→ `pip install pgvector` inside the venv.

**Bedrock `AccessDeniedException`**
→ Model access not enabled. Go to AWS Console → Bedrock → Model access → enable
`claude-sonnet-4-6` and `titan-embed-text-v2`.

**Flutter `MissingPluginException` for url_launcher**
→ Run `flutter pub get` and restart the app (hot reload is insufficient for native plugins).

**`flutter run -d chrome` says "This application is not configured to build on the web"**
→ Web platform not yet added. Run once from the `frontend/` directory:
```bash
flutter create . --platforms web
```

**Map loads but shows India (zoom 5) instead of Tusra village**
→ The Django server must be running (`python manage.py runserver`) before you open the app.
If the map loaded before the API responded, press the **↻ refresh** button in the top-right
of the map screen.

**"Phone and OTP are required" error on login**
→ Always enter the phone with `+91` prefix (e.g. `+919078277159`). If you sent the OTP
without `+91`, send it again with the prefix — the stored OTP must match the login number.

**Login works but map shows "Failed to load village data"**
→ Django server not running or crashed. Check Terminal 1 for errors and restart:
```bash
python manage.py runserver
```

**`flutter pub get` fails with dependency conflicts**
→ Run `flutter clean` then `flutter pub get`.

**Chrome opens but shows a blank white page**
→ Open DevTools (F12) → Console tab. Usually a CORS error:
make sure `CORS_ALLOWED_ORIGINS` in `backend/.env` includes `http://localhost:3000`
(or whatever port Flutter is using). Then restart Django.

**Adopt button does nothing / Cancel button does nothing**
→ This was a Flutter Web navigator context bug (fixed). Ensure you are on the latest code.
If you see the issue on an older build, do a full hot restart (`R`) or clear the browser cache
and reload. The fix replaced the old dialog with a `StatefulWidget` that uses its own context
for all `Navigator.of(context).pop()` calls.

**"Failed: ..." error after clicking Adopt Project**
→ Check the Django terminal for the error. Common causes:
- Leader role not set on the user → `u.role = 'leader'; u.save()` in Django shell
- `IsLeader` permission check failing → confirm login was with a leader-role account

**Proposal PDF download opens a blank page or 401**
→ The S3 presigned URL expires after 1 hour. Re-adopt the project to generate a fresh URL.
If using the Django fallback (`/api/v1/projects/{id}/proposal/?token=...`), check that:
- The token is valid (not expired — default JWT lifetime is 60 minutes)
- Django server is running

**Celery tasks not running**
→ Check that Terminal 2 (worker) is active. The WhatsApp bot falls back to background threads
automatically — voice transcription still works but without retry logic.

**Gram Sabha "End Session" → no AI summary after 30 seconds**
→ Celery worker must be running (Terminal 2). The summary is generated asynchronously.
Pull-to-refresh or navigate away and back to see the updated `transcript` field.

**WhatsApp: "Gaon nahi mila" (village not found)**
→ Try the full village name: `GAON Tusra`. The search is case-insensitive and matches
substrings, but requires at least 3 characters.
