from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path('register/', views.register, name='auth-register'),
    path('login/', views.login, name='auth-login'),
    path('refresh/', TokenRefreshView.as_view(), name='auth-refresh'),
    path('profile/', views.profile, name='auth-profile'),
    path('otp/send/', views.otp_send, name='auth-otp-send'),
    path('users/', views.manage_users, name='manage-users'),
    path('users/<int:user_id>/', views.update_user, name='update-user'),
    path('village-leader/', views.village_leader, name='village-leader'),
]
