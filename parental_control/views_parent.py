from rest_framework import generics, permissions
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
from .serializers import (
    ChildDeviceSerializer,
    LocationLogSerializer,
    InstalledAppSerializer,
    AppUsageLogSerializer,
    NotificationLogSerializer,
    AccessibilityTextLogSerializer,
    GeoZoneSerializer,
    AppTimeLimitSerializer,
    ContactSerializer,
    SOSAlertSerializer,
)
from .permissions import IsParentOfDevice


class ChildDeviceListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = ChildDeviceSerializer

    def get_queryset(self):
        return ChildDevice.objects.filter(parent=self.request.user)


class ChildDeviceDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = ChildDeviceSerializer
    queryset = ChildDevice.objects.all()
    lookup_field = "id"

    def get_queryset(self):
        return ChildDevice.objects.filter(parent=self.request.user)


class InstalledAppListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = InstalledAppSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return InstalledApp.objects.filter(device__id=device_id, device__parent=self.request.user)

    def perform_create(self, serializer):
        device = ChildDevice.objects.get(id=self.kwargs["device_id"], parent=self.request.user)
        serializer.save(device=device)


class InstalledAppDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = InstalledAppSerializer

    # `urls.py` da yo'l `devices/<uuid:device_id>/apps/<uuid:id>/` ko'rinishida,
    # ya'ni kalit `id`. DRF standart `pk` ni kutadi va mos kelmasa har bir
    # so'rovda xato beradi ("Expected view ... to be called with a URL keyword
    # argument named 'pk'"), ya'ni endpoint umuman ishlamaydi.
    lookup_field = "id"

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return InstalledApp.objects.filter(device__id=device_id, device__parent=self.request.user)

    def update(self, request, *args, **kwargs):
        """Bloklash/blokdan chiqarish hodisasi qurilma tarixiga yoziladi.

        Telegram xabari shu qarorning o'zi qabul qilgani uchun, asl maqsad —
 * keyinchalik ota-onaning boshqa akkaunti yoki boshqa ilovada ko'rish uchun
        * aniq tarix (Telegram orqali ota-onaga o'zi eslatma beradi).
        """
        app = self.get_object()
        was_blocked = app.is_blocked
        response = super().update(request, *args, **kwargs)
        app.refresh_from_db()

        if app.is_blocked != was_blocked:
            device = app.device
            label = app.app_name or app.package_name
            if app.is_blocked:
                notify_parent(
                    device,
                    DeviceEvent.EVENT_APP_BLOCKED,
                    f"🚫 «{label}» ilovasi bloklandi.",
                    {"package_name": app.package_name},
                )
            else:
                notify_parent(
                    device,
                    DeviceEvent.EVENT_APP_UNBLOCKED,
                    f"✅ «{label}» blokdan chiqarildi.",
                    {"package_name": app.package_name},
                )
        return response


class LocationLogListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = LocationLogSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return LocationLog.objects.filter(device__id=device_id, device__parent=self.request.user)


class AppUsageLogListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = AppUsageLogSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return AppUsageLog.objects.filter(device__id=device_id, device__parent=self.request.user)


class NotificationLogListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = NotificationLogSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return NotificationLog.objects.filter(device__id=device_id, device__parent=self.request.user)


class AccessibilityTextLogListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = AccessibilityTextLogSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return AccessibilityTextLog.objects.filter(device__id=device_id, device__parent=self.request.user)

from rest_framework import permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth.models import User
from django.utils import timezone
from .serializers import ParentRegisterSerializer, TelegramNotificationSettingSerializer
from .models import DeviceEvent, TelegramNotificationSetting
from . import telegram
from .notifications import notify_parent

class ParentRegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = ParentRegisterSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response({"message": "User registered successfully"}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class TelegramSettingView(APIView):
    """Ota-onaning Telegram bildirishnoma sozlamalari.

    GET  -> joriy holat
    PUT  -> chat_id va is_enabled ni yangilaydi (chat ID `getChat` bilan tekshiriladi)
    POST -> test xabari yuboradi
    """

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        setting, _ = TelegramNotificationSetting.objects.get_or_create(user=request.user)
        data = TelegramNotificationSettingSerializer(setting).data
        data["bot_configured"] = telegram.is_configured()
        data["bot_username"] = _get_bot_username()
        return Response(data)

    def put(self, request):
        setting, _ = TelegramNotificationSetting.objects.get_or_create(user=request.user)
        serializer = TelegramNotificationSettingSerializer(
            setting, data=request.data, partial=True, context={"request": request}
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(serializer.data)

    def post(self, request):
        """Test xabari — chat ID to'g'rini isbot uchun."""
        setting = TelegramNotificationSetting.objects.filter(user=request.user).first()
        if setting is None or not setting.chat_id:
            return Response(
                {"error": "Avval Telegram chat ID sini kiriting."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        text = (
            "✅ FamilyControl bilan bog'landingiz.\n\n"
            "Endi sizga xabarlar shu yerga yuboriladi:\n"
            "• Qurilma ulandi / uzildi\n"
            "• SOS signali\n"
            "• Ilova bloklandi / blokdan chiqarildi\n"
            "• Batareya qullab qolmoqda\n"
            "• Himoya o'chirildi\n"
            "• Xavfsizlik zonasidan chiqildi"
        )
        if not telegram.send_message(setting.chat_id, text):
            return Response(
                {"error": "Xabar yuborilmadi. Botga /start yuborganingizni tekshiring."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        setting.last_sent_at = timezone.now()
        setting.save(update_fields=["last_sent_at"])
        return Response({"status": "ok", "message": "Test xabari yuborildi."})


def _get_bot_username():
    """Bot username'ni ko'rsatish uchun (sozlamalar ekranida ko'rinadi)."""
    if not telegram.is_configured():
        return None
    result = telegram.get_me()
    return result.get("username") if result else None


class DeviceEventListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = None

    def get_serializer_class(self):
        from .serializers import DeviceEventSerializer

        return DeviceEventSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return DeviceEvent.objects.filter(
            device__id=device_id, device__parent=self.request.user
        )

class GeoZoneListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = GeoZoneSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return GeoZone.objects.filter(device__id=device_id, device__parent=self.request.user)

    def perform_create(self, serializer):
        device = ChildDevice.objects.get(id=self.kwargs["device_id"], parent=self.request.user)
        serializer.save(device=device)

class AppTimeLimitListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = AppTimeLimitSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return AppTimeLimit.objects.filter(device__id=device_id, device__parent=self.request.user)

    def perform_create(self, serializer):
        device = ChildDevice.objects.get(id=self.kwargs["device_id"], parent=self.request.user)
        serializer.save(device=device)

class AppTimeLimitDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = AppTimeLimitSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return AppTimeLimit.objects.filter(device__id=device_id, device__parent=self.request.user)

class ContactListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = ContactSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return Contact.objects.filter(device__id=device_id, device__parent=self.request.user)

    def perform_create(self, serializer):
        device = ChildDevice.objects.get(id=self.kwargs["device_id"], parent=self.request.user)
        serializer.save(device=device)

class SOSAlertCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = SOSAlertSerializer

    def perform_create(self, serializer):
        device = ChildDevice.objects.get(id=self.kwargs["device_id"], parent=self.request.user)
        serializer.save(device=device)
