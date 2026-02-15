# Design Document: PrajaShakti Platform

## Overview

PrajaShakti is a citizen-driven geospatial intelligence platform that empowers rural communities in India by enabling voice-first and text-based reporting of local development needs. The platform combines mobile-first citizen interfaces with AI-powered categorization, geospatial visualization, and data validation to help village leaders prioritize and track development projects.

### Core Design Principles

1. **Voice-First Design**: Prioritize voice input to accommodate low-literacy users in rural areas
2. **Offline-First Architecture**: Support report creation and queuing in low-connectivity environments
3. **Geospatial-Native**: Treat location as a first-class citizen in all data models and queries
4. **Multi-Language by Default**: Support Hindi, English, and regional languages throughout the stack
5. **Progressive Enhancement**: Provide basic functionality immediately, enhance with AI/validation asynchronously

### Technology Stack

- **Mobile App & Dashboard**: Flutter (cross-platform iOS/Android/Web)
- **Backend API**: Django 4.x with Django REST Framework
- **Database**: 
  - PostgreSQL 14+ with PostGIS 3.x for geospatial queries (primary database)
  - SQLite for local offline storage in mobile app
- **AI Services**: Amazon Bedrock (AWS)
  - Voice Transcription: Amazon Transcribe (supports Hindi and regional languages)
  - AI Categorization: Amazon Bedrock with Claude or Titan models
  - Translation: Amazon Translate
- **Map Visualization**: Mapbox GL for Flutter with custom clustering
- **External Data**: Bhuvan API (ISRO), OpenStreetMap Overpass API
- **Alternative Channels**:
  - SMS/IVR: Twilio or Amazon SNS/Amazon Connect
  - WhatsApp: WhatsApp Business API via Twilio
- **Hosting**: AWS
  - API: AWS Lambda + API Gateway (serverless) or EC2
  - Database: Amazon RDS for PostgreSQL
  - Storage: Amazon S3 for voice recordings and images
  - AI: Amazon Bedrock for all AI workloads

## Architecture

### System Architecture

The platform follows a three-tier architecture with mobile clients, a RESTful API backend, and a PostgreSQL/PostGIS database.

```
┌─────────────────────────────────────────────────────────────┐
│                     Client Layer                             │
├──────────────────────────┬──────────────────────────────────┤
│   Mobile App             │   Leader Dashboard               │
│   (Flutter)              │   (Flutter Web)                  │
│   - Voice Recording      │   - Report Management            │
│   - Text Input           │   - Map Visualization            │
│   - GPS Capture          │   - Priority Review              │
│   - Offline Queue        │   - Analytics                    │
│   - SQLite Local DB      │                                  │
└──────────────┬───────────┴──────────────┬───────────────────┘
               │                          │
               │      HTTPS/REST API      │
               │                          │
┌──────────────┴──────────────────────────┴───────────────────┐
│                     API Layer                                │
│                  (Django/DRF)                                │
├──────────────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌─────────────┐           │
│  │  Report    │  │   Voice    │  │     AI      │           │
│  │  Service   │  │  Service   │  │  Service    │           │
│  └────────────┘  └────────────┘  └─────────────┘           │
│  ┌────────────┐  ┌────────────┐  ┌─────────────┐           │
│  │    Map     │  │ Validation │  │   Queue     │           │
│  │  Service   │  │  Service   │  │  Service    │           │
│  └────────────┘  └────────────┘  └─────────────┘           │
│  ┌────────────┐  ┌────────────┐  ┌─────────────┐           │
│  │    SMS     │  │    IVR     │  │  WhatsApp   │           │
│  │  Handler   │  │  Handler   │  │  Handler    │           │
│  └────────────┘  └────────────┘  └─────────────┘           │
└──────────────┬───────────────────────────────────────────────┘
               │
               │      SQL/PostGIS
               │
┌──────────────┴───────────────────────────────────────────────┐
│                   Data Layer                                  │
│              (PostgreSQL + PostGIS)                           │
├───────────────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌─────────────┐            │
│  │  reports   │  │  villages  │  │   users     │            │
│  │  (spatial) │  │  (spatial) │  │             │            │
│  └────────────┘  └────────────┘  └─────────────┘            │
└───────────────────────────────────────────────────────────────┘

External Services:
┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  Amazon Bedrock │  │  Amazon          │  │  Bhuvan API      │
│  (AI/ML)        │  │  Transcribe      │  │  (ISRO)          │
│  - Claude       │  │  (Voice-to-Text) │  │                  │
│  - Titan        │  └──────────────────┘  └──────────────────┘
└─────────────────┘  ┌──────────────────┐  ┌──────────────────┐
                     │  Twilio          │  │  WhatsApp        │
                     │  (SMS/IVR)       │  │  Business API    │
                     └──────────────────┘  └──────────────────┘
```

### Data Flow

#### Report Submission Flow

1. **Citizen Input**: User records voice or types text in mobile app
2. **GPS Capture**: App captures GPS coordinates with accuracy check
3. **Local Validation**: App validates input length and GPS accuracy
4. **API Submission**: App sends report to `/api/reports` endpoint
5. **Async Processing**: API queues report for transcription (if voice), categorization, and validation
6. **Storage**: Report saved to PostgreSQL with PostGIS spatial index
7. **Confirmation**: API returns report ID and confirmation to mobile app

#### AI Processing Pipeline

1. **Voice Transcription** (if applicable): Amazon Transcribe converts audio to text
2. **Language Detection**: Detect source language from text
3. **Translation** (if needed): Translate to English for categorization using Amazon Translate
4. **Categorization**: Amazon Bedrock (Claude/Titan) classifies report into predefined category
5. **Metadata Extraction**: Amazon Bedrock extracts infrastructure types, quantities, temporal references
6. **Priority Scoring**: Calculate priority based on urgency keywords and clustering
7. **External Validation**: Query Bhuvan and OSM for contextual data
8. **Update Report**: Store all processed metadata in database

#### Alternative Channel Submission Flow

1. **SMS/WhatsApp/IVR Input**: User submits report via alternative channel
2. **Webhook Reception**: Django receives webhook from Twilio/WhatsApp API
3. **Phone Number Extraction**: Extract sender's phone number
4. **User Lookup/Creation**: Get or create user account based on phone number
5. **Content Processing**: 
   - SMS: Use text directly as description
   - IVR: Download voice recording from Twilio, process like app voice
   - WhatsApp: Handle text, voice note, or image based on message type
