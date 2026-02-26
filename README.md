<div align="center">

# 🌾 PrajaShakti AI

### *जहाँ किसान की आवाज़ बदलाव बनती है*
### *Where a farmer's voice becomes change*

**The only platform where a voice note becomes a satellite-confirmed, scheme-matched, trackable development project.**

<br/>

[![Django](https://img.shields.io/badge/Django-5.x-092E20?style=for-the-badge&logo=django&logoColor=white)](https://djangoproject.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![AWS Bedrock](https://img.shields.io/badge/AWS_Bedrock-Claude_Sonnet-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/bedrock)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16_+_pgvector-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgresql.org)
[![Celery](https://img.shields.io/badge/Celery-5.x-37814A?style=for-the-badge&logo=celery&logoColor=white)](https://docs.celeryq.dev)
[![WhatsApp](https://img.shields.io/badge/WhatsApp_Bot-Twilio-25D366?style=for-the-badge&logo=whatsapp&logoColor=white)](https://twilio.com)

<br/>

> 🏆 **Rural Innovation Hackathon 2026** — AI-powered community intelligence for India's 2.5 lakh+ Panchayats

</div>

---

## 🎯 The Problem

India's 640,000 villages face a **broken feedback loop**:

| Pain Point | Reality |
|---|---|
| 🗣️ Citizens have needs | But no structured way to report them |
| 📋 Leaders have budgets | But no data to prioritise spending |
| 🏛️ Government has schemes | But 60%+ subsidy money goes unused |
| 📡 Satellites see crop stress | But data never reaches the village |

A water crisis in Ward 3 stays invisible while ₹12 lakh of Panchayat funds sit unused. **PrajaShakti AI fixes this.**

---

## 💡 The Solution

```
Citizen speaks → AI listens → Satellite confirms → Scheme matched → Project adopted → Problem solved
```

Three pillars working together:

| Pillar | What it does |
|---|---|
| 🎙️ **Community Voice** | Citizens report needs via voice/WhatsApp in Hindi — no app, no literacy required |
| 🛰️ **Geo Intelligence** | Bhuvan ISRO NDVI satellite data + CGWB groundwater validates every report |
| 🤖 **Smart Action** | AI recommends projects, matches government schemes, auto-generates PDF proposals |

---

## ✨ Key Features

### 🗺️ Village Intelligence Map (7 Layers)
Real-time map with toggleable layers — report heatmaps, satellite NDVI overlays, infrastructure gaps, active projects, and fund status all in one view.

### 📱 WhatsApp Bot (Zero App Required)
Citizens send voice notes in Hindi → AWS Transcribe converts to text → Claude Sonnet categorises → geo-tagged report appears on the map instantly.

```
Commands:
  GAON Tusra        → Select your village
  WARD 3            → Set your ward
  [Voice Note]      → Report a need (AI transcribes + categorises)
  Status            → Check your report status
  Vote 1            → Upvote report #1
  PM-KUSUM          → Check scheme eligibility via RAG
  Help              → Show all commands
```

### 🧠 AI Priority Engine
Composite scoring algorithm weighing community signals (votes, geographic spread, Gram Sabha mentions), satellite data, and urgency modifiers to rank clusters **0–100**.

```
Priority Score = Community (40%) + Data Validation (40%) + Urgency (20%)
```

### 📚 Scheme RAG Chatbot
pgvector-powered retrieval over 12 government schemes (PM-KUSUM, MGNREGA, JJM, PMGSY…). Ask in plain Hindi → get eligibility, application steps, and fund convergence plan.

### 🏛️ Digital Gram Sabha
Leaders run AI-moderated village meetings. Citizens raise issues, vote on priorities, and at session end Claude Sonnet auto-generates a bilingual (Hindi + English) official summary.

### 📄 One-Click Proposal Generation
Leaders tap "Adopt" → system generates a complete PDF project proposal with fund convergence plan, scheme applications, and expected impact metrics — in seconds.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Citizens                                 │
│              WhatsApp Bot          Flutter App (Web/Mobile)      │
└──────────┬──────────────────────────────────┬───────────────────┘
           │ Twilio Webhook                   │ REST API (JWT)
           ▼                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Django 5.x REST API                          │
│  auth_service │ community │ geo_intelligence │ ai_engine        │
│  scheme_rag   │ projects  │ notifications    │ data_ingestion   │
└──────┬────────────────────────────────────────────┬────────────┘
       │ Celery Tasks                               │ PostGIS queries
       ▼                                            ▼
┌──────────────┐   ┌──────────────┐   ┌───────────────────────────┐
│  AWS Bedrock │   │AWS Transcribe│   │  PostgreSQL 16            │
│Claude Sonnet │   │  Hindi Voice │   │  + PostGIS + pgvector     │
│Titan Embed   │   │  → Text      │   │  HNSW similarity index    │
└──────────────┘   └──────────────┘   └───────────────────────────┘
       │                                            │
       ▼                                            ▼
┌──────────────┐   ┌──────────────┐   ┌───────────────────────────┐
│    AWS S3    │   │  Redis 7     │   │   Bhuvan ISRO WMS         │
│  5 buckets   │   │  Broker +    │   │   NDVI Satellite Tiles    │
│  audio/docs  │   │  Cache       │   │   CGWB Groundwater        │
└──────────────┘   └──────────────┘   └───────────────────────────┘
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Backend** | Django 5.x + Django REST Framework |
| **Async Tasks** | Celery 5.x + Redis 7 |
| **Database** | PostgreSQL 16 + PostGIS + pgvector |
| **AI / LLM** | AWS Bedrock — Claude Sonnet 4.6 |
| **Voice** | AWS Transcribe (Hindi `hi-IN`) |
| **Embeddings** | Amazon Titan Embed Text v2 (1024-dim) |
| **Storage** | AWS S3 (5 buckets) |
| **Frontend** | Flutter 3.x — Web + iOS + Android |
| **State Mgmt** | flutter_bloc (Cubit pattern) |
| **Navigation** | GoRouter (ShellRoute + responsive shell) |
| **Maps** | flutter_map + Bhuvan ISRO WMS proxy |
| **Bot** | Twilio WhatsApp Sandbox |
| **Notifications** | Firebase Cloud Messaging + AWS SNS |

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version |
|---|---|
| Python | 3.13+ |
| PostgreSQL | 16 + PostGIS + pgvector |
| Redis | 7.x |
| Flutter | 3.x |
| AWS credentials | In `backend/.env` |

### 1. Start Backend

```bash
cd backend
source venv/bin/activate

# Start Django API server
python manage.py runserver
```

### 2. Load Demo Data (first time only)

```bash
python manage.py create_demo        # Tusra village, 65 reports, 2 clusters, 3 projects
python manage.py ingest_schemes     # Embed 12 schemes into pgvector (needs AWS)
python manage.py create_hnsw_index  # Create vector similarity index
```

### 3. Start Async Workers

```bash
# Terminal 2 — Celery worker (voice transcription, AI pipeline)
celery -A config worker -l info

# Terminal 3 — Celery beat (daily prices, weekly satellite refresh)
celery -A config beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler
```

### 4. Start Flutter App

```bash
cd frontend
flutter pub get
flutter run -d chrome        # Web (leader dashboard — responsive)
flutter run                  # iOS / Android
```

### 5. WhatsApp Bot (optional)

```bash
ngrok http 8000
# Set webhook in Twilio Console → https://xxxx.ngrok-free.app/api/v1/webhooks/whatsapp/
# Message +1 415 523 8886 on WhatsApp: "GAON Tusra"
```

> 📖 See [RUNNING.md](RUNNING.md) for full setup, troubleshooting, and all API endpoints.

---

## 🗂️ Repository Structure

```
praja-shakti/
├── backend/                    Django 5.x API
│   ├── apps/
│   │   ├── auth_service/       JWT auth, OTP, roles
│   │   ├── community/          Reports, votes, clusters, Gram Sabha
│   │   ├── geo_intelligence/   Satellite, maps, geospatial
│   │   ├── scheme_rag/         RAG pipeline, pgvector, fund convergence
│   │   ├── ai_engine/          Bedrock, Transcribe, scoring, recommendations
│   │   ├── projects/           Project lifecycle, tracking, ratings
│   │   └── notifications/      WhatsApp bot, FCM, SMS
│   └── docker-compose.yml      PostgreSQL + Redis
│
├── frontend/                   Flutter 3.x app
│   └── lib/
│       ├── app/                Router (responsive shell), theme
│       ├── core/               API client, models, responsive utils
│       └── features/
│           ├── map/            Village Intelligence Map (7 layers)
│           ├── report/         Voice + text reporting
│           ├── community/      Feed, upvoting, clusters
│           ├── projects/       Tracker, timeline, ratings
│           ├── schemes/        RAG chatbot
│           ├── gram_sabha/     Digital village meetings
│           └── dashboard/      Leader dashboard, adopt flow
│
├── scripts/                    ETL, data ingestion, RAG indexing
├── data/                       DISHA Dashboard scraped data (8 villages)
└── RUNNING.md                  Complete running instructions
```

---

## 📊 Demo Data — Tusra Village, Balangir, Odisha

| Metric | Value |
|---|---|
| Village | Tusra, Balangir, Odisha |
| Population | 4,800 |
| Reports | 65 (water, road, health) |
| Clusters | 2 (water: priority 94/100) |
| Projects | 3 (adopted, in_progress, completed) |
| Schemes | 12 (PM-KUSUM, MGNREGA, JJM…) |
| NDVI Score | 0.12 (high stress zone) |
| Groundwater | 14.2m depth (CGWB) |
| Fund Available | ₹12L (eGramSwaraj) |
| AI Recommendation | Solar borewell, ₹4.5L, 60% PM-KUSUM subsidy |

---

## 🎬 90-Second Demo Flow

```
0:00  Open Flutter web app → Village Intelligence Map
      → 65 red markers on Tusra village

0:10  Send WhatsApp voice note in Hindi
      → AI transcribes → categorises → marker appears on map live

0:25  Toggle Satellite layer
      → Bhuvan NDVI overlay → red stress zone matches water reports

0:35  GET /ai/priorities/?village=1
      → Water cluster: Priority Score 94/100 (community 38 + data 36 + urgency 20)

0:50  GET /ai/recommendations/?village=1
      → Solar borewell: ₹4.5L cost, PM-KUSUM 60% + MGNREGA 25% + Panchayat 15%

1:05  Leader taps "Adopt Project"
      → PDF proposal auto-generated → download link returned

1:15  Map marker: Red → Yellow → Blue → Green
      → Citizen receives WhatsApp: "आपकी रिपोर्ट पर काम शुरू हो गया!"
```

---

## 🌐 Responsive Design

The Flutter web app is fully responsive and adaptive:

| Screen | Layout |
|---|---|
| **Mobile** (< 600px) | BottomNavigationBar + single-column cards |
| **Tablet** (600–1024px) | NavigationRail (icon-only) + 2-column grid |
| **Desktop** (> 1024px) | NavigationRail (extended labels) + multi-column layout + side detail panels |

Platform-adaptive icons: Cupertino on iOS, Material on Android/Web.

---

## 📡 Key API Endpoints

```
Base: http://127.0.0.1:8000/api/v1/

Auth
  POST  /auth/otp/send/           Send OTP (returns otp_debug in dev)
  POST  /auth/login/              {phone, otp} → JWT tokens

Community
  GET   /reports/?village=1       All village reports
  POST  /reports/{id}/vote/       Upvote a report
  GET   /reports/clusters/?village=1   Spatial clusters (GeoJSON)

AI & Intelligence
  GET   /ai/priorities/?village=1      Ranked clusters with scores
  GET   /ai/recommendations/?village=1 AI project recommendations
  POST  /ai/scheme-query/              {query, village_id} → RAG answer

Leader Actions
  GET   /dashboard/summary/?panchayat=1
  POST  /projects/adopt/               {cluster_id, recommendation_index}
  GET   /projects/?village=1

Map
  GET   /map/layers/?village=1&layers=infra,heatmap,demographics,fund_status
  GET   /map/tiles/{z}/{x}/{y}.png     Bhuvan NDVI proxy (cached)

Gram Sabha
  POST  /gramsabha/               Create session
  POST  /gramsabha/{id}/end/      End session → triggers AI summary

WhatsApp
  POST  /webhooks/whatsapp/       Twilio webhook (no auth required)
```

---

## 🔒 Environment Variables

All credentials live in `backend/.env`:

```env
# Django
SECRET_KEY=...
DEBUG=True

# Database (use 127.0.0.1, not localhost — IPv6 issue on Apple Silicon)
DB_HOST=127.0.0.1
DB_NAME=prajashakti
DB_USER=your_user

# Redis
REDIS_URL=redis://127.0.0.1:6379/0

# AWS
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=global.anthropic.claude-sonnet-4-6
BEDROCK_EMBEDDING_MODEL_ID=amazon.titan-embed-text-v2:0

# Twilio
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_WHATSAPP_NUMBER=whatsapp:+14155238886

# Bhuvan ISRO
BHUVAN_TOKEN=...
```

---

## 🌱 Impact at Scale

| Metric | Target |
|---|---|
| Panchayats | 2,50,000+ across India |
| Citizens reachable | 800 million (via WhatsApp — no smartphone required) |
| Schemes covered | 50+ central + state schemes |
| Languages | Hindi first; extensible to 22 scheduled languages |
| Fund efficiency | 40–60% improvement in scheme utilisation |

---

<div align="center">

**Built with ❤️ for Rural India**

*PrajaShakti AI — Rural Innovation Hackathon 2026*

</div>
