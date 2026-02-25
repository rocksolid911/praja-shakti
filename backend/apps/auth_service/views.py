from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model

from .serializers import (
    RegisterSerializer, OTPSendSerializer, OTPVerifySerializer,
    ProfileSerializer, UserSerializer,
)
from .utils import send_otp, verify_otp

User = get_user_model()


@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    serializer = RegisterSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.save()
    refresh = RefreshToken.for_user(user)
    return Response({
        'user': UserSerializer(user).data,
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    phone = request.data.get('phone')
    otp = request.data.get('otp')

    if not phone or not otp:
        return Response(
            {'error': 'Phone and OTP are required'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not verify_otp(phone, otp):
        return Response(
            {'error': 'Invalid or expired OTP'},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    try:
        user = User.objects.get(phone=phone)
    except User.DoesNotExist:
        # Auto-create user on first login
        user = User.objects.create_user(
            username=phone,
            phone=phone,
        )

    refresh = RefreshToken.for_user(user)
    return Response({
        'user': UserSerializer(user).data,
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    })


@api_view(['POST'])
@permission_classes([AllowAny])
def otp_send(request):
    serializer = OTPSendSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    phone = serializer.validated_data['phone']
    otp = send_otp(phone)
    # In dev, return OTP for testing convenience
    return Response({'message': 'OTP sent', 'otp_debug': otp})


@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def profile(request):
    if request.method == 'GET':
        serializer = ProfileSerializer(request.user)
        return Response(serializer.data)

    serializer = ProfileSerializer(request.user, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    serializer.save()
    return Response(serializer.data)