6. **Location Assignment**: Use village centroid if no GPS data available
7. **Queue for Processing**: Add to same AI processing pipeline as app submissions
8. **Confirmation**: Send confirmation message with report ID via same channel
9. **Status Queries**: Handle "STATUS <id>" queries with current report status

## Components and Interfaces

### Mobile App Components (Flutter)

#### ReportingScreen

Primary interface for citizen report submission.

```dart
class ReportingScreen extends StatefulWidget {
  final String userId;
  final String villageId;
  
  @override
  _ReportingScreenState createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  InputMode inputMode = InputMode.voice;
  AudioRecording? voiceRecording;
  String textInput = '';
  GPSCoordinates? gpsCoordinates;
  double? gpsAccuracy;
  bool isSubmitting = false;
  String? transcribedText;
  
  // Start voice recording
  Future<void> startVoiceRecording() async {}
  
  // Stop voice recording and get audio file
  Future<AudioRecording> stopVoiceRecording() async {}
  
  // Capture GPS coordinates
  Future<GPSCoordinates> captureGPS() async {}
  
  // Submit report to API
  Future<ReportResponse> submitReport(ReportSubmission report) async {}
  
  // Queue report for offline sync (stored in SQLite)
  Future<void> queueOfflineReport(ReportSubmission report) async {}
}

enum InputMode { voice, text }

class GPSCoordinates {
  final double latitude;
  final double longitude;
  
  GPSCoordinates(this.latitude, this.longitude);
}

class AudioRecording {
  final String filePath;
  final Duration duration;
  
  AudioRecording(this.filePath, this.duration);
}
```

#### MapScreen

Interactive map visualization of village reports.

```dart
class MapScreen extends StatefulWidget {
  final String villageId;
  final GPSCoordinates initialCenter;
  final double initialZoom;
  
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Report> reports = [];
  Report? selectedReport;
  BoundingBox? mapBounds;
  bool clusteringEnabled = true;
  
  // Load reports within map bounds
  Future<List<Report>> loadReportsInBounds(BoundingBox bounds) async {}
  
  // Handle marker click
  void onMarkerClick(String reportId) {}
  
  // Handle map movement
  void onMapMove(BoundingBox newBounds) {}
  
  // Cluster nearby reports
  List<ReportCluster> clusterReports(List<Report> reports, double thresholdMeters) {}
}

class BoundingBox {
  final GPSCoordinates southwest;
  final GPSCoordinates northeast;
  
  BoundingBox(this.southwest, this.northeast);
}
```

#### OfflineQueueManager

Manages offline report queue using SQLite.

```dart
class OfflineQueueManager {
  static final OfflineQueueManager _instance = OfflineQueueManager._internal();
  factory OfflineQueueManager() => _instance;
  OfflineQueueManager._internal();
  
  Database? _database;
  
  // Initialize SQLite database
  Future<void> initDatabase() async {}
  
  // Add report to offline queue
  Future<void> queueReport(OfflineReport report) async {}
  
  // Get all pending reports
  Future<List<OfflineReport>> getPendingReports() async {}
  
  // Sync pending reports to server
  Future<void> syncPendingReports() async {}
  
  // Mark report as synced
  Future<void> markAsSynced(String localId) async {}
  
  // Update sync status
  Future<void> updateSyncStatus(String localId, SyncStatus status, String? error) async {}
}

class OfflineReport {
  final String localId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final int syncAttempts;
  final String? lastSyncError;
  
  OfflineReport({
    required this.localId,
    required this.data,
    required this.createdAt,
    required this.syncStatus,
    this.syncAttempts = 0,
    this.lastSyncError,
  });
}

enum SyncStatus { pending, syncing, synced, failed }
```

### Backend API Services (Django)

#### ReportService

Core service for report CRUD operations.

```python
from typing import List, Optional, Dict, Any
from datetime import datetime
from dataclasses import dataclass

@dataclass
class CreateReportDTO:
    user_id: str
    village_id: str
    description: Optional[str] = None
    voice_recording_url: Optional[str] = None
    gps_coordinates: 'GPSCoordinates'
    gps_accuracy: float
    language: str
    input_mode: str  # 'voice' or 'text'
    submission_channel: str = 'app'  # 'app', 'sms', 'ivr', 'whatsapp'

@dataclass
class ReportFilters:
    category: Optional[str] = None
    min_priority: Optional[int] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    validation_status: Optional[str] = None

class ReportService:
    """Service for report CRUD operations"""
    
    def create_report(self, data: CreateReportDTO) -> 'Report':
        """Create a new report"""
        pass
    
    def get_report_by_id(self, report_id: str) -> Optional['Report']:
        """Get report by ID"""
        pass
    
    def get_reports_by_village(self, village_id: str, filters: ReportFilters) -> List['Report']:
        """Get reports by village with optional filters"""
        pass
    
    def get_reports_in_bounds(self, bounds: 'BoundingBox') -> List['Report']:
        """Get reports within geographic bounds using PostGIS"""
        pass
    
    def get_reports_near_point(self, point: 'GPSCoordinates', radius_meters: float) -> List['Report']:
        """Get reports within radius of point using PostGIS ST_DWithin"""
        pass
    
    def update_report_metadata(self, report_id: str, metadata: Dict[str, Any]) -> 'Report':
        """Update report metadata (category, priority, validation, etc.)"""
        pass
    
    def get_reports_by_category(self, village_id: str, category: str) -> List['Report']:
        """Get reports by category for a village"""
        pass
```

#### VoiceService

Handles voice transcription using Amazon Transcribe.

class VoiceService {
  // Transcribe audio file to text using Amazon Transcribe
  Future<TranscriptionResult> transcribeAudio(String audioUrl, String languageCode) async {}
  
  // Detect language from audio
  Future<String> detectLanguage(String audioUrl) async {}
  
  // Upload audio file to S3
  Future<String> uploadAudioFile(Uint8List audioData, String reportId) async {}
}

class TranscriptionResult {
  final String text;
  final double confidence;
  final String language;
  final List<String>? alternatives;

