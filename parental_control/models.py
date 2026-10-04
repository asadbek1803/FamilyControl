import hashlib
import secrets
import uuid
from datetime import timedelta
from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone


class ChildDevice(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    parent = models.ForeignKey(User, on_delete=models.CASCADE, related_name="devices", null=True, blank=True)
    device_identifier = models.CharField(max_length=255, unique=True)
    device_name = models.CharField(max_length=255, blank=True)
    pairing_code = models.CharField(max_length=6, blank=True, null=True, db_index=True)
    pairing_code_expires_at = models.DateTimeField(blank=True, null=True)
    device_token_hash = models.CharField(max_length=64, blank=True, null=True, db_index=True)
    is_active = models.BooleanField(default=False)
    battery_level = models.FloatField(blank=True, null=True)
    last_seen = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["pairing_code"]),
            models.Index(fields=["device_token_hash"]),
        ]

    def generate_pairing_code(self):
        code = secrets.randbelow(1000000)
        self.pairing_code = f"{code:06d}"
        self.pairing_code_expires_at = timezone.now() + timedelta(minutes=15)
        self.save(update_fields=["pairing_code", "pairing_code_expires_at"])
        return self.pairing_code

    def verify_pairing_code(self, code):
        if not self.pairing_code or not self.pairing_code_expires_at:
            return False
        if timezone.now() > self.pairing_code_expires_at:
            return False
        if self.pairing_code != code:
            return False
        return True

    def clear_pairing_code(self):
        self.pairing_code = None
        self.pairing_code_expires_at = None
        self.save(update_fields=["pairing_code", "pairing_code_expires_at"])

    def generate_device_token(self):
        token = secrets.token_urlsafe(48)
        self.device_token_hash = hashlib.sha256(token.encode()).hexdigest()
        self.is_active = True
        self.save(update_fields=["device_token_hash", "is_active"])
        return token

    def verify_device_token(self, token):
        if not self.device_token_hash:
            return False
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        return secrets.compare_digest(token_hash, self.device_token_hash)

    def update_last_seen(self):
        self.last_seen = timezone.now()
        self.save(update_fields=["last_seen"])

    def __str__(self):
        return f"{self.device_name or self.device_identifier} ({self.parent.username})"


class LocationLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="location_logs")
    latitude = models.FloatField()
    longitude = models.FloatField()
    accuracy = models.FloatField(blank=True, null=True)
    recorded_at = models.DateTimeField(db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["device", "recorded_at"]),
        ]

    def __str__(self):
        return f"{self.device} - {self.recorded_at}"


class InstalledApp(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="installed_apps")
    app_name = models.CharField(max_length=255)
    package_name = models.CharField(max_length=255)
    is_blocked = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("device", "package_name")
        indexes = [
            models.Index(fields=["device"]),
        ]

    def __str__(self):
        return f"{self.package_name} ({self.device})"


class AppUsageLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="app_usage_logs")
    package_name = models.CharField(max_length=255)
    total_time_in_foreground_ms = models.BigIntegerField()
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    recorded_at = models.DateTimeField(db_index=True)

    class Meta:
        indexes = [
            models.Index(fields=["device", "recorded_at"]),
        ]

    def __str__(self):
        return f"{self.package_name} - {self.recorded_at}"


class NotificationLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="notification_logs")
    package_name = models.CharField(max_length=255)
    title = models.CharField(max_length=255, blank=True)
    text = models.TextField(blank=True)
    recorded_at = models.DateTimeField(db_index=True)

    class Meta:
        indexes = [
            models.Index(fields=["device", "recorded_at"]),
        ]

    def __str__(self):
        return f"{self.package_name} - {self.recorded_at}"


class AccessibilityTextLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="accessibility_text_logs")
    package_name = models.CharField(max_length=255)
    extracted_text = models.TextField()
    context_type = models.CharField(max_length=100, blank=True)
    recorded_at = models.DateTimeField(db_index=True)

    class Meta:
        indexes = [
            models.Index(fields=["device", "recorded_at"]),
        ]

    def __str__(self):
        return f"{self.package_name} - {self.recorded_at}"


class GeoZone(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="zones")
    name = models.CharField(max_length=255)
    radius_meters = models.FloatField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} - {self.device}"


class AppTimeLimit(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="limits")
    package_name = models.CharField(max_length=255)
    max_daily_minutes = models.IntegerField()
    block_after_time = models.TimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.package_name} - {self.device}"


class Contact(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="contacts")
    contact_name = models.CharField(max_length=255)
    phone_number = models.CharField(max_length=255)
    is_new = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.contact_name} - {self.device}"


class SOSAlert(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="sos_alerts")
    latitude = models.FloatField()
    longitude = models.FloatField()
    resolved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"SOS - {self.device} at {self.created_at}"
