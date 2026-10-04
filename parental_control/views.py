from rest_framework import status, permissions, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from django.db import transaction
from .models import (
    ChildDevice,
    LocationLog,
    InstalledApp,
    AppUsageLog,
    NotificationLog,
    AccessibilityTextLog,
    DeviceEvent,
)
from .serializers import (
    DeviceRegisterSerializer,
    DevicePairSerializer,
    LocationLogSerializer,
    InstalledAppSerializer,
    AppUsageLogSerializer,
    NotificationLogSerializer,
    AccessibilityTextLogSerializer,
    DeviceEventSerializer,
)
from .permissions import IsAuthenticatedDevice
from .authentication import DeviceTokenAuthentication
from .notifications import notify_parent


class DeviceRegisterView(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = DeviceRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        device = serializer.save()
        return Response(serializer.to_representation(device), status=status.HTTP_200_OK)


class DeviceClaimView(APIView):
    """Farzand qurilmasi o'zining `device_token` ini oladi.

    Nima uchun kerak: pairing ota-onaning ilovasida amalga oshadi, ya'ni
    `device_token` ota-onaning telefoni bilan qolib ketadi. Farzand qurilmasi
    esa o'z ma'lumotlarini yuborishi (joylashuv, hodisalar) uchun token
    olishi SHART.

    `device_identifier` — qurilmada UUIDv4 sifatida generatsiya qilinadi va
    faqat o'sha qurilmada saqlanadi, ya'ni capability token vazifasini bajaradi.
    Tokenni hech qachon ochiq saqlamaymiz: `claim` uni yangilaydi va yangi
    tokeni qaytaradi, eskisi esa darhol bekor qilinadi.
    """

    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "claim"

    def post(self, request):
        identifier = (request.data.get("device_identifier") or "").strip()
        if not identifier:
            return Response(
                {"error": "device_identifier talab qilinadi"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        device = ChildDevice.objects.filter(device_identifier=identifier).first()
        if device is None:
            return Response({"is_paired": False}, status=status.HTTP_200_OK)

        if not device.is_paired:
            # Hali ota-ona ulamagan — token bermaymiz
            return Response(
                {"is_paired": False, "device_name": device.device_name},
                status=status.HTTP_200_OK,
            )

        token = device.generate_device_token()
        return Response(
            {
                "is_paired": True,
                "device_id": str(device.id),
                "device_token": token,
                "parent_username": device.parent.username if device.parent else None,
            },
            status=status.HTTP_200_OK,
        )


class DeviceEventCreateView(APIView):
    """Qurilma hodisa yuboradi -> server uni Telegram orqali ota-onaga yetkazadi.

    Bot tokeni FAQAT serverda bo'lgani uchun Telegram integratsiyasi butunlay
    server tomonida ishlaydi.
    """

    authentication_classes = [DeviceTokenAuthentication]
    permission_classes = [IsAuthenticatedDevice]

    def post(self, request):
        device = request.auth
        serializer = DeviceEventSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        event_type = serializer.validated_data["event_type"]
        message = serializer.validated_data["message"]
        data = serializer.validated_data.get("data") or {}

        # SOS — maxsus usul: alohida modelga ham yoziladi
        if event_type == DeviceEvent.EVENT_SOS:
            from .models import SOSAlert

            try:
                SOSAlert.objects.create(
                    device=device,
                    latitude=float(data.get("latitude", 0.0)),
                    longitude=float(data.get("longitude", 0.0)),
                )
            except (TypeError, ValueError):
                pass  # koordinata yo'q bo'lsa ham hodisa yuboriladi

        event = notify_parent(device, event_type, message, data)
        return Response(
            {
                "status": "ok",
                "event_id": str(event.id),
                "delivered_to_telegram": event.is_delivered,
            },
            status=status.HTTP_201_CREATED,
        )


class DeviceEventListView(generics.ListAPIView):
    """Ota-onaning o'z qurilmasiga Tegishli hodisa tarixi."""

    authentication_classes = [DeviceTokenAuthentication]
    permission_classes = [IsAuthenticatedDevice]

    def get_serializer_class(self):
        return DeviceEventSerializer

    def get_queryset(self):
        return DeviceEvent.objects.filter(device=self.request.auth)



class DevicePairView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "pair"

    @transaction.atomic
    def post(self, request):
        # `select_for_update` va `clear_pairing_code()` atomik bo'lishi uchun
        # butun jarayon bitta transaction ichida bajarilishi kerak.
        serializer = DevicePairSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        device = serializer.save()

        # "Qurilma ulandi" hodisasi -> ota-onaning Telegram'i
        notify_parent(
            device,
            DeviceEvent.EVENT_PAIRED,
            f"📱 «{request.user.get_username()}» qurilmangizga ulandi.",
        )

        return Response(serializer.to_representation(device), status=status.HTTP_200_OK)


class BatchSyncView(APIView):
    authentication_classes = [DeviceTokenAuthentication]
    permission_classes = [IsAuthenticatedDevice]

    def post(self, request):
        MAX_BATCH = 500

        data = request.data
        if not isinstance(data, dict):
            return Response({"error": "Invalid payload format"}, status=status.HTTP_400_BAD_REQUEST)

        device = request.auth
        if not device or not hasattr(device, "parent"):
            return Response({"error": "Invalid device authentication"}, status=status.HTTP_401_UNAUTHORIZED)

        location_logs = data.get("location_logs", [])
        installed_apps = data.get("installed_apps", [])
        app_usage_logs = data.get("app_usage_logs", [])
        notification_logs = data.get("notification_logs", [])
        accessibility_text_logs = data.get("accessibility_text_logs", [])

        if any(len(x) > MAX_BATCH for x in [
            location_logs, installed_apps, app_usage_logs, notification_logs, accessibility_text_logs
        ]):
            return Response({"error": f"Batch size exceeds limit of {MAX_BATCH}"}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            if location_logs:
                serializer = LocationLogSerializer(data=location_logs, many=True)
                serializer.is_valid(raise_exception=True)
                LocationLog.objects.bulk_create(
                    [
                        LocationLog(**{**item, "device": device})
                        for item in serializer.validated_data
                    ],
                    ignore_conflicts=True,
                )

            if installed_apps:
                serializer = InstalledAppSerializer(data=installed_apps, many=True)
                serializer.is_valid(raise_exception=True)
                for item in serializer.validated_data:
                    InstalledApp.objects.update_or_create(
                        device=device,
                        package_name=item["package_name"],
                        defaults={
                            "app_name": item["app_name"],
                            "is_blocked": item.get("is_blocked", False),
                        },
                    )

            if app_usage_logs:
                serializer = AppUsageLogSerializer(data=app_usage_logs, many=True)
                serializer.is_valid(raise_exception=True)
                AppUsageLog.objects.bulk_create(
                    [
                        AppUsageLog(**{**item, "device": device})
                        for item in serializer.validated_data
                    ],
                    ignore_conflicts=True,
                )

            if notification_logs:
                serializer = NotificationLogSerializer(data=notification_logs, many=True)
                serializer.is_valid(raise_exception=True)
                NotificationLog.objects.bulk_create(
                    [
                        NotificationLog(**{**item, "device": device})
                        for item in serializer.validated_data
                    ],
                    ignore_conflicts=True,
                )

            if accessibility_text_logs:
                serializer = AccessibilityTextLogSerializer(data=accessibility_text_logs, many=True)
                serializer.is_valid(raise_exception=True)
                AccessibilityTextLog.objects.bulk_create(
                    [
                        AccessibilityTextLog(**{**item, "device": device})
                        for item in serializer.validated_data
                    ],
                    ignore_conflicts=True,
                )

        blocked_packages = list(
            InstalledApp.objects.filter(device=device, is_blocked=True)
            .values_list("package_name", flat=True)
        )

        return Response(
            {
                "status": "ok",
                "blocked_packages": blocked_packages,
            },
            status=status.HTTP_200_OK,
        )