  TranscriptionResult({
    required this.text,
    required this.confidence,
    required this.language,
    this.alternatives,
  });
}
interface VoiceService {
  // Transcribe audio file to text using Amazon Transcribe
  transcribeAudio(audioUrl: string, languageCode: string): Promise<TranscriptionResult>
  
  // Detect language from audio
  detectLanguage(audioUrl: string): Promise<string>
  
  // Upload audio file to S3
  uploadAudioFile(audioData: Buffer, reportId: string): Promise<string>
}

interface TranscriptionResult {
  text: string;
  confidence: number;
  language: string;
  alternatives?: string[];
}
```

#### AlternativeChannelService

Handles report submissions through SMS, IVR, and WhatsApp.

```python
from typing import Optional, Dict, Any
from dataclasses import dataclass

@dataclass
class ChannelSubmission:
    phone_number: str
    content: str
    channel: str  # 'sms', 'ivr', 'whatsapp'
    media_url: Optional[str] = None  # For voice notes or images
    timestamp: datetime

class AlternativeChannelService:
    """Service for handling SMS, IVR, and WhatsApp submissions"""
    
    def handle_sms_submission(self, phone_number: str, message_body: str) -> Dict[str, Any]:
        """
        Process incoming SMS report submission
        
        Args:
            phone_number: Sender's phone number
            message_body: SMS text content
            
        Returns:
            Dict with report_id and confirmation message
        """
        pass
    
    def handle_ivr_recording(self, phone_number: str, recording_url: str, language: str) -> Dict[str, Any]:
        """
        Process voice recording from IVR system
        
        Args:
            phone_number: Caller's phone number
            recording_url: URL to recorded audio file
            language: Selected language from IVR menu
            
        Returns:
            Dict with report_id and processing status
        """
        pass
    
    def handle_whatsapp_message(self, phone_number: str, message_type: str, content: str, media_url: Optional[str] = None) -> Dict[str, Any]:
        """
        Process WhatsApp message (text, voice note, or image)
        
        Args:
            phone_number: Sender's WhatsApp number
            message_type: 'text', 'voice', or 'image'
            content: Message text or caption
            media_url: URL to media file if applicable
            
        Returns:
            Dict with report_id and confirmation message
        """
        pass
    
    def send_confirmation(self, phone_number: str, channel: str, report_id: str, language: str) -> bool:
        """
        Send confirmation message to user via their submission channel
        
        Args:
            phone_number: Recipient's phone number
            channel: 'sms' or 'whatsapp'
            report_id: Created report ID
            language: User's preferred language
            
        Returns:
            Success status
        """
        pass
    
    def handle_status_query(self, phone_number: str, report_id: str, channel: str, language: str) -> str:
        """
        Handle status query for a report
        
        Args:
            phone_number: Requester's phone number
            report_id: Report ID to query
            channel: 'sms' or 'whatsapp'
            language: User's preferred language
            
        Returns:
            Status message text
        """
        pass
    
    def get_or_create_user(self, phone_number: str, village_id: Optional[str] = None) -> str:
        """
        Get existing user by phone number or create new user
        
        Args:
            phone_number: User's phone number
            village_id: Optional village ID for new users
            
        Returns:
            User ID
        """
        pass
```

#### AIService

Handles AI-powered categorization and metadata extraction using Amazon Bedrock.

```python
from typing import List, Dict, Any
from dataclasses import dataclass

@dataclass
class CategorizationResult:
    category: str
    confidence: float
    reasoning: str

@dataclass
class ExtractedMetadata:
    infrastructure_types: List[str]
    quantities: List[Dict[str, Any]]  # [{"value": 5, "unit": "families", "context": "..."}]
    temporal_references: List[Dict[str, str]]  # [{"duration": "3 months", "context": "..."}]
    urgency_keywords: List[str]

@dataclass
class PriorityResult:
    score: int  # 1-100
    factors: List[Dict[str, Any]]  # [{"factor": "urgency", "contribution": 20, "explanation": "..."}]

class AIService:
    """Service for AI operations using Amazon Bedrock"""
    
    def categorize_report(self, description: str, language: str) -> CategorizationResult:
        """
        Categorize report using Amazon Bedrock (Claude/Titan)
        
        Args:
            description: Report description text
            language: Language code of the description
            
        Returns:
            CategorizationResult with category, confidence, and reasoning
        """
        pass
    
    def extract_metadata(self, description: str, language: str) -> ExtractedMetadata:
        """
        Extract structured metadata from description using Amazon Bedrock
        
        Args:
            description: Report description text
            language: Language code of the description
            
        Returns:
            ExtractedMetadata with infrastructure types, quantities, temporal refs
        """
        pass
    
    def calculate_priority_score(self, report: 'Report', nearby_reports: List['Report']) -> PriorityResult:
        """
        Calculate priority score based on urgency and clustering
        
        Args:
            report: The report to score
            nearby_reports: Reports within 100m with same category
            
        Returns:
            PriorityResult with score and contributing factors
        """
        pass
    
    def translate_text(self, text: str, source_lang: str, target_lang: str) -> str:
        """
        Translate text using Amazon Translate
        
        Args:
            text: Text to translate
            source_lang: Source language code
            target_lang: Target language code
            
        Returns:
            Translated text
        """
        pass
```

#### ValidationService

Validates reports against external data sources.

```python
from typing import List, Optional, Dict, Any
from dataclasses import dataclass

@dataclass
class BhuvanValidation:
    land_use_type: str
    confidence: float
    metadata: Dict[str, Any]

@dataclass
class OSMFeature:
    type: str
    name: str
    coordinates: 'GPSCoordinates'
    distance: float
    tags: Dict[str, str]

@dataclass
class ValidationResult:
    is_valid: bool
    contradictions: List[str]
    supporting_evidence: List[str]
    confidence: float

class ValidationService:
    """Service for validating reports against external data sources"""
    
    def validate_with_bhuvan(self, gps_coordinates: 'GPSCoordinates') -> BhuvanValidation:
        """Validate report against Bhuvan land use data"""
        pass
    
    def query_osm_features(self, gps_coordinates: 'GPSCoordinates', radius_meters: float, feature_type: str) -> List[OSMFeature]:
        """Query OpenStreetMap for nearby features"""
        pass
    
    def check_contradictions(self, report: 'Report', external_data: Dict[str, Any]) -> ValidationResult:
        """Check for contradictions between report and external data"""
        pass
    
    def update_validation_status(self, report_id: str, status: str, data: Any) -> None:
        """Update validation status"""
        pass
