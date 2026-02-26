"""
End-to-end test for the voice transcription pipeline.
No Celery worker needed — runs tasks synchronously.

Usage:
    python manage.py test_voice_pipeline
    python manage.py test_voice_pipeline --text "nala band hai, pani sadak pe aa raha hai"
    python manage.py test_voice_pipeline --s3-key voice/existing-file.wav  # use existing S3 file
    python manage.py test_voice_pipeline --audio-file /path/to/local.wav   # upload local file
"""
import os
import time
import json
import tempfile
import subprocess
import boto3

from django.core.management.base import BaseCommand
from django.conf import settings
from django.contrib.gis.geos import Point


class Command(BaseCommand):
    help = 'Test end-to-end voice transcription pipeline without Celery worker'

    def add_arguments(self, parser):
        parser.add_argument(
            '--text', default='Gaon mein pani ki bahut kami hai. Handpump kharab ho gaya hai, borewell ka pani nahi aa raha. Mahilaaon ko door se pani laana padta hai.',
            help='Text to speak (used to create test audio via macOS say command)'
        )
        parser.add_argument(
            '--voice', default='Rishi',
            help='macOS say voice (Rishi is Indian-accented English; for real Hindi use --audio-file)'
        )
        parser.add_argument(
            '--language', default='hi-IN',
            help='Transcribe language code (hi-IN, en-IN, or-IN, etc.)'
        )
        parser.add_argument(
            '--s3-key', default=None,
            help='Use an existing S3 key in prajashakti-audio bucket instead of creating new audio'
        )
        parser.add_argument(
            '--audio-file', default=None,
            help='Path to a local audio file to upload and transcribe'
        )

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('\n=== PrajaShakti Voice Pipeline Test ===\n'))

        # Step 1: Get or create audio file on S3
        if options['s3_key']:
            s3_key = options['s3_key']
            lang = options['language']
            self.stdout.write(f'Using existing S3 key: {s3_key}')
        elif options['audio_file']:
            s3_key, lang = self._upload_local_file(options['audio_file'])
        else:
            s3_key, lang = self._create_and_upload_audio(options['text'], options['voice'], options['language'])

        # Step 2: Create a report to attach transcription to
        report = self._create_test_report(s3_key)
        self.stdout.write(f'\nStep 2: Created report #{report.id} (status: pending transcription)')

        # Step 3: Run AWS Transcribe directly (synchronous, no Celery)
        self.stdout.write(f'\nStep 3: Starting AWS Transcribe job (language: {lang})...')
        job_name = self._run_transcribe(report, s3_key, lang)
        if not job_name:
            return

        # Step 4: Poll until done
        text = self._poll_transcription(job_name)
        if not text:
            return

        self.stdout.write(f'\n  Transcript: "{text}"')

        # Step 5: Run Bedrock categorization
        self.stdout.write('\nStep 5: Categorizing with Bedrock Claude...')
        result = self._categorize(text)
        if result:
            self.stdout.write(f'  Category:    {result.get("category", "?")}')
            self.stdout.write(f'  Sub-category: {result.get("sub_category", "?")}')
            self.stdout.write(f'  Urgency:     {result.get("urgency", "?")}')
            self.stdout.write(f'  Confidence:  {result.get("confidence", "?")}')
            self.stdout.write(f'  Summary:     {result.get("english_summary", "?")}')

            # Update report
            report.category = result.get('category', 'other')
            report.sub_category = result.get('sub_category', '')
            report.urgency = result.get('urgency', 'medium')
            report.ai_confidence = result.get('confidence', 0.5)
            report.description_text = result.get('english_summary', text)
            report.description_hindi = text
            report.save()

        self.stdout.write(self.style.SUCCESS(
            f'\n=== Pipeline complete! Report #{report.id} transcribed and categorized. ==='
        ))
        self.stdout.write(f'View at: http://127.0.0.1:8000/admin/community/report/{report.id}/change/')

    def _create_and_upload_audio(self, text, voice, language):
        """Create audio using macOS say command, convert to WAV, upload to S3."""
        self.stdout.write(f'Step 1: Creating audio via macOS say...')
        self.stdout.write(f'  Text: "{text[:80]}..."')

        s3 = boto3.client('s3', region_name=settings.AWS_REGION)
        from uuid import uuid4

        with tempfile.TemporaryDirectory() as tmpdir:
            aiff_path = os.path.join(tmpdir, 'voice.aiff')
            wav_path = os.path.join(tmpdir, 'voice.wav')

            # Create AIFF with macOS say
            cmd = ['say', '-o', aiff_path]
            if voice:
                cmd += ['-v', voice]
            cmd.append(text)

            result = subprocess.run(cmd, capture_output=True)
            if result.returncode != 0:
                # Try without voice option
                result = subprocess.run(['say', '-o', aiff_path, text], capture_output=True)

            if not os.path.exists(aiff_path):
                self.stdout.write(self.style.ERROR('  Failed to create audio with say command'))
                return None, language

            # Convert AIFF to WAV using afconvert (built into macOS)
            subprocess.run(
                ['afconvert', '-f', 'WAVE', '-d', 'LEI16', aiff_path, wav_path],
                check=True, capture_output=True
            )

            file_size = os.path.getsize(wav_path)
            self.stdout.write(f'  Created WAV file: {file_size/1024:.1f} KB')

            # Upload to S3
            s3_key = f'voice/test/{uuid4().hex}.wav'
            s3.upload_file(wav_path, settings.AWS_S3_AUDIO_BUCKET, s3_key,
                          ExtraArgs={'ContentType': 'audio/wav'})
            self.stdout.write(f'  Uploaded to s3://{settings.AWS_S3_AUDIO_BUCKET}/{s3_key}')

        return s3_key, language

    def _upload_local_file(self, file_path):
        """Upload a local audio file to S3."""
        from uuid import uuid4
        s3 = boto3.client('s3', region_name=settings.AWS_REGION)

        ext = os.path.splitext(file_path)[1].lower()
        fmt_map = {'.wav': 'audio/wav', '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg',
                   '.m4a': 'audio/mp4', '.flac': 'audio/flac'}
        content_type = fmt_map.get(ext, 'audio/wav')

        s3_key = f'voice/test/{uuid4().hex}{ext}'
        s3.upload_file(file_path, settings.AWS_S3_AUDIO_BUCKET, s3_key,
                      ExtraArgs={'ContentType': content_type})

        self.stdout.write(f'Step 1: Uploaded {file_path} → s3://{settings.AWS_S3_AUDIO_BUCKET}/{s3_key}')
        return s3_key, 'hi-IN'

    def _create_test_report(self, s3_key):
        from apps.community.models import Report
        from apps.geo_intelligence.models import Village

        village = Village.objects.first()
        if not village:
            self.stdout.write(self.style.ERROR('No village found. Run: python manage.py create_demo'))
            return None

        return Report.objects.create(
            village=village,
            description_text='[Voice note - transcription pending]',
            audio_s3_key=s3_key,
            status='reported',
            ward=3,
            location=Point(83.1607, 20.7382, srid=4326),
        )

    def _run_transcribe(self, report, s3_key, language):
        from uuid import uuid4

        client = boto3.client('transcribe', region_name=settings.AWS_REGION)
        job_name = f'prajashakti-test-{report.id}-{uuid4().hex[:8]}'

        # Detect format from key extension
        ext = s3_key.rsplit('.', 1)[-1].lower() if '.' in s3_key else 'wav'
        media_format = ext if ext in ['wav', 'mp3', 'ogg', 'flac', 'mp4', 'm4a'] else 'wav'

        try:
            client.start_transcription_job(
                TranscriptionJobName=job_name,
                Media={'MediaFileUri': f's3://{settings.AWS_S3_AUDIO_BUCKET}/{s3_key}'},
                MediaFormat=media_format,
                LanguageCode=language,
            )
            report.transcribe_job_id = job_name
            report.save(update_fields=['transcribe_job_id'])
            self.stdout.write(f'  Job: {job_name}')
            return job_name
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'  Transcribe failed: {e}'))
            return None

    def _poll_transcription(self, job_name, max_wait=120):
        """Poll AWS Transcribe until done (max_wait seconds)."""
        import requests as req
        client = boto3.client('transcribe', region_name=settings.AWS_REGION)

        self.stdout.write(f'\nStep 4: Polling transcription (up to {max_wait}s)...')
        start = time.time()

        while time.time() - start < max_wait:
            job = client.get_transcription_job(TranscriptionJobName=job_name)
            status = job['TranscriptionJob']['TranscriptionJobStatus']
            elapsed = int(time.time() - start)
            self.stdout.write(f'  [{elapsed}s] Status: {status}')

            if status == 'COMPLETED':
                uri = job['TranscriptionJob']['Transcript']['TranscriptFileUri']
                resp = req.get(uri)
                data = resp.json()
                return data['results']['transcripts'][0]['transcript']

            elif status == 'FAILED':
                reason = job['TranscriptionJob'].get('FailureReason', 'Unknown')
                self.stdout.write(self.style.ERROR(f'  Transcription FAILED: {reason}'))
                return None

            time.sleep(10)

        self.stdout.write(self.style.ERROR(f'  Timed out after {max_wait}s'))
        return None

    def _categorize(self, text):
        """Call Bedrock Claude to categorize the transcribed text."""
        from apps.ai_engine.bedrock_client import call_bedrock_claude

        prompt = f"""You are analyzing rural Indian citizen reports. Categorize this report.

Report text: "{text}"

Respond ONLY with valid JSON matching this schema:
{{
  "category": "<water|road|health|education|electricity|sanitation|other>",
  "sub_category": "<specific issue in 3-5 words>",
  "urgency": "<low|medium|high|critical>",
  "confidence": <0.0-1.0>,
  "english_summary": "<1 sentence English summary>"
}}"""

        try:
            response = call_bedrock_claude(prompt, max_tokens=300)
            # Strip any markdown if Claude wrapped it
            if '```' in response:
                response = response.split('```')[1]
                if response.startswith('json'):
                    response = response[4:]
            return json.loads(response.strip())
        except Exception as e:
            self.stdout.write(self.style.WARNING(f'  Categorization error: {e}'))
            return None
