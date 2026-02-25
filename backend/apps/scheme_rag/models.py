from django.db import models
from pgvector.django import VectorField


class Scheme(models.Model):
    name = models.CharField(max_length=200)
    short_name = models.CharField(max_length=50)
    ministry = models.CharField(max_length=200)
    category = models.CharField(max_length=100)
    description = models.TextField()
    pdf_s3_key = models.CharField(max_length=500, blank=True)
    max_subsidy_pct = models.FloatField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    last_updated = models.DateField(null=True, blank=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.short_name} - {self.name}"


class SchemeChunk(models.Model):
    CHUNK_TYPES = [
        ('eligibility', 'Eligibility'),
        ('fund_allocation', 'Fund Allocation'),
        ('documents', 'Documents Required'),
        ('process', 'Application Process'),
        ('general', 'General'),
    ]
    scheme = models.ForeignKey(Scheme, on_delete=models.CASCADE, related_name='chunks')
    chunk_index = models.IntegerField()
    content = models.TextField()
    section_header = models.CharField(max_length=200, blank=True)
    chunk_type = models.CharField(max_length=50, choices=CHUNK_TYPES, default='general')
    embedding = VectorField(dimensions=1536)
    token_count = models.IntegerField()

    class Meta:
        ordering = ['scheme', 'chunk_index']

    def __str__(self):
        return f"{self.scheme.short_name} chunk {self.chunk_index}: {self.section_header}"


class EligibilityRule(models.Model):
    scheme = models.ForeignKey(Scheme, on_delete=models.CASCADE, related_name='eligibility_rules')
    rule_text = models.TextField()
    rule_type = models.CharField(max_length=50)
    embedding = VectorField(dimensions=1536)

    def __str__(self):
        return f"{self.scheme.short_name}: {self.rule_text[:60]}"


class FundConvergencePlan(models.Model):
    project = models.ForeignKey(
        'projects.Project', on_delete=models.CASCADE,
        related_name='fund_convergence_plans',
    )
    total_cost_inr = models.BigIntegerField()
    panchayat_contribution_inr = models.BigIntegerField()
    savings_pct = models.FloatField()
    schemes_used = models.JSONField()
    generated_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Fund plan for Project #{self.project_id}: Rs.{self.total_cost_inr}"