```

#### MapService

Handles map-related operations and clustering.

```python
from typing import List, Dict, Any
from dataclasses import dataclass

@dataclass
class ReportCluster:
    centroid: 'GPSCoordinates'
    report_ids: List[str]
    count: int
    dominant_category: str
    average_priority: float

@dataclass
class BoundingBox:
    southwest: 'GPSCoordinates'
    northeast: 'GPSCoordinates'

class MapService:
    """Service for map-related operations"""
    
    def get_village_boundaries(self, village_id: str) -> Dict[str, Any]:
        """Get village boundaries from Bhuvan as GeoJSON"""
        pass
    
    def cluster_reports(self, reports: List['Report'], threshold_meters: float) -> List[ReportCluster]:
        """Cluster reports by proximity using PostGIS"""
        pass
    
    def calculate_map_bounds(self, reports: List['Report']) -> BoundingBox:
        """Calculate optimal map bounds for reports"""
        pass
    
    def generate_map_tiles(self, bounds: BoundingBox, zoom: int) -> List[Dict[str, Any]]:
        """Generate map tiles with report markers"""
        pass
```

### Queue Service

Handles asynchronous processing of reports.

```python
from typing import List
from enum import Enum

class ProcessingTask(Enum):
    TRANSCRIPTION = 'transcription'
    CATEGORIZATION = 'categorization'
    METADATA_EXTRACTION = 'metadata_extraction'
    PRIORITY_SCORING = 'priority_scoring'
    VALIDATION = 'validation'

class QueueService:
    """Service for asynchronous report processing using Celery or AWS SQS"""
    
    def enqueue_report(self, report_id: str, tasks: List[ProcessingTask]) -> None:
        """Enqueue report for processing"""
        pass
    
    def process_transcription(self, report_id: str) -> None:
        """Process voice transcription task"""
        pass
    
    def process_categorization(self, report_id: str) -> None:
        """Process categorization task"""
        pass
    
    def process_validation(self, report_id: str) -> None:
        """Process validation task"""
        pass
    
    def retry_failed_tasks(self, max_retries: int) -> None:
        """Retry failed tasks"""
        pass
```

## Data Models

### Core Entities

#### Report

```python
from dataclasses import dataclass
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum

@dataclass
class GPSCoordinates:
    latitude: float  # -90 to 90
    longitude: float  # -180 to 180

class Category(Enum):
    WATER = 'water'
    ROADS = 'roads'
    AGRICULTURE = 'agriculture'
    HEALTH = 'health'
    EDUCATION = 'education'
    SANITATION = 'sanitation'
    ELECTRICITY = 'electricity'
    OTHER = 'other'

class ValidationStatus(Enum):
    PENDING = 'pending'
    VALIDATED = 'validated'
    FLAGGED = 'flagged'
    FAILED = 'failed'

@dataclass
class PriorityFactor:
    factor: str
    contribution: int  # Points added to score
    explanation: str

@dataclass
class ExternalData:
    bhuvan: Optional[Dict[str, Any]] = None
    osm: Optional[List[Dict[str, Any]]] = None
    contradictions: Optional[List[str]] = None

@dataclass
class Report:
    id: str  # UUID
    user_id: str  # Foreign key to users table
    village_id: str  # Foreign key to villages table
    
    # Content
    description: str  # Transcribed or typed text
    original_language: str  # ISO 639-1 code (e.g., 'hi', 'en', 'ta')
    translated_description: Optional[str] = None  # English translation if original is not English
    voice_recording_url: Optional[str] = None  # S3 URL if voice input
    
    # Location
    gps_coordinates: GPSCoordinates  # PostGIS POINT
    gps_accuracy: float  # Meters
    location_source: str = 'gps'  # 'gps' or 'village_centroid'
    
    # Classification
    category: Category
    category_confidence: float  # 0-1
    priority_score: int  # 1-100
    priority_factors: List[PriorityFactor]
    
    # Metadata
    extracted_metadata: Dict[str, Any]
    input_mode: str  # 'voice' or 'text'
    submission_channel: str = 'app'  # 'app', 'sms', 'ivr', 'whatsapp'
    
    # Validation
    validation_status: ValidationStatus
    external_data: Optional[ExternalData] = None
    
    # Timestamps
    created_at: datetime
    updated_at: datetime
    processed_at: Optional[datetime] = None
```

#### Village

```python
from dataclasses import dataclass
from typing import Optional, List
from datetime import datetime

@dataclass
class GeoJSONPolygon:
    type: str = 'Polygon'
    coordinates: List[List[List[float]]] = None  # [[[lon, lat], [lon, lat], ...]]

@dataclass
class Village:
    id: str  # UUID
    name: str
    state_code: str  # ISO 3166-2:IN code
    district_code: str
    block_code: str
    
    # Geospatial
    boundaries: GeoJSONPolygon  # PostGIS POLYGON
    centroid: GPSCoordinates  # PostGIS POINT
    
    # Metadata
    population: Optional[int] = None
    area: Optional[float] = None  # Square kilometers
    
    # Timestamps
    created_at: datetime
    updated_at: datetime
```

#### User

```python
from dataclasses import dataclass
from typing import Optional
from datetime import datetime
from enum import Enum

class UserRole(Enum):
    CITIZEN = 'citizen'
    LEADER = 'leader'
    ADMIN = 'admin'

@dataclass
class User:
    id: str  # UUID
    phone_number: str  # Primary identifier
    name: Optional[str]
    village_id: str  # Foreign key to villages table
    role: UserRole
    preferred_language: str  # ISO 639-1 code
    
    # Timestamps
    created_at: datetime
    updated_at: datetime
    last_login_at: Optional[datetime] = None
