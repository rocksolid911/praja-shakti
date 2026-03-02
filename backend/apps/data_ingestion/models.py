from django.db import models


class MarketPrice(models.Model):
    date = models.DateField()
    commodity = models.CharField(max_length=100)
    mandi = models.CharField(max_length=200)
    district = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    price_min = models.FloatField(null=True, blank=True)
    price_max = models.FloatField(null=True, blank=True)
    price_modal = models.FloatField(null=True, blank=True)

    class Meta:
        ordering = ['-date']
        unique_together = ['date', 'commodity', 'mandi']

    def __str__(self):
        return f"{self.commodity} @ {self.mandi}: Rs.{self.price_modal} ({self.date})"


class DistrictSchemeStats(models.Model):
    """Per-district scheme implementation statistics fetched from government APIs."""
    SCHEME_CHOICES = [
        ('mgnrega', 'MGNREGA'),
        ('jjm', 'Jal Jeevan Mission'),
        ('pmay_g', 'PMAY-G'),
        ('sbm_g', 'SBM-G'),
        ('pm_kisan', 'PM-KISAN'),
        ('pmgsy', 'PMGSY'),
        ('pm_kusum', 'PM-KUSUM'),
    ]
    district_lgd = models.CharField(max_length=10, db_index=True)
    district_name = models.CharField(max_length=100)
    state_name = models.CharField(max_length=100)
    scheme = models.CharField(max_length=20, choices=SCHEME_CHOICES)
    year = models.CharField(max_length=10)          # e.g., '2023-24'

    # MGNREGA fields
    person_days_generated = models.BigIntegerField(null=True, blank=True)
    households_employed = models.IntegerField(null=True, blank=True)
    expenditure_inr = models.BigIntegerField(null=True, blank=True)
    works_completed = models.IntegerField(null=True, blank=True)

    # JJM / water fields
    tap_connections_target = models.IntegerField(null=True, blank=True)
    tap_connections_achieved = models.IntegerField(null=True, blank=True)
    coverage_pct = models.FloatField(null=True, blank=True)

    # Generic
    beneficiary_count = models.IntegerField(null=True, blank=True)
    amount_released_inr = models.BigIntegerField(null=True, blank=True)
    source_url = models.URLField(blank=True)
    fetched_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['district_lgd', 'scheme', 'year']
        ordering = ['-fetched_at']
        verbose_name = 'District Scheme Stat'
        verbose_name_plural = 'District Scheme Stats'

    def __str__(self):
        return f"{self.district_name} | {self.get_scheme_display()} | {self.year}"


class DataSyncLog(models.Model):
    SOURCES = [
        ('agmarknet', 'Agmarknet Prices'),
        ('egram_swaraj', 'eGramSwaraj'),
        ('bhuvan_ndvi', 'Bhuvan NDVI'),
        ('cgwb', 'CGWB Groundwater'),
        ('disha', 'DISHA Dashboard'),
        ('census', 'Census Data'),
        ('osm', 'OpenStreetMap'),
        ('myscheme', 'myScheme.gov.in'),
        ('datagov', 'data.gov.in'),
    ]
    source = models.CharField(max_length=20, choices=SOURCES)
    started_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    records_processed = models.IntegerField(default=0)
    records_created = models.IntegerField(default=0)
    records_updated = models.IntegerField(default=0)
    success = models.BooleanField(default=False)
    error = models.TextField(blank=True)

    class Meta:
        ordering = ['-started_at']

    def __str__(self):
        status = 'OK' if self.success else 'FAILED'
        return f"{self.get_source_display()} sync [{status}] {self.started_at}"
