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

    def get_queryset(self):
        device_id = self.kwargs["device_id"]
        return InstalledApp.objects.filter(device__id=device_id, device__parent=self.request.user)


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
from .serializers import ParentRegisterSerializer

class ParentRegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = ParentRegisterSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response({"message": "User registered successfully"}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

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
