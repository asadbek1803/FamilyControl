from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from .models import ChildDevice


class BatchSyncTestCase(APITestCase):
    def setUp(self):
        self.parent = User.objects.create_user(username="parent2", password="pass1234")
        self.device = ChildDevice.objects.create(
            device_identifier="android-batch",
            device_name="BatchPhone",
            parent=self.parent,
            is_active=True,
        )
        self.token = self.device.generate_device_token()
        self.device_id = str(self.device.id)

    def test_batch_sync_requires_device_bearer(self):
        url = reverse("sync_batch")
        response = self.client.post(url, {}, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_batch_sync_idempotent_with_uuid(self):
        url = reverse("sync_batch")
        auth_header = f"DeviceBearer {self.device_id}:{self.token}"
        payload = {
            "location_logs": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000",
                    "latitude": 40.7128,
                    "longitude": -74.0060,
                    "accuracy": 10.0,
                    "recorded_at": "2026-10-03T10:00:00Z",
                }
            ],
            "installed_apps": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440001",
                    "app_name": "TestApp",
                    "package_name": "com.test.app",
                    "is_blocked": True,
                }
            ],
            "app_usage_logs": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440002",
                    "package_name": "com.test.app",
                    "total_time_in_foreground_ms": 60000,
                    "start_time": "2026-10-03T09:00:00Z",
                    "end_time": "2026-10-03T10:00:00Z",
                    "recorded_at": "2026-10-03T10:00:00Z",
                }
            ],
            "notification_logs": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440003",
                    "package_name": "com.test.app",
                    "title": "Test",
                    "text": "Hello",
                    "recorded_at": "2026-10-03T10:00:00Z",
                }
            ],
            "accessibility_text_logs": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440004",
                    "package_name": "com.test.app",
                    "extracted_text": "text",
                    "context_type": "view",
                    "recorded_at": "2026-10-03T10:00:00Z",
                }
            ],
        }
        response = self.client.post(url, payload, format="json", HTTP_AUTHORIZATION=auth_header)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("blocked_packages", response.data)
        self.assertIn("com.test.app", response.data["blocked_packages"])
        # Resend same ids - should not create duplicates
        response2 = self.client.post(url, payload, format="json", HTTP_AUTHORIZATION=auth_header)
        self.assertEqual(response2.status_code, status.HTTP_200_OK)
        self.assertEqual(self.device.location_logs.count(), 1)
        self.assertEqual(self.device.app_usage_logs.count(), 1)
        self.assertEqual(self.device.notification_logs.count(), 1)
        self.assertEqual(self.device.accessibility_text_logs.count(), 1)
        # installed apps updated; still 1 record
        self.assertEqual(self.device.installed_apps.count(), 1)

    def test_client_id_is_actually_persisted(self):
        """Klient yuborgan UUID bazaga saqlanishi SHART.

        XATO bo'lsa DRF `id` maydonini `read_only` qilib tashlab ketadi,
        `bulk_create` har syncda yangi tasodifiy UUID yaratadi va
        `ignore_conflicts` hech qachon ishga tushmaydi — ya'ni bir xil log
        har syncda yana yozilib, bazada yig'ilib boradi.
        """
        url = reverse("sync_batch")
        auth_header = f"DeviceBearer {self.device_id}:{self.token}"
        payload = {
            "location_logs": [
                {
                    "id": "550e8400-e29b-41d4-a716-4466554400aa",
                    "latitude": 40.7128,
                    "longitude": -74.0060,
                    "recorded_at": "2026-10-03T11:00:00Z",
                }
            ],
        }
        response = self.client.post(url, payload, format="json", HTTP_AUTHORIZATION=auth_header)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        log = self.device.location_logs.get()
        self.assertEqual(str(log.id), "550e8400-e29b-41d4-a716-4466554400aa")

    def test_sync_without_client_id_still_works(self):
        """Eski ilovalar `id` yubormaydi — server o'zi yaratishi kerak."""
        url = reverse("sync_batch")
        auth_header = f"DeviceBearer {self.device_id}:{self.token}"
        payload = {
            "location_logs": [
                {
                    "latitude": 40.7128,
                    "longitude": -74.0060,
                    "recorded_at": "2026-10-03T12:00:00Z",
                }
            ],
        }
        response = self.client.post(url, payload, format="json", HTTP_AUTHORIZATION=auth_header)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(self.device.location_logs.count(), 1)
        self.assertIsNotNone(self.device.location_logs.get().id)

    def test_different_ids_create_different_rows(self):
        """Turli UUID -> turli qator (tasodifiy yig'ilish bo'lmasligi)."""
        url = reverse("sync_batch")
        auth_header = f"DeviceBearer {self.device_id}:{self.token}"
        for suffix in ("b1", "b2", "b3"):
            response = self.client.post(
                url,
                {
                    "location_logs": [
                        {
                            "id": f"550e8400-e29b-41d4-a716-4466554400{suffix}",
                            "latitude": 40.7128,
                            "longitude": -74.0060,
                            "recorded_at": "2026-10-03T13:00:00Z",
                        }
                    ]
                },
                format="json",
                HTTP_AUTHORIZATION=auth_header,
            )
            self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(self.device.location_logs.count(), 3)
