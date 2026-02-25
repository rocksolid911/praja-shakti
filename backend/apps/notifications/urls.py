from django.urls import path
from . import views

urlpatterns = [
    path('webhooks/whatsapp/', views.whatsapp_webhook, name='whatsapp-webhook'),
    path('notifications/device-token/', views.register_device_token, name='register-device-token'),
    path('notifications/device-token/deregister/', views.deregister_device_token, name='deregister-device-token'),
]