```

### Database Schema

```sql
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Villages table
CREATE TABLE villages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  state_code VARCHAR(10) NOT NULL,
  district_code VARCHAR(10) NOT NULL,
  block_code VARCHAR(10) NOT NULL,
  boundaries GEOMETRY(POLYGON, 4326) NOT NULL,
  centroid GEOMETRY(POINT, 4326) NOT NULL,
  population INTEGER,
  area DECIMAL(10, 2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create spatial index on village boundaries
CREATE INDEX idx_villages_boundaries ON villages USING GIST(boundaries);
CREATE INDEX idx_villages_centroid ON villages USING GIST(centroid);

-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number VARCHAR(15) UNIQUE NOT NULL,
  name VARCHAR(255),
  village_id UUID REFERENCES villages(id),
  role VARCHAR(20) NOT NULL CHECK (role IN ('citizen', 'leader', 'admin')),
  preferred_language VARCHAR(5) NOT NULL DEFAULT 'hi',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_users_village_id ON users(village_id);
CREATE INDEX idx_users_phone_number ON users(phone_number);

-- Reports table
CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) NOT NULL,
  village_id UUID REFERENCES villages(id) NOT NULL,
  
  -- Content
  description TEXT NOT NULL,
  original_language VARCHAR(5) NOT NULL,
  translated_description TEXT,
  voice_recording_url TEXT,
  
  -- Location
  gps_coordinates GEOMETRY(POINT, 4326) NOT NULL,
  gps_accuracy DECIMAL(6, 2) NOT NULL,
  location_source VARCHAR(20) NOT NULL DEFAULT 'gps' CHECK (location_source IN ('gps', 'village_centroid')),
  
  -- Classification
  category VARCHAR(20) NOT NULL CHECK (category IN ('water', 'roads', 'agriculture', 'health', 'education', 'sanitation', 'electricity', 'other')),
  category_confidence DECIMAL(3, 2),
  priority_score INTEGER CHECK (priority_score BETWEEN 1 AND 100),
  priority_factors JSONB,
  
  -- Metadata
  extracted_metadata JSONB,
  input_mode VARCHAR(10) NOT NULL CHECK (input_mode IN ('voice', 'text')),
  submission_channel VARCHAR(20) NOT NULL DEFAULT 'app' CHECK (submission_channel IN ('app', 'sms', 'ivr', 'whatsapp')),
  
  -- Validation
  validation_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (validation_status IN ('pending', 'validated', 'flagged', 'failed')),
  external_data JSONB,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE
);

-- Create spatial index on GPS coordinates
CREATE INDEX idx_reports_gps_coordinates ON reports USING GIST(gps_coordinates);

-- Create indexes for common queries
CREATE INDEX idx_reports_village_id ON reports(village_id);
CREATE INDEX idx_reports_user_id ON reports(user_id);
CREATE INDEX idx_reports_category ON reports(category);
CREATE INDEX idx_reports_priority_score ON reports(priority_score DESC);
CREATE INDEX idx_reports_created_at ON reports(created_at DESC);
CREATE INDEX idx_reports_validation_status ON reports(validation_status);

-- Composite index for village + category queries
CREATE INDEX idx_reports_village_category ON reports(village_id, category);

-- Processing queue table
CREATE TABLE processing_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID REFERENCES reports(id) NOT NULL,
  task_type VARCHAR(50) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  retry_count INTEGER DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_processing_queue_status ON processing_queue(status);
CREATE INDEX idx_processing_queue_report_id ON processing_queue(report_id);
```

### API Endpoints

#### Report Endpoints

```
POST   /api/reports
GET    /api/reports/:id
GET    /api/reports
GET    /api/reports/nearby
GET    /api/reports/village/:villageId
PATCH  /api/reports/:id
```

**POST /api/reports**

Create a new report.

Request:
```json
{
  "userId": "uuid",
  "villageId": "uuid",
  "description": "string (optional if voice)",
  "voiceRecordingData": "base64 (optional if text)",
  "gpsCoordinates": {
    "latitude": 28.6139,
    "longitude": 77.2090
  },
  "gpsAccuracy": 15.5,
  "language": "hi",
  "inputMode": "voice" | "text"
}
```

Response:
```json
{
  "reportId": "uuid",
  "status": "processing",
  "message": "Report submitted successfully",
  "estimatedProcessingTime": 30
}
```

**GET /api/reports/:id**

Get report by ID.

Response:
```json
{
  "id": "uuid",
  "description": "string",
  "category": "water",
  "categoryConfidence": 0.92,
  "priorityScore": 75,
  "gpsCoordinates": {
    "latitude": 28.6139,
    "longitude": 77.2090
  },
  "validationStatus": "validated",
  "createdAt": "2024-01-15T10:30:00Z"
}
```

**GET /api/reports/nearby**

Get reports near a point.

Query Parameters:
- `lat`: Latitude
- `lon`: Longitude
- `radius`: Radius in meters (default: 1000)
- `category`: Optional category filter

Response:
```json
{
  "reports": [
    {
      "id": "uuid",
      "description": "string",
      "category": "water",
      "priorityScore": 75,
      "distance": 250.5,
      "gpsCoordinates": {
        "latitude": 28.6139,
        "longitude": 77.2090
      }
    }
  ],
  "count": 15
}
```

#### Map Endpoints

```
GET    /api/map/village/:villageId/boundaries
GET    /api/map/village/:villageId/reports
GET    /api/map/clusters
```

**GET /api/map/village/:villageId/reports**

Get all reports for a village with optional clustering.

Query Parameters:
- `cluster`: Boolean (default: false)
- `clusterThreshold`: Meters (default: 50)
- `category`: Optional category filter

Response:
```json
{
  "reports": [
    {
      "id": "uuid",
      "gpsCoordinates": {
        "latitude": 28.6139,
        "longitude": 77.2090
      },
      "category": "water",
      "priorityScore": 75
    }
  ],
  "clusters": [
    {
      "centroid": {
        "latitude": 28.6140,
        "longitude": 77.2091
      },
      "count": 5,
      "reportIds": ["uuid1", "uuid2", "uuid3", "uuid4", "uuid5"],
      "dominantCategory": "water",
      "averagePriority": 68
    }
  ]
}
```

#### Alternative Channel Endpoints (Webhooks)

```
POST   /api/webhooks/sms
POST   /api/webhooks/ivr
POST   /api/webhooks/whatsapp
```

**POST /api/webhooks/sms**

Receive incoming SMS from Twilio.

Request (from Twilio):
```
From: +919876543210
To: +911234567890
Body: पानी की समस्या है गांव में
```

Response (TwiML):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Message>आपकी रिपोर्ट प्राप्त हो गई है। रिपोर्ट ID: ABC123</Message>
</Response>
```

