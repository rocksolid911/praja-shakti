from django.contrib.gis.db import models
from pgvector.django import VectorField


CATEGORIES = [
    ('water', 'Water Access'),
    ('road', 'Road'),
    ('health', 'Health'),
    ('education', 'Education'),
    ('electricity', 'Electricity'),
    ('sanitation', 'Sanitation'),
    ('other', 'Other'),
]

URGENCY = [
    ('low', 'Low'),
    ('medium', 'Medium'),
    ('high', 'High'),
    ('critical', 'Critical'),
]


class Report(models.Model):
    STATUS = [
        ('reported', 'Reported'),
        ('adopted', 'Adopted'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('delayed', 'Delayed'),
    ]
    reporter = models.ForeignKey(
        'auth_service.User', on_delete=models.SET_NULL,
        null=True, related_name='reports',
    )
    village = models.ForeignKey(
        'geo_intelligence.Village', on_delete=models.CASCADE,
        related_name='reports',
    )
    category = models.CharField(max_length=20, choices=CATEGORIES, blank=True)
    sub_category = models.CharField(max_length=100, blank=True)
    description_text = models.TextField()
    description_hindi = models.TextField(blank=True)
    audio_s3_key = models.CharField(max_length=500, blank=True)
    photo_s3_key = models.CharField(max_length=500, blank=True)
    location = models.PointField(srid=4326, null=True, blank=True)
    ward = models.IntegerField(null=True, blank=True)
    urgency = models.CharField(max_length=10, choices=URGENCY, blank=True)
    status = models.CharField(max_length=20, choices=STATUS, default='reported')
    vote_count = models.IntegerField(default=0)
    cluster = models.ForeignKey(
        'ReportCluster', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='reports',
    )
    ai_confidence = models.FloatField(null=True, blank=True)
    embedding = VectorField(dimensions=1024, null=True, blank=True)
    is_gram_sabha = models.BooleanField(default=False)
    transcribe_job_id = models.CharField(max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.category}] {self.description_text[:60]}"


class Vote(models.Model):
    report = models.ForeignKey(Report, on_delete=models.CASCADE, related_name='votes')
    voter = models.ForeignKey('auth_service.User', on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['report', 'voter']

    def __str__(self):
        return f"Vote by {self.voter} on Report #{self.report_id}"


class ReportCluster(models.Model):
    village = models.ForeignKey(
        'geo_intelligence.Village', on_delete=models.CASCADE,
        related_name='clusters',
    )
    category = models.CharField(max_length=20, choices=CATEGORIES)
    centroid = models.PointField(srid=4326)
    radius_km = models.FloatField()
    report_count = models.IntegerField(default=0)
    ward_count = models.IntegerField(default=0)
    upvote_count = models.IntegerField(default=0)
    estimated_households = models.IntegerField(null=True, blank=True)
    community_priority_score = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-community_priority_score']

    def __str__(self):
        return f"Cluster: {self.category} in {self.village.name} ({self.report_count} reports)"


class GramSabhaSession(models.Model):
    village = models.ForeignKey(
        'geo_intelligence.Village', on_delete=models.CASCADE,
        related_name='gram_sabha_sessions',
    )
    title = models.CharField(max_length=200)
    scheduled_at = models.DateTimeField()
    is_active = models.BooleanField(default=False)
    transcript = models.TextField(blank=True)
    summary_s3_key = models.CharField(max_length=500, blank=True)
    created_by = models.ForeignKey(
        'auth_service.User', on_delete=models.SET_NULL,
        null=True, related_name='gram_sabha_sessions',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-scheduled_at']

    def __str__(self):
        return f"{self.title} - {self.village.name}"


class GramSabhaIssue(models.Model):
    session = models.ForeignKey(
        GramSabhaSession, on_delete=models.CASCADE,
        related_name='issues',
    )
    report = models.ForeignKey(
        Report, null=True, blank=True,
        on_delete=models.SET_NULL, related_name='gram_sabha_issues',
    )
    title = models.CharField(max_length=200)
    vote_count = models.IntegerField(default=0)

    class Meta:
        ordering = ['-vote_count']

    def __str__(self):
        return self.title
