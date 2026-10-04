from rest_framework import status, permissions
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
)
from .serializers import (
    DeviceRegisterSerializer,
    DevicePairSerializer,
    LocationLogSerializer,
    InstalledAppSerializer,
    AppUsageLogSerializer,
    NotificationLogSerializer,
    AccessibilityTextLogSerializer,
)
from .permissions import IsAuthenticatedDevice
from .authentication import DeviceTokenAuthentication


class DeviceRegisterView(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = DeviceRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        device = serializer.save()
        return Response(serializer.to_representation(device), status=status.HTTP_200_OK)


class DevicePairView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "pair"

    def post(self, request):
        serializer = DevicePairSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        device = serializer.save()
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
