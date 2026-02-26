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
# Populate village, 65 reports, 2 clusters, 3 projects, 12 schemes
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

4. Enter the OTP and tap **Login** → the Village Intelligence Map loads

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
- `GAON Tusra` — select your village (required on first message)
- `WARD 3` — set ward number
- Voice note → AI transcription + categorization
- `Status` — view your latest reports
- `Vote 1` — upvote report #1
- `PM-KUSUM` — scheme eligibility query via RAG
- `Help` — show all commands

---

## Key API Endpoints

Base URL: `http://127.0.0.1:8000/api/v1/`

All endpoints (except auth and webhook) require a JWT `Authorization: Bearer <token>` header.

### Auth

```
POST  /auth/otp/send/           {"phone": "9999999999"}
POST  /auth/login/              {"phone": "9999999999", "otp": "123456"}
GET   /auth/profile/
```

### Reports & Community

```
GET   /reports/?village=1
POST  /reports/
POST  /reports/{id}/vote/
GET   /reports/clusters/?village=1    # GeoJSON clusters
```

### Map

```
GET   /map/layers/?village=1&layers=reports,satellite,infra,heatmap,projects,demographics,fund_status
GET   /map/tiles/{z}/{x}/{y}.png?village=1&type=ndvi    # Bhuvan NDVI proxy
GET   /geo/villages/1/
```

### AI & Intelligence

```
GET   /ai/priorities/?village=1       # Ranked clusters with priority scores
GET   /ai/recommendations/?village=1  # AI project recommendations
POST  /ai/scheme-query/               {"query": "PM-KUSUM eligibility", "village_id": 1}
```

### Projects & Dashboard

```
GET   /dashboard/summary/?panchayat=1
GET   /dashboard/fund-status/?panchayat=1
POST  /projects/adopt/                {"cluster_id": 1, "recommendation_index": 0}
GET   /projects/?village=1
PATCH /projects/{id}/status/          {"status": "in_progress"}
```

### Gram Sabha

```
GET   /gramsabha/?village=1
POST  /gramsabha/                     {"village": 1, "title": "...", "scheduled_at": "..."}
POST  /gramsabha/{id}/issues/         {"title": "Water scarcity in Ward 3", "session": id}
POST  /gramsabha/{id}/end/            # Triggers AI summary via Celery
```

---

## Demo Walkthrough (90-Second Hackathon Flow)

```
1. Open Flutter app → Village Intelligence Map → 65 red markers on Tusra village
2. Send WhatsApp voice note → AI transcribes Hindi → marker appears on map
3. Send "Vote 1" via WhatsApp → upvote count increases
4. Toggle Satellite layer → Bhuvan NDVI overlay → stress zone visible
5. GET /ai/priorities/?village=1 → Water cluster: priority score 94/100
6. GET /ai/recommendations/?village=1 → Solar borewell, Rs.4.5L, PM-KUSUM 60%
7. POST /projects/adopt/ → PDF proposal generated → Download URL in response
8. Marker color: Red → Yellow → Blue → Green
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

**Celery tasks not running**
→ Check that Terminal 2 (worker) is active. WhatsApp bot falls back to background threads
if Celery is unavailable — voice transcription still works but without retry logic.
