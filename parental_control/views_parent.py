from datetime import timedelta

from rest_framework import generics, permissions
from .models import (
    ChildDevice,
    LocationLog,
    InstalledApp,
    AppUsageLog,
    NotificationLog,
    GeoZone,
    AppTimeLimit,
    Contact,
    SOSAlert,
    DeviceEvent,
    TelegramNotificationSetting,
)
from .serializers import (
    ChildDeviceSerializer,
    LocationLogSerializer,
    InstalledAppSerializer,
    AppUsageLogSerializer,
    NotificationLogSerializer,
    GeoZoneSerializer,
    AppTimeLimitSerializer,
    ContactSerializer,
    SOSAlertSerializer,
    DeviceEventSerializer,
    ParentRegisterSerializer,
    TelegramNotificationSettingSerializer,
)
from .permissions import IsParentOfDevice
from . import telegram
from .notifications import notify_parent


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


# ---------------------------------------------------------------------------
# `AccessibilityTextLogListView` 2026-10 da olib tashlandi.
#
# Bu endpoint ekrandagi matnni (`extracted_text`) ota-onaga qaytarardi.
# Android ilovasi hech qachon shu ma'lumotni yubormagan
# (`canRetrieveWindowContent="false"`), ya'ni javob har doim `[]` bo'lardi.
# Endi model ham, endpoint ham yo'q — bu tizim ekran matnini yig'maydi.
# ---------------------------------------------------------------------------

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone

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
    """Qurilma hodisalari tarixi (ulandi, bloklandi, SOS, batareya, zona).

    `/devices/<uuid>/events/?event_type=sos&days=7` — filtrlar ixtiyoriy.
    """

    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = DeviceEventSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        queryset = DeviceEvent.objects.filter(
            device__id=device_id, device__parent=self.request.user
        )

        params = self.request.query_params

        event_type = params.get("event_type")
        if event_type:
            valid = {choice for choice, _label in DeviceEvent.EVENT_TYPE_CHOICES}
            if event_type not in valid:
                # Noto'g'ri filtr butun ro'yxatni bo'sh qilib yubormasligi
                # kerak — aks holda xato foydalanuvchiga "tarix yo'q" ko'rinadi.
                return queryset.none()
            queryset = queryset.filter(event_type=event_type)

        days = params.get("days")
        if days:
            try:
                days = int(days)
            except (TypeError, ValueError):
                return queryset.none()
            if days > 0:
                queryset = queryset.filter(
                    created_at__gte=timezone.now() - timedelta(days=days)
                )

        return queryset

class GeoZoneListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = GeoZoneSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        # `GeoZone` da `Meta.ordering` yo'q — zonesiz ro'yxat har ochilishida
        # boshqa tartibda chiqadi va foydalanuvchi o'z zonasini topa olmaydi.
        return GeoZone.objects.filter(
            device__id=device_id, device__parent=self.request.user
        ).order_by("-created_at")

    def perform_create(self, serializer):
        device = ChildDevice.objects.get(id=self.kwargs["device_id"], parent=self.request.user)
        serializer.save(device=device)


class GeoZoneDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Bitta xavfsizlik zonasi — tahrirlash va o'chirish.

    `lookup_field = "id"` `urls.py` dagi `<uuid:id>` bilan mos kelishi uchun
    (standart `pk` mos kelmasa har bir so'rovda xato beradi).
    """

    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = GeoZoneSerializer
    lookup_field = "id"

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return GeoZone.objects.filter(
            device__id=device_id, device__parent=self.request.user
        )


class AppTimeLimitListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = AppTimeLimitSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return AppTimeLimit.objects.filter(device__id=device_id, device__parent=self.request.user)

    def perform_create(self, serializer):
        device = ChildDevice.objects.get(id=self.kwargs["device_id"], parent=self.request.user)
        serializer.save(device=device)

class ContactListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = ContactSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return Contact.objects.filter(device__id=device_id, device__parent=self.request.user)

    def perform_create(self, serializer):
        device = ChildDevice.objects.get(id=self.kwargs["device_id"], parent=self.request.user)
        serializer.save(device=device)

class SOSAlertListCreateView(generics.ListCreateAPIView):
    """SOS signallari — ota-ona ko'radi va yaratadi.

    Avval faqat `CreateAPIView` bor edi: bola yuborsa, ota-ona uni ilovada
    ko'ra olmasdi (faqat Telegram'da xabar kelardi). Endi tarixi ham ko'rinadi.
    """

    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = SOSAlertSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        queryset = SOSAlert.objects.filter(
            device__id=device_id, device__parent=self.request.user
        )

        # `?unresolved=1` — faqat hali ko'rib chiqilmagan signallar.
        # Panel shu filtr bilan yopilgan signallarni topadi.
        raw = self.request.query_params.get("unresolved")
        if raw is not None and raw.lower() in ("1", "true", "yes"):
            queryset = queryset.filter(resolved=False)

        return queryset

    def perform_create(self, serializer):
        device = ChildDevice.objects.get(id=self.kwargs["device_id"], parent=self.request.user)
        serializer.save(device=device)


class SOSAlertDetailView(generics.RetrieveUpdateAPIView):
    """Bitta SOS signali — ota-ona uni `resolved=true` deb belgilaydi."""

    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = SOSAlertSerializer
    lookup_field = "id"

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return SOSAlert.objects.filter(
            device__id=device_id, device__parent=self.request.user
        )


class AppTimeLimitDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = AppTimeLimitSerializer

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return AppTimeLimit.objects.filter(device__id=device_id, device__parent=self.request.user)

class ContactDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsParentOfDevice]
    serializer_class = ContactSerializer

    # `urls.py` da `<uuid:id>` ishlatilgan — DRF standart `pk` ni kutadi va
    # mos kelmasa har bir so'rovda `AssertionError` beradi.
    lookup_field = "id"

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return Contact.objects.filter(device__id=device_id, device__parent=self.request.user)
