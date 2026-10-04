from django.urls import path
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from .views import (
    DeviceRegisterView,
    DevicePairView,
    BatchSyncView,
)
from .views_parent import (
    ChildDeviceListView,
    ChildDeviceDetailView,
    InstalledAppListView,
    InstalledAppDetailView,
    LocationLogListView,
    AppUsageLogListView,
    NotificationLogListView,
    AccessibilityTextLogListView,
    ParentRegisterView,
    GeoZoneListView,
    AppTimeLimitListView,
    AppTimeLimitDetailView,
    ContactListView,
    SOSAlertCreateView,
    TelegramSettingView,
    DeviceEventListView as ParentDeviceEventListView,
)
from .views import (
    DeviceClaimView,
    DeviceEventCreateView,
)

urlpatterns = [
    path("auth/register/", ParentRegisterView.as_view(), name="parent_register"),
    path("auth/token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("devices/register/", DeviceRegisterView.as_view(), name="device_register"),
    path("devices/pair/", DevicePairView.as_view(), name="device_pair"),
    # Qurilma o'z tokenini oladi (pairing ota-onaning ilovasida bo'lgani uchun)
    path("devices/claim/", DeviceClaimView.as_view(), name="device_claim"),
    path("sync/batch/", BatchSyncView.as_view(), name="sync_batch"),
    # Qurilma hodisa yuboradi (DeviceBearer autentifikatsiyasi)
    path("devices/events/", DeviceEventCreateView.as_view(), name="device_event_create"),
    # Ota-onaning sozlamalari
    path("settings/telegram/", TelegramSettingView.as_view(), name="telegram_setting"),
    path("devices/", ChildDeviceListView.as_view(), name="device_list"),
    path("devices/<uuid:id>/", ChildDeviceDetailView.as_view(), name="device_detail"),
    path("devices/<uuid:device_id>/apps/", InstalledAppListView.as_view(), name="installed_apps_list"),
    path("devices/<uuid:device_id>/apps/<uuid:id>/", InstalledAppDetailView.as_view(), name="installed_app_detail"),
    path("devices/<uuid:device_id>/locations/", LocationLogListView.as_view(), name="location_logs_list"),
    path("devices/<uuid:device_id>/usage/", AppUsageLogListView.as_view(), name="app_usage_logs_list"),
    path("devices/<uuid:device_id>/notifications/", NotificationLogListView.as_view(), name="notification_logs_list"),
    path("devices/<uuid:device_id>/accessibility/", AccessibilityTextLogListView.as_view(), name="accessibility_text_logs_list"),
    path("devices/<uuid:device_id>/zones/", GeoZoneListView.as_view(), name="geozone_list"),
    path("devices/<uuid:device_id>/limits/", AppTimeLimitListView.as_view(), name="apptimelimit_list"),
    path("devices/<uuid:device_id>/limits/<uuid:pk>/", AppTimeLimitDetailView.as_view(), name="apptimelimit_detail"),
    path("devices/<uuid:device_id>/contacts/", ContactListView.as_view(), name="contact_list"),
    path("devices/<uuid:device_id>/sos/", SOSAlertCreateView.as_view(), name="sos_create"),
    path("devices/<uuid:device_id>/events/", ParentDeviceEventListView.as_view(), name="device_events_list"),
]