**POST /api/webhooks/ivr**

Receive IVR recording from Twilio.

Request (from Twilio):
```
From: +919876543210
RecordingUrl: https://api.twilio.com/recordings/RE123
RecordingDuration: 45
Language: hi
```

Response (TwiML):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say language="hi-IN">आपकी रिपोर्ट प्राप्त हो गई है। धन्यवाद।</Say>
  <Hangup/>
</Response>
```

**POST /api/webhooks/whatsapp**

Receive WhatsApp message from Twilio/WhatsApp Business API.

Request (from Twilio):
```json
{
  "From": "whatsapp:+919876543210",
  "To": "whatsapp:+911234567890",
  "Body": "सड़क टूटी हुई है",
  "MessageType": "text",
  "MediaUrl0": null
}
```

Response:
```json
{
  "status": "received",
  "reportId": "uuid",
  "message": "आपकी रिपोर्ट प्राप्त हो गई है। रिपोर्ट ID: ABC123"
}
```


## Error Handling

### Error Categories

#### Client-Side Errors (4xx)

**400 Bad Request**
- Invalid GPS coordinates (out of range)
- Text description too short (<10 characters) or too long (>500 characters)
- Missing required fields
- Invalid language code

**401 Unauthorized**
- Missing or invalid authentication token
- Expired session

**403 Forbidden**
- User attempting to access reports from different village (for citizens)
- Insufficient permissions for operation

**404 Not Found**
- Report ID does not exist
- Village ID does not exist
- User ID does not exist

**429 Too Many Requests**
- Rate limit exceeded (max 10 reports per user per hour)
- Too many API calls from single IP

#### Server-Side Errors (5xx)

**500 Internal Server Error**
- Unexpected database errors
- Unhandled exceptions in business logic

**502 Bad Gateway**
- External API failures (Google Speech-to-Text, OpenAI, Bhuvan)
- Timeout connecting to external services

**503 Service Unavailable**
- Database connection pool exhausted
- Queue service unavailable
- Maintenance mode

### Error Response Format

All API errors follow a consistent format:

```json
{
  "error": {
    "code": "INVALID_GPS_COORDINATES",
    "message": "GPS coordinates are out of valid range",
    "details": {
      "latitude": 91.5,
      "validRange": "[-90, 90]"
    },
    "timestamp": "2024-01-15T10:30:00Z",
    "requestId": "uuid"
  }
}
```

### Retry and Fallback Strategies

#### Voice Transcription Failures

1. **Low Confidence (<0.7)**: Return transcription to user for confirmation/correction
2. **API Timeout**: Retry up to 3 times with exponential backoff (2s, 4s, 8s)
3. **API Unavailable**: Queue for later processing, allow user to proceed with manual text input
4. **Persistent Failure**: Mark report as "pending transcription" and notify user via SMS

#### AI Categorization Failures

1. **Low Confidence (<0.6)**: Assign to "other" category and flag for manual review
2. **API Timeout**: Retry up to 3 times with exponential backoff
3. **API Unavailable**: Use rule-based keyword matching as fallback
4. **Persistent Failure**: Assign to "other" category with priority score based on keywords only

#### External Validation Failures

1. **Bhuvan API Unavailable**: Mark validation status as "pending" and retry after 1 hour
2. **OSM API Unavailable**: Skip OSM validation, proceed with Bhuvan data only
3. **Both APIs Unavailable**: Mark validation status as "failed" but allow report to be visible
4. **Rate Limit Exceeded**: Queue validation tasks and process during off-peak hours

#### GPS Capture Failures

1. **Low Accuracy (>50m)**: Prompt user to move to open area and retry
2. **No GPS Signal**: Allow user to manually select location on map
3. **Permission Denied**: Show educational prompt explaining why location is needed
4. **Persistent Failure**: Allow report submission with approximate location (village centroid)

### Offline Handling

#### Mobile App Offline Queue

When network connectivity is unavailable:

1. **Report Creation**: Store report locally in IndexedDB/AsyncStorage
2. **Queue Management**: Maintain ordered queue of pending reports
3. **Sync on Reconnect**: Automatically sync queued reports when connectivity restored
4. **Conflict Resolution**: Use "last write wins" strategy with client-side timestamps
5. **User Feedback**: Show sync status indicator and pending report count

#### Offline Data Structure

```dart
enum SyncStatus { pending, syncing, synced, failed }

class OfflineReport {
  final String localId; // Client-generated UUID
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final int syncAttempts;
  final String? lastSyncError;
  
  OfflineReport({
    required this.localId,
    required this.data,
    required this.createdAt,
    required this.syncStatus,
    this.syncAttempts = 0,
    this.lastSyncError,
  });
}
```

### Validation Error Messages

User-facing error messages should be:
- Available in user's preferred language
- Clear and actionable
- Non-technical

Examples:

```python
error_messages = {
    'INVALID_GPS_COORDINATES': {
        'en': 'Unable to capture your location. Please move to an open area and try again.',
        'hi': 'आपका स्थान कैप्चर नहीं हो सका। कृपया खुली जगह पर जाएं और पुनः प्रयास करें।'
    },
    'TEXT_TOO_SHORT': {
        'en': 'Please provide more details about the issue (at least 10 characters).',
        'hi': 'कृपया समस्या के बारे में अधिक विवरण दें (कम से कम 10 अक्षर)।'
    },
    'VOICE_TRANSCRIPTION_FAILED': {
        'en': 'Could not understand the recording. Please try again or use text input.',
        'hi': 'रिकॉर्डिंग समझ नहीं आई। कृपया पुनः प्रयास करें या टेक्स्ट इनपुट का उपयोग करें।'
    }
}
```

## Testing Strategy

### Testing Approach

The PrajaShakti platform requires a dual testing approach combining unit tests for specific scenarios and property-based tests for universal correctness properties.

#### Unit Testing

Unit tests focus on:
- Specific examples demonstrating correct behavior
- Edge cases (empty inputs, boundary values, special characters)
- Error conditions and exception handling
- Integration points between components
- External API mocking and failure scenarios

**Testing Frameworks**: 
- Backend: pytest with pytest-django for Django backend
- Mobile: Flutter test framework with mockito for mocking

**Coverage Goals**:
- Minimum 80% code coverage for business logic
- 100% coverage for critical paths (report creation, GPS capture, categorization)

#### Property-Based Testing

Property-based tests validate universal properties across randomized inputs. Each correctness property from the design must be implemented as a property-based test.

**Testing Frameworks**: 
- Backend: Hypothesis (Python property-based testing library)
- Mobile: Flutter's built-in test framework with custom generators

**Configuration**:
- Minimum 100 iterations per property test (due to randomization)
- Each test must reference its design document property
- Tag format: `Feature: gramdisha-platform, Property {number}: {property_text}`

**Example Property Test Structure (Python/Hypothesis)**:

```python
from hypothesis import given, strategies as st
import pytest

