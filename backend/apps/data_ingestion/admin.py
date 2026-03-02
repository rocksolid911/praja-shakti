from django.contrib import admin
from .models import MarketPrice, DataSyncLog


@admin.register(MarketPrice)
class MarketPriceAdmin(admin.ModelAdmin):
    list_display = ['commodity', 'mandi', 'price_modal', 'date']
    list_filter = ['commodity', 'state']
    search_fields = ['commodity', 'mandi']


@admin.register(DataSyncLog)
class DataSyncLogAdmin(admin.ModelAdmin):
    list_display = ['source', 'success', 'records_processed', 'started_at', 'completed_at']
    list_filter = ['source', 'success']
