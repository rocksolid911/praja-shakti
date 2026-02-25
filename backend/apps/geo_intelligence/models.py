from django.contrib.gis.db import models


class State(models.Model):
    name = models.CharField(max_length=100)
    lgd_code = models.CharField(max_length=10, unique=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class District(models.Model):
    state = models.ForeignKey(State, on_delete=models.CASCADE, related_name='districts')
    name = models.CharField(max_length=100)
    lgd_code = models.CharField(max_length=10, unique=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name}, {self.state.name}"


class Block(models.Model):
    district = models.ForeignKey(District, on_delete=models.CASCADE, related_name='blocks')
    name = models.CharField(max_length=100)
    lgd_code = models.CharField(max_length=10, unique=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name}, {self.district.name}"


class Panchayat(models.Model):
    block = models.ForeignKey(Block, on_delete=models.CASCADE, related_name='panchayats')
    name = models.CharField(max_length=100)
    lgd_code = models.CharField(max_length=10, unique=True)
    boundary = models.MultiPolygonField(srid=4326, null=True, blank=True)
    population = models.IntegerField(null=True, blank=True)
    households = models.IntegerField(null=True, blank=True)
    area_sq_km = models.FloatField(null=True, blank=True)
    fund_available_inr = models.BigIntegerField(default=0)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name}, {self.block.name}"


class Village(models.Model):
    panchayat = models.ForeignKey(Panchayat, on_delete=models.CASCADE, related_name='villages')
    name = models.CharField(max_length=100)
    lgd_code = models.CharField(max_length=10, unique=True)
    location = models.PointField(srid=4326, null=True, blank=True)
    boundary = models.MultiPolygonField(srid=4326, null=True, blank=True)
    population = models.IntegerField(null=True, blank=True)
    households = models.IntegerField(null=True, blank=True)
    agricultural_households = models.IntegerField(null=True, blank=True)
    groundwater_depth_m = models.FloatField(null=True, blank=True)
    ndvi_score = models.FloatField(null=True, blank=True)
    ndvi_updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name}, {self.panchayat.name}"


class Infrastructure(models.Model):
    TYPES = [
        ('school', 'School'),
        ('hospital', 'Hospital'),
        ('market', 'Market'),
        ('water_source', 'Water Source'),
        ('road', 'Road'),
    ]
    village = models.ForeignKey(Village, on_delete=models.CASCADE, related_name='infrastructure')
    infra_type = models.CharField(max_length=20, choices=TYPES)
    name = models.CharField(max_length=200, blank=True)
    location = models.PointField(srid=4326)
    osm_id = models.CharField(max_length=50, blank=True)
    distance_from_center_km = models.FloatField(null=True, blank=True)

    class Meta:
        verbose_name_plural = 'Infrastructure'

    def __str__(self):
        return f"{self.get_infra_type_display()}: {self.name or 'Unnamed'}"
