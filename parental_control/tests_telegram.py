from unittest.mock import patch

from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import ChildDevice, DeviceEvent, TelegramNotificationSetting


class TelegramSettingTestCase(APITestCase):
    def setUp(self):
        self.parent = User.objects.create_user(username="tparent", password="pass1234")
        self.url = reverse("telegram_setting")

    def test_requires_authentication(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_get_returns_empty_settings(self):
        self.client.force_authenticate(user=self.parent)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsNone(response.data["chat_id"])
        self.assertFalse(response.data["is_enabled"])

    @patch("parental_control.telegram.get_chat")
    @patch("parental_control.telegram.is_configured", return_value=True)
    def test_put_validates_chat_and_saves(self, _configured, mock_get_chat):
        mock_get_chat.return_value = {"id": 555111, "title": "Ota-onam"}
        self.client.force_authenticate(user=self.parent)

        response = self.client.put(
            self.url, {"chat_id": 555111, "is_enabled": True}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["is_enabled"])
        self.assertEqual(response.data["chat_title"], "Ota-onam")
        self.assertEqual(TelegramNotificationSetting.objects.count(), 1)

    @patch("parental_control.telegram.get_chat", return_value=None)
    @patch("parental_control.telegram.is_configured", return_value=True)
    def test_put_rejects_unreachable_chat(self, _configured, _get_chat):
        self.client.force_authenticate(user=self.parent)
        response = self.client.put(self.url, {"chat_id": 555111}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("chat_id", response.data)

    @patch("parental_control.telegram.is_configured", return_value=False)
    def test_put_rejected_when_bot_not_configured(self, _configured):
        self.client.force_authenticate(user=self.parent)
        response = self.client.put(self.url, {"chat_id": 555111}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch("parental_control.telegram.send_message", return_value=True)
    def test_test_message_delivered(self, mock_send):
        TelegramNotificationSetting.objects.create(
            user=self.parent, chat_id=555111, is_enabled=True
        )
        self.client.force_authenticate(user=self.parent)
        response = self.client.post(self.url, {}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(mock_send.called)

    def test_chat_id_cannot_be_shared_between_accounts(self):
        """Bir Telegram chat ID faqat bitta ota-onaga tegishli bo'lishi kerak."""
        other = User.objects.create_user(username="other", password="pass1234")
        TelegramNotificationSetting.objects.create(user=other, chat_id=555111, is_enabled=True)
        self.client.force_authenticate(user=self.parent)

        with patch("parental_control.telegram.is_configured", return_value=True), patch(
            "parental_control.telegram.get_chat", return_value={"id": 555111}
        ):
            response = self.client.put(self.url, {"chat_id": 555111}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class DeviceClaimTestCase(APITestCase):
    def setUp(self):
        self.parent = User.objects.create_user(username="cparent", password="pass1234")
        self.url = reverse("device_claim")

    def test_unpaired_device_gets_no_token(self):
        ChildDevice.objects.create(device_identifier="dev-unpaired")
        response = self.client.post(
            self.url, {"device_identifier": "dev-unpaired"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data["is_paired"])
        self.assertNotIn("device_token", response.data)

    def test_paired_device_claims_token(self):
        device = ChildDevice.objects.create(
            device_identifier="dev-paired", parent=self.parent, is_active=True
        )
        response = self.client.post(
            self.url, {"device_identifier": "dev-paired"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["is_paired"])
        self.assertEqual(response.data["device_id"], str(device.id))
        # `claim` tokenni yangiladi, shuning uchun obyektni bazadan qayta o'qiymiz
        device.refresh_from_db()
        self.assertTrue(device.verify_device_token(response.data["device_token"]))

    def test_unknown_device_identifier(self):
        response = self.client.post(self.url, {"device_identifier": "nope"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data["is_paired"])

    def test_missing_identifier(self):
        response = self.client.post(self.url, {}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class DeviceEventTestCase(APITestCase):
    def setUp(self):
        self.parent = User.objects.create_user(username="eparent", password="pass1234")
        self.device = ChildDevice.objects.create(
            device_identifier="dev-events",
            device_name="Farzand",
            parent=self.parent,
            is_active=True,
        )
        self.token = self.device.generate_device_token()
        self.auth = f"DeviceBearer {self.device.id}:{self.token}"
        self.url = reverse("device_event_create")

    def test_requires_device_bearer(self):
        response = self.client.post(self.url, {}, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    @patch("parental_control.telegram.send_message", return_value=True)
    def test_event_created_and_delivered(self, mock_send):
        TelegramNotificationSetting.objects.create(
            user=self.parent, chat_id=777, is_enabled=True
        )
        response = self.client.post(
            self.url,
            {"event_type": "sos", "message": "SOS bosing!", "data": {}},
            format="json",
            HTTP_AUTHORIZATION=self.auth,
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(response.data["delivered_to_telegram"])
        self.assertEqual(DeviceEvent.objects.count(), 1)
        self.assertEqual(mock_send.call_count, 1)

    @patch("parental_control.telegram.send_message", return_value=True)
    def test_event_saved_even_if_telegram_fails(self, mock_send):
        """Telegram nosoz bo'lsa ham hodisa bazada saqlanib qolishi SHART."""
        mock_send.side_effect = Exception("telegram down")
        response = self.client.post(
            self.url,
            {"event_type": "battery_low", "message": "Batareya 12%"},
            format="json",
            HTTP_AUTHORIZATION=self.auth,
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertFalse(response.data["delivered_to_telegram"])
        self.assertEqual(DeviceEvent.objects.count(), 1)

    def test_not_delivered_when_setting_disabled(self):
        response = self.client.post(
            self.url,
            {"event_type": "admin_disabled", "message": "Himoya o'chirildi"},
            format="json",
            HTTP_AUTHORIZATION=self.auth,
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertFalse(response.data["delivered_to_telegram"])

    def test_invalid_event_type_rejected(self):
        response = self.client.post(
            self.url,
            {"event_type": "read_all_chats", "message": "..."},
            format="json",
            HTTP_AUTHORIZATION=self.auth,
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch("parental_control.telegram.send_message", return_value=True)
    def test_pairing_creates_paired_event(self, _mock_send):
        TelegramNotificationSetting.objects.create(
            user=self.parent, chat_id=777, is_enabled=True
        )
        other = ChildDevice.objects.create(device_identifier="dev-new-pair")
        code = other.generate_pairing_code()
        self.client.force_authenticate(user=self.parent)

        response = self.client.post(
            reverse("device_pair"), {"pairing_code": code}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(
            DeviceEvent.objects.filter(
                device=other, event_type=DeviceEvent.EVENT_PAIRED
            ).exists()
        )

    @patch("parental_control.telegram.send_message", return_value=True)
    def test_blocking_app_records_event(self, mock_send):
        """Ota-ona ilovani bloklaganda hodisa tarixga yoziladi."""
        from .models import InstalledApp

        TelegramNotificationSetting.objects.create(
            user=self.parent, chat_id=777, is_enabled=True
        )
        app = InstalledApp.objects.create(
            device=self.device, package_name="com.instagram", app_name="Instagram"
        )
        self.client.force_authenticate(user=self.parent)

        response = self.client.patch(
            f"/api/v1/devices/{self.device.id}/apps/{app.id}/",
            {"is_blocked": True},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        app.refresh_from_db()
        self.assertTrue(app.is_blocked)
        self.assertTrue(
            DeviceEvent.objects.filter(
                device=self.device, event_type=DeviceEvent.EVENT_APP_BLOCKED
            ).exists()
        )
        self.assertEqual(mock_send.call_count, 1)

    @patch("parental_control.telegram.send_message", return_value=True)
    def test_unrelated_field_update_creates_no_event(self, mock_send):
        """`is_blocked` o'zgarmasa, hodisa yaratilmasligi kerak."""
        from .models import InstalledApp

        app = InstalledApp.objects.create(
            device=self.device, package_name="com.telegram", app_name="Telegram"
        )
        self.client.force_authenticate(user=self.parent)

        response = self.client.patch(
            f"/api/v1/devices/{self.device.id}/apps/{app.id}/",
            {"app_name": "Telegram"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(DeviceEvent.objects.count(), 0)
        self.assertEqual(mock_send.call_count, 0)


class RetryPendingTestCase(APITestCase):
    def setUp(self):
        from . import notifications

        self.notifications = notifications
        self.parent = User.objects.create_user(username="rparent", password="pass1234")
        self.device = ChildDevice.objects.create(
            device_identifier="dev-retry", parent=self.parent, is_active=True
        )
        TelegramNotificationSetting.objects.create(
            user=self.parent, chat_id=777, is_enabled=True
        )

    @patch("parental_control.telegram.send_message", return_value=True)
    def test_pending_event_is_retried(self, mock_send):
        event = DeviceEvent.objects.create(
            device=self.device, event_type=DeviceEvent.EVENT_SOS, message="SOS"
        )
        self.assertEqual(self.notifications.retry_pending(), 1)
        event.refresh_from_db()
        self.assertTrue(event.is_delivered)

    @patch("parental_control.telegram.send_message", return_value=True)
    def test_already_delivered_not_resent(self, mock_send):
        DeviceEvent.objects.create(
            device=self.device,
            event_type=DeviceEvent.EVENT_SOS,
            message="SOS",
            is_delivered=True,
        )
        self.assertEqual(self.notifications.retry_pending(), 0)
        self.assertFalse(mock_send.called)

    @patch("parental_control.telegram.send_message", return_value=True)
    def test_events_without_telegram_setting_are_skipped(self, mock_send):
        TelegramNotificationSetting.objects.filter(user=self.parent).update(
            is_enabled=False
        )
        DeviceEvent.objects.create(
            device=self.device, event_type=DeviceEvent.EVENT_SOS, message="SOS"
        )
        self.assertEqual(self.notifications.retry_pending(), 0)
        self.assertFalse(mock_send.called)
