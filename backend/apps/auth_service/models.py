from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    ROLES = [
        ('citizen', 'Citizen'),
        ('leader', 'Leader'),
        ('government', 'Government'),
        ('admin', 'Admin'),
    ]
    phone = models.CharField(max_length=15, unique=True)
    role = models.CharField(max_length=12, choices=ROLES, default='citizen')
    panchayat = models.ForeignKey(
        'geo_intelligence.Panchayat',
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='users',
    )
    ward = models.IntegerField(null=True, blank=True)
    language_preference = models.CharField(max_length=10, default='en')
    whatsapp_number = models.CharField(max_length=15, blank=True)
    firebase_uid = models.CharField(
        max_length=128, unique=True, null=True, blank=True,
        help_text='Firebase Authentication UID',
    )
    is_anonymous_user = models.BooleanField(
        default=False,
        help_text='True if created via Firebase Anonymous Auth',
    )

    USERNAME_FIELD = 'phone'
    REQUIRED_FIELDS = ['username']

    def __str__(self):
        return f"{self.get_full_name() or self.phone} ({self.role})"


class OTPVerification(models.Model):
    phone = models.CharField(max_length=15)
    otp = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_used = models.BooleanField(default=False)
    expires_at = models.DateTimeField()

    def __str__(self):
        return f"OTP for {self.phone}"
