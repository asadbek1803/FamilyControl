from rest_framework import serializers
from django.utils import timezone
from .models import (
    ChildDevice,
    LocationLog,
    InstalledApp,
    AppUsageLog,
    NotificationLog,
    AccessibilityTextLog,
    GeoZone,
    AppTimeLimit,
    Contact,
    SOSAlert,
)


class DeviceRegisterSerializer(serializers.Serializer):
    device_identifier = serializers.CharField(max_length=255)
    device_name = serializers.CharField(max_length=255, required=False, allow_blank=True)

    def create(self, validated_data):
        device, created = ChildDevice.objects.get_or_create(
            device_identifier=validated_data["device_identifier"],
            defaults={
                "device_name": validated_data.get("device_name", ""),
            },
        )
        if not created:
            if validated_data.get("device_name"):
                device.device_name = validated_data["device_name"]
                device.save(update_fields=["device_name"])
            # Clear old pairing codes if any? ensure fresh
            device.pairing_code = None
            device.pairing_code_expires_at = None
        device.generate_pairing_code()
        return device

    def to_representation(self, instance):
        return {
            "device_id": instance.id,
            "device_identifier": instance.device_identifier,
            "pairing_code": instance.pairing_code,
            "expires_at": instance.pairing_code_expires_at,
        }


class DevicePairSerializer(serializers.Serializer):
    device_identifier = serializers.CharField(max_length=255)
    pairing_code = serializers.CharField(max_length=6)

    def validate_pairing_code(self, value):
        if not value.isdigit():
            raise serializers.ValidationError("Pairing code must be 6 digits.")
        return value

    def validate(self, attrs):
        try:
            device = ChildDevice.objects.get(device_identifier=attrs["device_identifier"])
        except ChildDevice.DoesNotExist:
            raise serializers.ValidationError("Invalid device or pairing code.")

        if not device.verify_pairing_code(attrs["pairing_code"]):
            raise serializers.ValidationError("Invalid device or pairing code.")

        attrs["device"] = device
        return attrs

    def save(self, **kwargs):
        device = self.validated_data["device"]
        device.parent = self.context["request"].user
        device.clear_pairing_code()
        token = device.generate_device_token()
        self.token = token
        return device

    def to_representation(self, instance):
        return {
            "device_id": instance.id,
            "device_token": getattr(self, "token", None),
            "is_active": instance.is_active,
        }


class LocationLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = LocationLog
        fields = ["id", "latitude", "longitude", "accuracy", "recorded_at"]

    def validate_latitude(self, value):
        if not (-90.0 <= value <= 90.0):
            raise serializers.ValidationError("Latitude must be between -90 and 90.")
        return value

    def validate_longitude(self, value):
        if not (-180.0 <= value <= 180.0):
            raise serializers.ValidationError("Longitude must be between -180 and 180.")
        return value


class InstalledAppSerializer(serializers.ModelSerializer):
    class Meta:
        model = InstalledApp
        fields = ["id", "app_name", "package_name", "is_blocked", "updated_at"]


class AppUsageLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppUsageLog
        fields = ["id", "package_name", "total_time_in_foreground_ms", "start_time", "end_time", "recorded_at"]

    def validate(self, attrs):
        start_time = attrs.get("start_time")
        end_time = attrs.get("end_time")
        if start_time and end_time and end_time < start_time:
            raise serializers.ValidationError("end_time must be >= start_time")
        return attrs


class NotificationLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationLog
        fields = ["id", "package_name", "title", "text", "recorded_at"]


class AccessibilityTextLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AccessibilityTextLog
        fields = ["id", "package_name", "extracted_text", "context_type", "recorded_at"]

class ChildDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChildDevice
        fields = ['id', 'device_identifier', 'device_name', 'is_active', 'battery_level', 'last_seen', 'created_at']
        read_only_fields = ['id', 'created_at', 'last_seen']

from django.contrib.auth.models import User

class ParentRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['username', 'password', 'email']

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password']
        )
        return user

class GeoZoneSerializer(serializers.ModelSerializer):
    class Meta:
        model = GeoZone
        fields = ["id", "name", "radius_meters", "created_at"]
        read_only_fields = ["id", "created_at"]

class AppTimeLimitSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppTimeLimit
        fields = ["id", "package_name", "max_daily_minutes", "block_after_time", "is_active"]
        read_only_fields = ["id"]

class ContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = Contact
        fields = ["id", "contact_name", "phone_number", "is_new", "updated_at"]
        read_only_fields = ["id", "updated_at"]

class SOSAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = SOSAlert
        fields = ["id", "latitude", "longitude", "resolved", "created_at"]
        read_only_fields = ["id", "created_at"]
