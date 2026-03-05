import logging

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.db import IntegrityError

from .serializers import (
    RegisterSerializer, OTPSendSerializer, OTPVerifySerializer,
    ProfileSerializer, UserSerializer, UserManageSerializer,
)
from .permissions import IsLeader
from .utils import send_otp, verify_otp, normalize_phone
from .firebase_auth import verify_firebase_token, extract_phone_from_firebase

logger = logging.getLogger(__name__)
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
    # Normalize to 10-digit format so +919090291939 and 9090291939 find the same user
    phone = normalize_phone(request.data.get('phone', ''))
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
    # Normalize to 10-digit format before storing OTP
    phone = normalize_phone(serializer.validated_data['phone'])
    otp = send_otp(phone)
    # In dev, return OTP for testing convenience
    return Response({'message': 'OTP sent', 'otp_debug': otp})


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated, IsLeader])
def manage_users(request):
    """List or create users in the leader's panchayat."""
    panchayat = request.user.panchayat
    if not panchayat:
        return Response({'error': 'You must belong to a panchayat to manage users.'}, status=400)

    if request.method == 'GET':
        users = User.objects.filter(panchayat=panchayat).order_by('role', 'first_name')
        return Response(UserManageSerializer(users, many=True).data)

    serializer = UserManageSerializer(data=request.data, context={'request': request})
    serializer.is_valid(raise_exception=True)
    user = serializer.save()
    return Response(UserManageSerializer(user).data, status=status.HTTP_201_CREATED)


@api_view(['PATCH', 'DELETE'])
@permission_classes([IsAuthenticated, IsLeader])
def update_user(request, user_id):
    """Update role, ward, or active status for a user in the leader's panchayat."""
    panchayat = request.user.panchayat
    if not panchayat:
        return Response({'error': 'You must belong to a panchayat to manage users.'}, status=400)
    try:
        user = User.objects.get(id=user_id, panchayat=panchayat)
    except User.DoesNotExist:
        return Response({'error': 'User not found in your panchayat.'}, status=404)

    if user.role in ('government', 'admin'):
        return Response({'error': 'Cannot modify government or admin accounts.'}, status=403)

    if request.method == 'DELETE':
        user.is_active = False
        user.save()
        return Response(status=status.HTTP_204_NO_CONTENT)

    serializer = UserManageSerializer(user, data=request.data, partial=True, context={'request': request})
    serializer.is_valid(raise_exception=True)
    serializer.save()
    return Response(UserManageSerializer(user).data)


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


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def village_leader(request):
    """Get the panchayat leader for a given village (or current user's panchayat)."""
    village_id = request.query_params.get('village')

    if village_id:
        try:
            from apps.geo_intelligence.models import Village
            village = Village.objects.select_related('panchayat').get(id=int(village_id))
            panchayat = village.panchayat
        except (Village.DoesNotExist, ValueError, TypeError):
            return Response({'error': 'Village not found'}, status=404)
    else:
        panchayat = request.user.panchayat
        if not panchayat:
            return Response({'leader': None, 'message': 'No village assigned'})

    if not panchayat:
        return Response({'leader': None, 'message': 'No panchayat found'})

    leaders = User.objects.filter(panchayat=panchayat, role='leader')
    leader = leaders.first()
    if not leader:
        return Response({'leader': None, 'message': 'No leader assigned for this village'})

    return Response({
        'id': leader.id,
        'name': f"{leader.first_name} {leader.last_name}".strip() or leader.phone,
        'phone': leader.phone,
        'panchayat': panchayat.name,
        'ward': leader.ward,
    })


# ── Firebase Authentication ──────────────────────────────────────────────────


