from django.contrib.gis.db import models


class Project(models.Model):
    STATUS = [
        ('recommended', 'AI Recommended'),
        ('adopted', 'Adopted'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('delayed', 'Delayed'),
    ]
    cluster = models.ForeignKey(
        'community.ReportCluster', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='projects',
    )
    village = models.ForeignKey(
        'geo_intelligence.Village', on_delete=models.CASCADE,
        related_name='projects',
    )
    adopted_by = models.ForeignKey(
        'auth_service.User', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='adopted_projects',
    )
    title = models.CharField(max_length=300)
    description = models.TextField()
    category = models.CharField(max_length=20)
    location = models.PointField(srid=4326, null=True, blank=True)
    estimated_cost_inr = models.BigIntegerField()
    beneficiary_count = models.IntegerField(null=True, blank=True)
    impact_projection = models.JSONField(null=True, blank=True)
    priority_score = models.FloatField(null=True, blank=True)
    ai_confidence = models.FloatField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS, default='recommended')
    proposal_s3_key = models.CharField(max_length=500, blank=True)
    mgnrega_request_s3_key = models.CharField(max_length=500, blank=True)
    scheme_application_s3_key = models.CharField(max_length=500, blank=True)
    adopted_at = models.DateTimeField(null=True, blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    expected_completion = models.DateField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    avg_citizen_rating = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-priority_score']

    def __str__(self):
        return f"[{self.status}] {self.title}"


class ProjectPhoto(models.Model):
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name='photos')
    uploaded_by = models.ForeignKey(
        'auth_service.User', on_delete=models.SET_NULL,
        null=True, related_name='project_photos',
    )
    s3_key = models.CharField(max_length=500)
    caption = models.CharField(max_length=200, blank=True)
    is_delay_report = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Photo for {self.project.title}"


class ProjectRating(models.Model):
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name='ratings')
    citizen = models.ForeignKey(
        'auth_service.User', on_delete=models.CASCADE,
        related_name='project_ratings',
    )
    rating = models.IntegerField()
    review = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['project', 'citizen']

    def __str__(self):
        return f"{self.citizen} rated {self.project.title}: {self.rating}/5"
