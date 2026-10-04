from django.contrib.auth.models import User
from django.urls import reverse
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