@given(
    lat=st.floats(min_value=-90, max_value=90),
    lon=st.floats(min_value=-180, max_value=180)
)
def test_gps_coordinate_validation(lat, lon):
    """
    Feature: gramdisha-platform, Property 1: GPS coordinate validation
    For any valid GPS coordinates, the system should accept them
    """
    coords = GPSCoordinates(latitude=lat, longitude=lon)
    assert is_valid_gps_coordinates(coords) is True
```

### Test Data Generation

#### Generators for Property Tests (Python/Hypothesis)

```python
from hypothesis import strategies as st
from hypothesis.extra.pytz import timezones

# GPS coordinate generator
gps_coordinate_gen = st.builds(
    GPSCoordinates,
    latitude=st.floats(min_value=-90, max_value=90, allow_nan=False, allow_infinity=False),
    longitude=st.floats(min_value=-180, max_value=180, allow_nan=False, allow_infinity=False)
)

# Report description generator (Hindi/English mix)
report_description_gen = st.one_of(
    st.text(min_size=10, max_size=500, alphabet=st.characters(blacklist_categories=('Cs',))),  # English
    st.sampled_from([
        'पानी की समस्या है गांव में',
        'सड़क टूटी हुई है और मरम्मत की जरूरत है',
        'बिजली नहीं आती है तीन दिन से',
        'स्कूल में शिक्षक नहीं हैं',
        'हैंडपंप खराब है पानी नहीं आ रहा'
    ])  # Hindi examples
)

# Category generator
category_gen = st.sampled_from([
    'water', 'roads', 'agriculture', 'health', 
    'education', 'sanitation', 'electricity', 'other'
])

# Language generator
language_gen = st.sampled_from(['en', 'hi', 'ta', 'te', 'bn'])

# Input mode generator
input_mode_gen = st.sampled_from(['voice', 'text'])

# Submission channel generator
submission_channel_gen = st.sampled_from(['app', 'sms', 'ivr', 'whatsapp'])

# Report generator
report_gen = st.builds(
    CreateReportDTO,
    user_id=st.uuids().map(str),
    village_id=st.uuids().map(str),
    description=report_description_gen,
    gps_coordinates=gps_coordinate_gen,
    gps_accuracy=st.floats(min_value=0, max_value=100, allow_nan=False),
    language=language_gen,
    input_mode=input_mode_gen,
    submission_channel=submission_channel_gen
)

# Priority score generator
priority_score_gen = st.integers(min_value=1, max_value=100)

