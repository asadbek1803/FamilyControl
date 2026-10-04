from datetime import timedelta

from django.contrib.auth.models import User
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase
from .models import ChildDevice


class PairingFlowTestCase(APITestCase):
    def setUp(self):
        self.parent = User.objects.create_user(username="parent", password="pass1234")

    def test_device_register_generates_pairing_code(self):
        url = reverse("device_register")
        payload = {
            "device_identifier": "android-12345",
            "device_name": "Kid's Phone",
        }
        response = self.client.post(url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("pairing_code", response.data)
        self.assertIn("device_id", response.data)
        device = ChildDevice.objects.get(device_identifier="android-12345")
        self.assertIsNotNone(device.pairing_code)
        self.assertEqual(len(device.pairing_code), 6)

    def test_device_pair_returns_device_token(self):
        device = ChildDevice.objects.create(
            device_identifier="android-67890",
            device_name="Kid2",
        )
        code = device.generate_pairing_code()
        self.client.force_authenticate(user=self.parent)
        url = reverse("device_pair")
        payload = {
            "device_identifier": "android-67890",
            "pairing_code": code,
        }
        response = self.client.post(url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("device_token", response.data)
        device.refresh_from_db()
        self.assertTrue(device.is_active)
        self.assertIsNotNone(device.device_token_hash)
        self.assertIsNone(device.pairing_code)

    def test_register_refreshes_code_for_unpaired_device(self):
        """Eskargan kodni yangilash yo'li ishlashi kerak (child home'da
        'Yangi kod olish' tugmasi shuni chaqiradi)."""
        device = ChildDevice.objects.create(
            device_identifier="android-refresh",
            device_name="Kid3",
        )
        old_code = device.generate_pairing_code()

        url = reverse("device_register")
        response = self.client.post(
            url, {"device_identifier": "android-refresh"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        device.refresh_from_db()
        self.assertNotEqual(device.pairing_code, old_code)
        self.assertTrue(device.verify_pairing_code(device.pairing_code))

    def test_register_refuses_to_hijack_paired_device(self):
        """XAVFSIZLIK: allaqach ota-onaga ulangan qurilmaga `AllowAny` endpoint
        orqali yangi kod chiqarib berilmasligi kerak — aks holda
        `device_identifier`ni bilgan har kim qurilmani o'g'irlaydi."""
        ChildDevice.objects.create(
            device_identifier="android-paired",
            device_name="Kid4",
            parent=self.parent,
            is_active=True,
        )
        url = reverse("device_register")
        response = self.client.post(
            url, {"device_identifier": "android-paired"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_paired_device_cannot_be_stolen_with_new_code(self):
        """Yangi kod olsa ham, boshqa ota-ona o'sha kod bilan ulana olmasligi kerak."""
        device = ChildDevice.objects.create(
            device_identifier="android-stolen",
            parent=self.parent,
            is_active=True,
        )
        code = device.generate_pairing_code()

        attacker = User.objects.create_user(username="attacker", password="pass1234")
        self.client.force_authenticate(user=attacker)
        url = reverse("device_pair")
        response = self.client.post(url, {"pairing_code": code}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        device.refresh_from_db()
        self.assertEqual(device.parent, self.parent)

    def test_expired_pairing_code_is_rejected(self):
        device = ChildDevice.objects.create(device_identifier="android-expired")
        device.generate_pairing_code()
        device.pairing_code_expires_at = timezone.now() - timedelta(minutes=1)
        device.save(update_fields=["pairing_code_expires_at"])

        self.client.force_authenticate(user=self.parent)
        url = reverse("device_pair")
        response = self.client.post(
            url, {"pairing_code": device.pairing_code}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
