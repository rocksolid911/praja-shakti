from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, OTPVerification


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['phone', 'username', 'role', 'panchayat', 'is_active']
    list_filter = ['role', 'is_active']
    search_fields = ['phone', 'username', 'first_name', 'last_name']
    fieldsets = BaseUserAdmin.fieldsets + (
        ('PrajaShakti', {'fields': ('phone', 'role', 'panchayat', 'ward', 'language_preference', 'whatsapp_number')}),
    )
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('PrajaShakti', {'fields': ('phone', 'role')}),
    )


@admin.register(OTPVerification)
class OTPVerificationAdmin(admin.ModelAdmin):
    list_display = ['phone', 'otp', 'is_used', 'created_at', 'expires_at']
    list_filter = ['is_used']
    search_fields = ['phone']
