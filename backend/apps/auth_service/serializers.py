from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'phone', 'username', 'first_name', 'last_name', 'role',
                  'panchayat', 'ward', 'language_preference', 'whatsapp_number']
        read_only_fields = ['id']


class RegisterSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['phone', 'first_name', 'last_name', 'role', 'panchayat',
                  'ward', 'language_preference']

    def create(self, validated_data):
        phone = validated_data['phone']
        user = User.objects.create_user(
            username=phone,
            phone=phone,
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            role=validated_data.get('role', 'citizen'),
            panchayat=validated_data.get('panchayat'),
            ward=validated_data.get('ward'),
            language_preference=validated_data.get('language_preference', 'hi'),
        )
        return user


class OTPSendSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)


class OTPVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    otp = serializers.CharField(max_length=6)


class UserManageSerializer(serializers.ModelSerializer):
    """Used by leaders to create or update users in their panchayat."""

    class Meta:
        model = User
        fields = ['id', 'phone', 'first_name', 'last_name', 'role', 'ward']
        read_only_fields = ['id']

    def validate_role(self, value):
        if value not in ('citizen', 'leader'):
            raise serializers.ValidationError("Leaders can only assign 'citizen' or 'leader' roles.")
        return value

    def create(self, validated_data):
        phone = validated_data['phone']
        user, _ = User.objects.get_or_create(phone=phone, defaults={'username': phone})
        user.first_name = validated_data.get('first_name', user.first_name)
        user.last_name = validated_data.get('last_name', user.last_name)
        user.role = validated_data.get('role', user.role or 'citizen')
        user.ward = validated_data.get('ward', user.ward)
        user.panchayat = self.context['request'].user.panchayat
        user.save()
        return user


class ProfileSerializer(serializers.ModelSerializer):
    panchayat_name = serializers.CharField(source='panchayat.name', read_only=True, default=None)
    village_id = serializers.SerializerMethodField()
    village_name = serializers.SerializerMethodField()

    def get_village_id(self, obj):
        if obj.panchayat:
            v = obj.panchayat.villages.first()
            return v.id if v else None
        return None

    def get_village_name(self, obj):
        if obj.panchayat:
            v = obj.panchayat.villages.first()
            return v.name if v else None
        return None

    class Meta:
        model = User
        fields = ['id', 'phone', 'username', 'first_name', 'last_name', 'role',
                  'panchayat', 'panchayat_name', 'ward', 'language_preference',
                  'whatsapp_number', 'village_id', 'village_name']
        read_only_fields = ['id', 'phone', 'role']
