from django.contrib import admin
from .models import Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['user', 'channel', 'title', 'is_read', 'sent_at']
    list_filter = ['channel', 'is_read']
    search_fields = ['title', 'message']
