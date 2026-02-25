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


class DataSyncLog(models.Model):
    SOURCES = [
        ('agmarknet', 'Agmarknet Prices'),
        ('egram_swaraj', 'eGramSwaraj'),
        ('bhuvan_ndvi', 'Bhuvan NDVI'),
        ('cgwb', 'CGWB Groundwater'),
        ('disha', 'DISHA Dashboard'),
        ('census', 'Census Data'),
        ('osm', 'OpenStreetMap'),
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
