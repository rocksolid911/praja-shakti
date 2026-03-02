from django.db import models


class PriorityScore(models.Model):
    cluster = models.OneToOneField(
        'community.ReportCluster', on_delete=models.CASCADE,
        related_name='priority_score',
    )
    community_score = models.FloatField()
    data_score = models.FloatField()
    urgency_score = models.FloatField()
    total_score = models.FloatField()
    score_breakdown = models.JSONField(null=True, blank=True)
    # Community signals
    report_count_pts = models.FloatField()
    geographic_spread_pts = models.FloatField()
    upvote_pts = models.FloatField()
    gram_sabha_bonus = models.FloatField()
    # Data signals
    satellite_pts = models.FloatField()
    data_gap_pts = models.FloatField()
    demographic_pts = models.FloatField()
    economic_pts = models.FloatField()
    # Urgency signals
    seasonal_pts = models.FloatField()
    safety_pts = models.FloatField()
    worsening_trend_pts = models.FloatField()
    justification = models.TextField(blank=True)
    calculated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-total_score']

    def __str__(self):
        return f"Score {self.total_score:.1f} for cluster #{self.cluster_id}"


class AITask(models.Model):
    TASK_TYPES = [
        ('transcribe', 'Voice Transcription'),
        ('categorize', 'Report Categorization'),
        ('cluster', 'Report Clustering'),
        ('score', 'Priority Scoring'),
        ('recommend', 'Project Recommendation'),
        ('rag_query', 'Scheme RAG Query'),
    ]
    STATUS = [
        ('pending', 'Pending'),
        ('running', 'Running'),
        ('done', 'Done'),
        ('failed', 'Failed'),
    ]
    task_type = models.CharField(max_length=20, choices=TASK_TYPES)
    celery_task_id = models.CharField(max_length=200, blank=True)
    status = models.CharField(max_length=10, choices=STATUS, default='pending')
    input_data = models.JSONField()
    output_data = models.JSONField(null=True, blank=True)
    error = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.get_task_type_display()} [{self.status}]"
