from django.contrib import admin
from .models import (
    ChildDevice,
    LocationLog,
    InstalledApp,
    AppUsageLog,
    NotificationLog,
    AccessibilityTextLog,
)


@admin.register(ChildDevice)
class ChildDeviceAdmin(admin.ModelAdmin):
    list_display = ("device_identifier", "device_name", "parent", "is_active", "last_seen", "created_at")
    search_fields = ("device_identifier", "device_name", "pairing_code")
    list_filter = ("is_active", "created_at")


@admin.register(LocationLog)
class LocationLogAdmin(admin.ModelAdmin):
    list_display = ("device", "latitude", "longitude", "accuracy", "recorded_at")
    list_filter = ("recorded_at",)


@admin.register(InstalledApp)
class InstalledAppAdmin(admin.ModelAdmin):
    list_display = ("device", "app_name", "package_name", "is_blocked", "updated_at")
    list_filter = ("is_blocked",)
    search_fields = ("package_name", "app_name")


@admin.register(AppUsageLog)
class AppUsageLogAdmin(admin.ModelAdmin):
    list_display = ("device", "package_name", "total_time_in_foreground_ms", "start_time", "end_time", "recorded_at")
    list_filter = ("recorded_at",)


@admin.register(NotificationLog)
class NotificationLogAdmin(admin.ModelAdmin):
    list_display = ("device", "package_name", "title", "recorded_at")
    list_filter = ("recorded_at",)


@admin.register(AccessibilityTextLog)
class AccessibilityTextLogAdmin(admin.ModelAdmin):
    list_display = ("device", "package_name", "context_type", "recorded_at")
    list_filter = ("recorded_at",)