@api_view(['POST'])
@permission_classes([AllowAny])
def firebase_login(request):
    """Exchange a Firebase ID token for Django JWT tokens.

    Request body:
        firebase_token: str  — Firebase ID token from client
        name: str (optional) — Display name for new users

    Flow:
    1. Verify Firebase ID token with firebase-admin SDK
    2. Extract phone_number or anonymous UID
    3. Find existing Django user by firebase_uid OR phone number
    4. Create user if not found
    5. Link firebase_uid to user if not already linked
    6. Return Django JWT tokens
    """
    firebase_token = request.data.get('firebase_token')
    if not firebase_token:
        return Response(
            {'error': 'firebase_token is required'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # 1. Verify token
    decoded = verify_firebase_token(firebase_token)
    if not decoded:
        return Response(
            {'error': 'Invalid or expired Firebase token'},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    firebase_uid = decoded['uid']
    sign_in_provider = decoded.get('firebase', {}).get('sign_in_provider', '')
    is_anonymous = sign_in_provider == 'anonymous'
    phone = extract_phone_from_firebase(decoded)

    # 2. Find existing user: first by firebase_uid, then by phone
    user = None
    try:
        user = User.objects.get(firebase_uid=firebase_uid)
    except User.DoesNotExist:
        if phone:
            try:
                user = User.objects.get(phone=phone)
                # Link Firebase UID to existing phone-matched user
                user.firebase_uid = firebase_uid
                user.save(update_fields=['firebase_uid'])
                logger.info(f"Linked firebase_uid to existing user {user.phone}")
            except User.DoesNotExist:
                pass

    # 3. Create new user if not found
    if user is None:
        if is_anonymous:
            # Anonymous user: generate a placeholder phone
            try:
                user = User.objects.create_user(
                    username=f'anon_{firebase_uid[:12]}',
                    phone=f'anon_{firebase_uid[:10]}',
                    firebase_uid=firebase_uid,
                    is_anonymous_user=True,
                )
                logger.info(f"Created anonymous user: {user.username}")
            except IntegrityError:
                # Race condition: another request already created this user
                user = User.objects.get(firebase_uid=firebase_uid)
        elif phone:
            name = request.data.get('name', '')
            first_name = name.split(' ')[0] if name else ''
            last_name = ' '.join(name.split(' ')[1:]) if name and ' ' in name else ''
            try:
                user = User.objects.create_user(
                    username=phone,
                    phone=phone,
                    firebase_uid=firebase_uid,
                    first_name=first_name,
                    last_name=last_name,
                )
                logger.info(f"Created new user via Firebase: {phone}")
            except IntegrityError:
                # Race condition: user was just created by another request
                user = User.objects.get(phone=phone)
                if not user.firebase_uid:
                    user.firebase_uid = firebase_uid
                    user.save(update_fields=['firebase_uid'])
        else:
            return Response(
                {'error': 'No phone number in Firebase token and not anonymous'},
                status=status.HTTP_400_BAD_REQUEST,
            )

    # 4. Issue Django JWTs
    refresh = RefreshToken.for_user(user)
    return Response({
        'user': UserSerializer(user).data,
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'is_new_user': not bool(user.first_name),
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upgrade_anonymous(request):
    """Upgrade an anonymous Firebase user after they link a phone number.

    Called after Firebase linkWithPhoneNumber() on the client.
    Sends a new Firebase ID token that now contains a phone_number claim.
    """
    firebase_token = request.data.get('firebase_token')
    if not firebase_token:
        return Response({'error': 'firebase_token is required'}, status=400)

    decoded = verify_firebase_token(firebase_token)
    if not decoded:
        return Response({'error': 'Invalid Firebase token'}, status=401)

    phone = extract_phone_from_firebase(decoded)
    if not phone:
        return Response({'error': 'No phone in token after linking'}, status=400)

    user = request.user

    # Check if a non-anonymous user already exists with this phone
    existing = User.objects.filter(phone=phone).exclude(id=user.id).first()
    if existing:
        # Merge: transfer firebase_uid to existing user, re-assign owned objects
        from apps.community.models import Report, Vote
        Report.objects.filter(reporter=user).update(reporter=existing)
        Vote.objects.filter(voter=user).update(voter=existing)

        existing.firebase_uid = decoded['uid']
        existing.save(update_fields=['firebase_uid'])

        # Delete the anonymous user
        user.delete()
        user = existing
        logger.info(f"Merged anonymous user into existing user {phone}")
    else:
        user.phone = phone
        user.username = phone
        user.is_anonymous_user = False
        user.save(update_fields=['phone', 'username', 'is_anonymous_user'])
        logger.info(f"Upgraded anonymous user to phone user: {phone}")

    refresh = RefreshToken.for_user(user)
    return Response({
        'user': UserSerializer(user).data,
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    })