# Confidence score generator
confidence_score_gen = st.floats(min_value=0.0, max_value=1.0, allow_nan=False)
```

### Integration Testing

Integration tests verify:
- End-to-end report submission flow
- Database queries with PostGIS spatial functions
- External API integrations (with test/sandbox endpoints)
- Queue processing and async workflows
- Map clustering algorithms

### Performance Testing

Performance benchmarks:
- Report creation API: <500ms response time (p95)
- Geospatial queries: <1s for 10,000 reports (p95)
- Map tile generation: <2s for viewport update (p95)
- Voice transcription: <10s for 60-second audio (p95)

### Security Testing

Security test scenarios:
- SQL injection attempts in text inputs
- XSS attempts in report descriptions
- Authentication bypass attempts
- Rate limiting enforcement
- GPS coordinate spoofing detection


## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: Low confidence transcription triggers re-recording request

*For any* voice transcription result with confidence score below 0.7, the system should request re-recording from the user.

**Validates: Requirements 1.2**

### Property 2: Voice reports include language metadata

*For any* voice report submitted, the system should extract and store the primary language with the report.

**Validates: Requirements 1.3**

### Property 3: Confirmed transcription creates report

*For any* transcribed text that is confirmed by the user, the system should create a report with that exact text as the description.

**Validates: Requirements 1.5**

### Property 4: Multi-language text acceptance

*For any* text input in Hindi, English, or supported regional languages (Tamil, Telugu, Bengali), the system should accept the input for report creation.

**Validates: Requirements 2.1**

### Property 5: Short text rejection

*For any* text input with fewer than 10 characters, the system should reject the submission and return a validation error.

**Validates: Requirements 2.2**

### Property 6: Long text truncation

*For any* text input exceeding 500 characters, the system should truncate the description to exactly 500 characters and notify the user.

**Validates: Requirements 2.3**

### Property 7: Poor GPS accuracy triggers retry prompt

*For any* GPS reading with accuracy exceeding 50 meters, the system should prompt the user to move to an open area and retry.

**Validates: Requirements 3.3**

### Property 8: Report data persistence round-trip

*For any* report created with description, GPS coordinates, category, priority score, and metadata, retrieving the report by ID should return all the same data unchanged.

**Validates: Requirements 2.4, 3.4, 4.4, 5.4, 7.4, 11.4**

### Property 9: Single valid category assignment

*For any* report description, the AI categorizer should assign exactly one category from the predefined list (water, roads, agriculture, health, education, sanitation, electricity, other).

**Validates: Requirements 4.1**

### Property 10: Confidence score bounds

*For any* categorization or transcription result, the confidence score should be between 0 and 1 (inclusive).

**Validates: Requirements 1.2, 4.2**

### Property 11: Low confidence categorization handling

*For any* report with categorization confidence below 0.6, the system should assign it to the "other" category and mark it for manual review.

**Validates: Requirements 4.3**

### Property 12: Language-agnostic categorization

*For any* two report descriptions with the same semantic meaning in different supported languages, the system should assign them to the same category.

**Validates: Requirements 4.5**

### Property 13: Priority score bounds

*For any* report, the calculated priority score should be between 1 and 100 (inclusive).

**Validates: Requirements 5.1**

### Property 14: Urgency keyword priority boost

*For any* report description, adding urgency keywords (emergency, urgent, critical, immediate) should increase the priority score by at least 20 points compared to the same description without those keywords.

**Validates: Requirements 5.2**

### Property 15: Clustering priority boost

*For any* set of reports with GPS coordinates within 100 meters of each other and the same category, each report's priority score should be at least 10 points higher than if it were isolated.

**Validates: Requirements 5.3**

### Property 16: Priority score explanation exists

*For any* report with a calculated priority score, the system should provide an explanation containing the scoring factors and their contributions.

**Validates: Requirements 5.5**

### Property 17: Map markers match reports

*For any* set of reports in a village, the village map should display exactly one marker for each report at the correct GPS coordinates (before clustering).

**Validates: Requirements 6.2**

### Property 18: Report marker popup completeness

*For any* report marker clicked on the map, the popup should display the report's description, category, and priority score.

**Validates: Requirements 6.3**

### Property 19: Proximity-based marker clustering

*For any* set of reports with GPS coordinates within 50 meters of each other, the map should cluster them into a single marker displaying the count.

**Validates: Requirements 6.4**

### Property 20: Map centers on village

*For any* village, when the village map loads, the view should be centered on that village's centroid coordinates.

**Validates: Requirements 6.6**

### Property 21: Report metadata completeness

*For any* report retrieved from the database, it should include all associated metadata: description, category, priority score, GPS coordinates, timestamp, language, validation status, and extracted metadata.

**Validates: Requirements 7.4, 9.3**

### Property 22: Unique report identifiers

*For any* two reports created at different times or by different users, they should have unique identifiers.

**Validates: Requirements 7.5**

### Property 23: Report creation timestamp exists

*For any* report created, it should have a creation timestamp that is set to the time of creation (within reasonable clock skew).

**Validates: Requirements 7.5**

### Property 24: Successful submission returns unique ID

*For any* report submitted successfully, the system should return a confirmation with a unique report ID.

**Validates: Requirements 8.3**

### Property 25: User report list completeness

*For any* user viewing their submitted reports, the list should display all their reports with category, timestamp, and status for each.

**Validates: Requirements 8.4**

### Property 26: Offline report queue and sync

*For any* report created while the mobile app is offline, the report should be stored locally and automatically synced to the server when connectivity is restored.

**Validates: Requirements 8.5**

### Property 27: Leader village filter

*For any* village leader viewing the dashboard, only reports from their assigned village should be displayed.

**Validates: Requirements 9.1**

### Property 28: Priority-based report sorting

*For any* set of reports displayed on the leader dashboard, they should be sorted by priority score in descending order (highest priority first).

**Validates: Requirements 9.2**

### Property 29: Category grouping with accurate counts

*For any* set of reports displayed on the leader dashboard, when grouped by category, the count for each category should equal the actual number of reports in that category.

**Validates: Requirements 9.5**

### Property 30: Successful validation updates status

*For any* report where external validation (Bhuvan/OSM) succeeds, the validation status should be updated to "validated" and the external data should be stored with the report.

**Validates: Requirements 10.2**

### Property 31: Failed validation marks pending

*For any* report where external validation fails or the API is unavailable, the validation status should be marked as "pending".

**Validates: Requirements 10.3**

### Property 32: Contradictory data flags report

*For any* report where external data contradicts the report content (e.g., water body already exists at reported location), the report should be flagged for manual review.

**Validates: Requirements 10.5**

### Property 33: Infrastructure type extraction

*For any* report description containing infrastructure keywords (hand pump, road, school, hospital, etc.), the system should extract and store those infrastructure types in the metadata.

**Validates: Requirements 11.1**

### Property 34: Temporal reference extraction

*For any* report description containing temporal references (for 3 months, since last year, etc.), the system should extract and store the duration in the metadata.

**Validates: Requirements 11.2**

### Property 35: Quantity extraction

*For any* report description containing numerical quantities (5 families, 200 meters, etc.), the system should extract and store the numerical values with their units in the metadata.

**Validates: Requirements 11.3**

### Property 36: Low extraction confidence preserves raw description

*For any* report where metadata extraction confidence is low, the system should store the raw description without structured metadata, ensuring no data loss.

**Validates: Requirements 11.5**

### Property 37: Device language detection and UI localization

*For any* supported device language (Hindi, English, Tamil, Telugu, Bengali), when the mobile app opens, the UI should be displayed in that language.

**Validates: Requirements 12.1**

### Property 38: Original language preservation with translation

*For any* report submitted in a non-English language, the system should store both the original language text and the English translation after processing.

**Validates: Requirements 12.3, 12.4, 12.5**

### Property 39: SMS submission creates report

*For any* SMS message sent to the platform number with text content of at least 10 characters, the system should create a report with the SMS text as the description and the sender's phone number linked to a user account.

**Validates: Requirements 13.1**

### Property 40: IVR voice recording processing

*For any* voice recording captured through the IVR system, the system should process it identically to app-based voice reports (transcription, categorization, validation).

**Validates: Requirements 13.3**

### Property 41: WhatsApp multi-format acceptance

*For any* WhatsApp message (text, voice note, or image) sent to the platform number, the system should accept it as a valid report submission.

**Validates: Requirements 13.4**

### Property 42: Phone number user identification

*For any* report submitted via SMS, IVR, or WhatsApp, the system should extract the sender's phone number and either link to an existing user account or create a new one.

**Validates: Requirements 13.5**

### Property 43: Alternative channel confirmation

*For any* report successfully received via SMS or WhatsApp, the system should send a confirmation message with the report ID back to the sender through the same channel.

**Validates: Requirements 13.7**

### Property 44: Status query response

*For any* valid status query message ("STATUS <report_id>") sent via SMS or WhatsApp, the system should respond with the current status of that report.

**Validates: Requirements 13.8**

### Property 45: Village centroid fallback location

*For any* report submitted via alternative channels (SMS, IVR, WhatsApp) without GPS data, the system should use the user's registered village centroid as the approximate location.

**Validates: Requirements 13.6**

