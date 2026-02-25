from django.db import models


class Notification(models.Model):
    CHANNELS = [
        ('push', 'Push Notification'),
        ('whatsapp', 'WhatsApp'),
        ('sms', 'SMS'),
    ]
    user = models.ForeignKey(
        'auth_service.User', on_delete=models.CASCADE,
        related_name='notifications',
    )
    channel = models.CharField(max_length=10, choices=CHANNELS)
    title = models.CharField(max_length=200)
    message = models.TextField()
    data = models.JSONField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    sent_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-sent_at']

    def __str__(self):
        return f"[{self.channel}] {self.title} -> {self.user}"
