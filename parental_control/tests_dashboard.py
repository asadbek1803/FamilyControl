"""Boshqaruv paneli (`/dashboard/`) va yangi ota-ona endpoint'larini testlar.

Uchta asosiy narsa tekshiriladi:

1. Panel **faqat ota-onaning o'z** qurilmalarini qaytaradi.
2. Barcha agregatlar (ekran vaqti, bloklangan ilovalar, kontaktlar, zonalar,
   limitlar, SOS) to'g'ri hisoblanadi.
3. So'rovlar soni qurilmalar soniga bog'liq **emas** — aks holda har bir
   farzand uchun alohida o'qish boshlanadi (N+1) va 10 farzandda panel
   sekinlashadi.
"""

from datetime import timedelta

from django.contrib.auth.models import User
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from .tests_base import BaseAPITestCase

from .models import (
    AppTimeLimit,
    AppUsageLog,
    ChildDevice,
    Contact,
    DeviceEvent,
    GeoZone,
    InstalledApp,
    SOSAlert,
)


def _now():
    return timezone.now()


def _backdate(instance, **fields):
    """`auto_now_add=True` maydonlarni `create()` da o'zgartirib bo'lmaydi.

    Django shu maydonlarni har qanday `create()` chaqiruvida e'tiborsiz
    qayta yozadi (`editable=False` hisoblanadi), shuning uchun testda
    `objects.filter(id=...).update(...)` orqali alohida o'zgartirish kerak.
    """
    type(instance).objects.filter(id=instance.id).update(**fields)
    instance.refresh_from_db()


class DashboardTestCase(BaseAPITestCase):
    def setUp(self):
        self.parent = User.objects.create_user(username="dash_parent", password="pass1234")
        self.stranger = User.objects.create_user(username="dash_stranger", password="pass1234")
        self.url = reverse("dashboard")

        self.alisher_phone = ChildDevice.objects.create(
            parent=self.parent,
            device_identifier="dev-alisher-phone",
            device_name="Alisher telefon",
            child_name="Alisher",
            is_active=True,
            battery_level=85.0,
            last_seen=_now(),
        )
        self.gulnara_phone = ChildDevice.objects.create(
            parent=self.parent,
            device_identifier="dev-gulnara-phone",
            device_name="Gulnara telefon",
            child_name="Gulnara",
            is_active=True,
            battery_level=12.0,  # qullab qolmoqda
            last_seen=_now(),
        )
        self.alisher_tablet = ChildDevice.objects.create(
            parent=self.parent,
            device_identifier="dev-alisher-tablet",
            device_name="Alisher planshet",
            child_name="Alisher",  # bir farzand, ikki qurilma
            is_active=False,
            battery_level=None,
            last_seen=_now() - timedelta(days=3),
        )
        self.foreign_device = ChildDevice.objects.create(
            parent=self.stranger,
            device_identifier="dev-foreign",
            device_name="Begona telefon",
            child_name="Begona",
            is_active=True,
        )

        self.client.force_authenticate(user=self.parent)

    # ------------------------------------------------------------------ auth

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_empty_panel_for_new_parent(self):
        newcomer = User.objects.create_user(username="dash_newcomer", password="pass1234")
        self.client.force_authenticate(user=newcomer)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["summary"]["children_count"], 0)
        self.assertEqual(response.data["summary"]["devices_count"], 0)
        self.assertEqual(response.data["children"], [])
        self.assertEqual(response.data["recent_events"], [])

    def test_other_parents_device_not_visible(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = [d["id"] for c in response.data["children"] for d in c["devices"]]
        self.assertNotIn(str(self.foreign_device.id), ids)
        self.assertEqual(response.data["summary"]["devices_count"], 3)

    # -------------------------------------------------------------- grouping

    def test_groups_devices_by_child_name(self):
        response = self.client.get(self.url)
        names = [c["child_name"] for c in response.data["children"]]
        self.assertIn("Alisher", names)
        self.assertIn("Gulnara", names)

        alisher = next(c for c in response.data["children"] if c["child_name"] == "Alisher")
        self.assertEqual(alisher["devices_count"], 2)
        self.assertEqual(alisher["online_count"], 1)

    def test_unnamed_devices_are_not_merged(self):
        """Nom qo'yilmagan ikki qurilma bitta "Nomsiz" guruhiga tushmasligi kerak.

        Aks holda ikki farzandning telefonlari bitta kartada aralashib ketadi
        va ota-ona noto'g'ri qaror qabul qilishi mumkin.
        """
        ChildDevice.objects.create(
            parent=self.parent, device_identifier="dev-anon-1", device_name="Nomsiz 1"
        )
        ChildDevice.objects.create(
            parent=self.parent, device_identifier="dev-anon-2", device_name="Nomsiz 2"
        )

        response = self.client.get(self.url)
        anonymous = [
            c
            for c in response.data["children"]
            if c["child_name"] not in ("Alisher", "Gulnara")
        ]
        self.assertEqual(len(anonymous), 2, "Nomsiz qurilmalar bittaga birlashtirilgan")
        for group in anonymous:
            self.assertEqual(group["devices_count"], 1)

    def test_named_children_sorted_first(self):
        ChildDevice.objects.create(
            parent=self.parent, device_identifier="dev-anon-3", device_name="Anon"
        )
        response = self.client.get(self.url)
        names = [c["child_name"] for c in response.data["children"]]
        # Nomsizlar oxirida bo'lishi kerak
        self.assertNotEqual(names[-1], "Alisher")
        self.assertEqual(names[-1], "Anon")

    # ------------------------------------------------------------ aggregates

    def test_summary_counts(self):
        InstalledApp.objects.create(
            device=self.alisher_phone, app_name="YouTube", package_name="com.youtube"
        )
        InstalledApp.objects.create(
            device=self.alisher_phone, app_name="Telegram", package_name="org.telegram"
        )
        InstalledApp.objects.create(
            device=self.gulnara_phone, app_name="TikTok", package_name="com.tiktok"
        )
        InstalledApp.objects.create(
            device=self.foreign_device, app_name="Yot", package_name="com.foreign", is_blocked=True
        )

        response = self.client.get(self.url)
        summary = response.data["summary"]

        self.assertEqual(summary["children_count"], 2)
        self.assertEqual(summary["devices_count"], 3)
        self.assertEqual(summary["online_count"], 2)
        # Faqat Gulnara 12% -> bitta qurilma
        self.assertEqual(summary["low_battery_count"], 1)
        # Begona qurilmaning bloklangan ilovasi hisobga olinmasligi kerak
        self.assertEqual(summary["blocked_apps_count"], 0)

    def test_device_detail_counts(self):
        InstalledApp.objects.create(
            device=self.alisher_phone, app_name="YouTube", package_name="com.youtube"
        )
        InstalledApp.objects.create(
            device=self.alisher_phone,
            app_name="O'yin",
            package_name="com.game",
            is_blocked=True,
        )
        Contact.objects.create(
            device=self.alisher_phone, contact_name="Do'st", phone_number="+998901234567"
        )
        GeoZone.objects.create(device=self.alisher_phone, name="Maktab", radius_meters=200, latitude=41.3, longitude=69.2)
        AppTimeLimit.objects.create(
            device=self.alisher_phone, package_name="com.game", max_daily_minutes=60
        )
        AppTimeLimit.objects.create(
            device=self.alisher_phone,
            package_name="com.youtube",
            max_daily_minutes=30,
            is_active=False,
        )
        SOSAlert.objects.create(device=self.alisher_phone, latitude=41.3, longitude=69.2)

        response = self.client.get(self.url)
        alisher_phone = _device(response, self.alisher_phone)

        self.assertEqual(alisher_phone["installed_apps_count"], 2)
        self.assertEqual(alisher_phone["blocked_apps_count"], 1)
        self.assertEqual(alisher_phone["contacts_count"], 1)
        self.assertEqual(alisher_phone["zones_count"], 1)
        # Faqat faol limit hisoblanadi
        self.assertEqual(alisher_phone["active_limits_count"], 1)
        self.assertEqual(alisher_phone["active_sos_count"], 1)

    def test_today_screen_time_summed_and_grouped(self):
        AppUsageLog.objects.create(
            device=self.alisher_phone,
            package_name="com.youtube",
            total_time_in_foreground_ms=60_000,
            start_time=_now() - timedelta(hours=2),
            end_time=_now() - timedelta(hours=1),
            recorded_at=_now(),
        )
        AppUsageLog.objects.create(
            device=self.alisher_phone,
            package_name="com.game",
            total_time_in_foreground_ms=30_000,
            start_time=_now() - timedelta(hours=4),
            end_time=_now() - timedelta(hours=3),
            recorded_at=_now(),
        )
        # Alisher planshetda yana 10 sekund
        AppUsageLog.objects.create(
            device=self.alisher_tablet,
            package_name="com.reader",
            total_time_in_foreground_ms=10_000,
            start_time=_now() - timedelta(hours=1),
            end_time=_now(),
            recorded_at=_now(),
        )
        # Ertangi kundagi log hisobga olinmasligi kerak
        AppUsageLog.objects.create(
            device=self.gulnara_phone,
            package_name="com.tiktok",
            total_time_in_foreground_ms=99_000_000,
            start_time=_now() - timedelta(days=2),
            end_time=_now() - timedelta(days=2),
            recorded_at=_now() - timedelta(days=2),
        )

        response = self.client.get(self.url)

        alisher_phone = _device(response, self.alisher_phone)
        self.assertEqual(alisher_phone["today_screen_time_ms"], 90_000)

        alisher = next(c for c in response.data["children"] if c["child_name"] == "Alisher")
        self.assertEqual(alisher["today_screen_time_ms"], 100_000)
        self.assertEqual(response.data["summary"]["today_screen_time_ms"], 100_000)

        gulnara = next(c for c in response.data["children"] if c["child_name"] == "Gulnara")
        self.assertEqual(gulnara["today_screen_time_ms"], 0)

    def test_resolved_sos_does_not_count_as_active(self):
        SOSAlert.objects.create(device=self.alisher_phone, latitude=1, longitude=2)
        SOSAlert.objects.create(
            device=self.alisher_phone, latitude=1, longitude=2, resolved=True
        )

        response = self.client.get(self.url)
        alisher_phone = _device(response, self.alisher_phone)
        self.assertEqual(alisher_phone["active_sos_count"], 1)
        self.assertEqual(response.data["summary"]["active_sos_count"], 1)

    def test_last_event_per_device(self):
        paired = DeviceEvent.objects.create(
            device=self.alisher_phone,
            event_type=DeviceEvent.EVENT_PAIRED,
            message="Ulangan",
        )
        _backdate(paired, created_at=_now() - timedelta(hours=2))
        DeviceEvent.objects.create(
            device=self.alisher_phone,
            event_type=DeviceEvent.EVENT_BATTERY_LOW,
            message="Batareya 10%",
        )

        response = self.client.get(self.url)
        alisher_phone = _device(response, self.alisher_phone)
        self.assertEqual(alisher_phone["last_event_type"], DeviceEvent.EVENT_BATTERY_LOW)
        self.assertEqual(alisher_phone["last_event_message"], "Batareya 10%")

    def test_recent_events_only_own_devices(self):
        DeviceEvent.objects.create(
            device=self.foreign_device,
            event_type=DeviceEvent.EVENT_SOS,
            message="Begona SOS",
        )
        DeviceEvent.objects.create(
            device=self.gulnara_phone,
            event_type=DeviceEvent.EVENT_SOS,
            message="Gulnara SOS",
        )

        response = self.client.get(self.url)
        messages = [e["message"] for e in response.data["recent_events"]]
        self.assertIn("Gulnara SOS", messages)
        self.assertNotIn("Begona SOS", messages)

    def test_device_without_name_does_not_crash(self):
        ChildDevice.objects.create(parent=self.parent, device_identifier="dev-bare")

        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    # ------------------------------------------------------------- N+1 guard

    def test_query_count_does_not_grow_with_devices(self):
        """Panelsiz har bir farzand uchun alohida so'rov YUBORILMASLIGI kerak.

        Bu test regressiya qo'yadi: `for device in devices:` ichida
        `device.apps.count()` yozilsa, so'rovlar soni qurilmalar soni bilan
        chiziqli o'sadi va panel sekinlashadi.

        Solishtirish 1 ta va 4 ta qurilma orasida qilinadi — bo'sh ro'yxat
        (`_empty_payload`) qisqa yo'lni bosib o'tadi va solishtirishni
        buzadi.
        """
        solo = User.objects.create_user(username="dash_solo", password="pass1234")
        ChildDevice.objects.create(
            parent=solo, device_identifier="dev-solo", child_name="Yakka"
        )
        self.client.force_authenticate(user=solo)

        with CaptureQueriesContext(connection) as one_device:
            self.client.get(self.url)
        queries_one = len(one_device.captured_queries)

        # To'rt qurilmali ota-ona
        for index in range(1, 5):
            ChildDevice.objects.create(
                parent=self.parent,
                device_identifier=f"dev-extra-{index}",
                child_name=f"Extra {index}",
            )

        with CaptureQueriesContext(connection) as four_devices:
            self.client.get(self.url)
        queries_four = len(four_devices.captured_queries)

        self.assertGreater(queries_one, 0)
        self.assertEqual(
            queries_one,
            queries_four,
            f"So'rovlar soni qurilmalar soniga bog'liq: "
            f"1 qurilma={queries_one}, 4 qurilma={queries_four}. "
            f"Bu N+1 muammosi.",
        )


class ChildNameTestCase(BaseAPITestCase):
    """`child_name` — qaysi qurilma qaysi farzandniki."""

    def setUp(self):
        self.parent = User.objects.create_user(username="name_parent", password="pass1234")
        self.device = ChildDevice.objects.create(
            parent=self.parent,
            device_identifier="dev-name-1",
            device_name="Xiaomi Redmi 12",
        )
        self.client.force_authenticate(user=self.parent)
        self.url = reverse("device_detail", args=[self.device.id])

    def test_patch_sets_child_name(self):
        response = self.client.patch(self.url, {"child_name": "Madina"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.device.refresh_from_db()
        self.assertEqual(self.device.child_name, "Madina")

    def test_display_name_falls_back_to_device_name(self):
        response = self.client.get(self.url)
        self.assertEqual(response.data["child_name"], "")
        self.assertEqual(response.data["display_child_name"], "Xiaomi Redmi 12")

    def test_display_name_prefers_child_name(self):
        self.device.child_name = "Madina"
        self.device.save(update_fields=["child_name"])
        response = self.client.get(self.url)
        self.assertEqual(response.data["display_child_name"], "Madina")

    def test_child_name_is_trimmed(self):
        response = self.client.patch(self.url, {"child_name": "  Madina  "}, format="json")
        self.assertEqual(response.data["child_name"], "Madina")

    def test_child_name_too_long_rejected(self):
        response = self.client.patch(self.url, {"child_name": "x" * 121}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_device_identifier_is_read_only(self):
        """`device_identifier` o'zgartirilsa, qurilma boshqa bolaga o'tib ketadi."""
        response = self.client.patch(
            self.url, {"device_identifier": "hacked"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.device.refresh_from_db()
        self.assertEqual(self.device.device_identifier, "dev-name-1")


class SOSListTestCase(BaseAPITestCase):
    """SOS signall tarixi — ota-ona ilovada ko'rishi va yopishi kerak."""

    def setUp(self):
        self.parent = User.objects.create_user(username="sos_parent", password="pass1234")
        self.other = User.objects.create_user(username="sos_other", password="pass1234")
        self.device = ChildDevice.objects.create(
            parent=self.parent, device_identifier="dev-sos-1", child_name="Ali"
        )
        self.foreign = ChildDevice.objects.create(
            parent=self.other, device_identifier="dev-sos-2"
        )
        self.client.force_authenticate(user=self.parent)
        self.url = reverse("sos_list_create", args=[self.device.id])

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        self.assertEqual(self.client.get(self.url).status_code, 401)

    def test_lists_alerts_of_own_device(self):
        SOSAlert.objects.create(device=self.device, latitude=41.3, longitude=69.2)
        SOSAlert.objects.create(device=self.device, latitude=41.4, longitude=69.3, resolved=True)
        SOSAlert.objects.create(device=self.foreign, latitude=0, longitude=0)

        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)

    def test_unresolved_filter(self):
        SOSAlert.objects.create(device=self.device, latitude=1, longitude=1)
        SOSAlert.objects.create(device=self.device, latitude=1, longitude=1, resolved=True)

        response = self.client.get(self.url, {"unresolved": "1"})
        self.assertEqual(len(response.data), 1)
        self.assertFalse(response.data[0]["resolved"])

    def test_mark_resolved(self):
        alert = SOSAlert.objects.create(device=self.device, latitude=1, longitude=1)
        detail = reverse("sos_detail", args=[self.device.id, alert.id])

        response = self.client.patch(detail, {"resolved": True}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        alert.refresh_from_db()
        self.assertTrue(alert.resolved)

    def test_cannot_resolve_other_parents_alert(self):
        alert = SOSAlert.objects.create(device=self.foreign, latitude=1, longitude=1)
        detail = reverse("sos_detail", args=[self.device.id, alert.id])
        self.assertEqual(self.client.patch(detail, {"resolved": True}, format="json").status_code, 404)

    def test_create_still_works(self):
        response = self.client.post(self.url, {"latitude": 41.3, "longitude": 69.2}, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(SOSAlert.objects.count(), 1)


class EventFilterTestCase(BaseAPITestCase):
    """Hodisa tarixi filtrlari."""

    def setUp(self):
        self.parent = User.objects.create_user(username="evt_parent", password="pass1234")
        self.device = ChildDevice.objects.create(
            parent=self.parent, device_identifier="dev-evt-1", child_name="Ali"
        )
        self.client.force_authenticate(user=self.parent)
        self.url = reverse("device_events_list", args=[self.device.id])

        paired = DeviceEvent.objects.create(
            device=self.device, event_type=DeviceEvent.EVENT_SOS, message="SOS 1"
        )
        _backdate(paired, created_at=_now() - timedelta(minutes=10))
        battery = DeviceEvent.objects.create(
            device=self.device, event_type=DeviceEvent.EVENT_BATTERY_LOW, message="Batareya"
        )
        _backdate(battery, created_at=_now() - timedelta(minutes=5))
        old = DeviceEvent.objects.create(
            device=self.device, event_type=DeviceEvent.EVENT_SOS, message="Eski SOS"
        )
        _backdate(old, created_at=_now() - timedelta(days=30))

    def test_all_events_by_default(self):
        self.assertEqual(len(self.client.get(self.url).data), 3)

    def test_filter_by_event_type(self):
        response = self.client.get(self.url, {"event_type": "sos"})
        messages = [e["message"] for e in response.data]
        self.assertEqual(messages, ["SOS 1", "Eski SOS"])

    def test_filter_by_days(self):
        response = self.client.get(self.url, {"days": 7})
        messages = [e["message"] for e in response.data]
        self.assertNotIn("Eski SOS", messages)
        self.assertEqual(len(messages), 2)

    def test_invalid_event_type_returns_empty_not_error(self):
        response = self.client.get(self.url, {"event_type": "no_such_event"})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_invalid_days_returns_empty_not_error(self):
        response = self.client.get(self.url, {"days": "keegan"})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_newest_first(self):
        """Tartib `-created_at` bo'yicha: Batareya (5 daq) -> SOS 1 (10 daq) -> Eski."""
        messages = [e["message"] for e in self.client.get(self.url).data]
        self.assertEqual(messages, ["Batareya", "SOS 1", "Eski SOS"])


class ZoneAndContactDetailTestCase(BaseAPITestCase):
    """Zona va kontaktlarni tahrirlash/o'chirish (avval faqat `POST` bor edi)."""

    def setUp(self):
        self.parent = User.objects.create_user(username="zc_parent", password="pass1234")
        self.other = User.objects.create_user(username="zc_other", password="pass1234")
        self.device = ChildDevice.objects.create(
            parent=self.parent, device_identifier="dev-zc-1", child_name="Ali"
        )
        self.foreign = ChildDevice.objects.create(
            parent=self.other, device_identifier="dev-zc-2"
        )
        self.client.force_authenticate(user=self.parent)

    def test_zone_update_and_delete(self):
        zone = GeoZone.objects.create(
            device=self.device,
            name="Maktab",
            radius_meters=150,
            latitude=41.311,
            longitude=69.240,
        )
        detail = reverse("geozone_detail", args=[self.device.id, zone.id])

        response = self.client.patch(detail, {"radius_meters": 400}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        zone.refresh_from_db()
        self.assertEqual(zone.radius_meters, 400)

        self.assertEqual(self.client.delete(detail).status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(GeoZone.objects.filter(id=zone.id).exists())

    def test_zone_create_requires_coordinates(self):
        """(0, 0) — Osiyo chekkasidagi nuqta, ota-onaning xatosi. Qabul qilinmasligi kerak."""
        url = reverse("geozone_list", args=[self.device.id])
        response = self.client.post(
            url, {"name": "Xato", "radius_meters": 200, "latitude": 0, "longitude": 0},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("latitude", response.data)

    def test_zone_create_rejects_out_of_range_radius(self):
        url = reverse("geozone_list", args=[self.device.id])
        response = self.client.post(
            url,
            {"name": "Xato", "radius_meters": 999999, "latitude": 41.3, "longitude": 69.2},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("radius_meters", response.data)

    def test_zone_create_success(self):
        url = reverse("geozone_list", args=[self.device.id])
        response = self.client.post(
            url,
            {
                "name": "Maktab",
                "radius_meters": 250,
                "latitude": 41.311,
                "longitude": 69.240,
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["radius_meters"], 250.0)

    def test_zone_of_other_parent_not_reachable(self):
        zone = GeoZone.objects.create(
            device=self.foreign, name="Begona", radius_meters=10,
            latitude=41.3, longitude=69.2,
        )
        detail = reverse("geozone_detail", args=[self.device.id, zone.id])
        self.assertEqual(self.client.patch(detail, {"name": "x"}, format="json").status_code, 404)

    def test_zones_are_newest_first(self):
        first = GeoZone.objects.create(
            device=self.device, name="Birinchi", radius_meters=10,
            latitude=41.3, longitude=69.2,
        )
        GeoZone.objects.create(
            device=self.device, name="Ikkinchi", radius_meters=10,
            latitude=41.3, longitude=69.2,
        )
        # `created_at` `auto_now_add` — `create()` da berib bo'lmaydi
        _backdate(first, created_at=_now() - timedelta(days=1))

        response = self.client.get(reverse("geozone_list", args=[self.device.id]))
        self.assertEqual(response.data[0]["name"], "Ikkinchi")

    def test_time_limit_rejects_absurd_value(self):
        url = reverse("apptimelimit_list", args=[self.device.id])
        response = self.client.post(
            url, {"package_name": "com.game", "max_daily_minutes": 99999}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_contact_update_and_delete(self):
        contact = Contact.objects.create(
            device=self.device, contact_name="Ali", phone_number="+998901111111"
        )
        detail = reverse("contact_detail", args=[self.device.id, contact.id])

        response = self.client.patch(detail, {"is_new": False}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        contact.refresh_from_db()
        self.assertFalse(contact.is_new)

        self.assertEqual(self.client.delete(detail).status_code, status.HTTP_204_NO_CONTENT)

    def test_contact_of_other_parent_not_reachable(self):
        contact = Contact.objects.create(
            device=self.foreign, contact_name="Begona", phone_number="+1"
        )
        detail = reverse("contact_detail", args=[self.device.id, contact.id])
        self.assertEqual(self.client.patch(detail, {"contact_name": "x"}, format="json").status_code, 404)

    def test_time_limit_delete(self):
        limit = AppTimeLimit.objects.create(
            device=self.device, package_name="com.game", max_daily_minutes=60
        )
        detail = reverse("apptimelimit_detail", args=[self.device.id, limit.id])
        self.assertEqual(self.client.delete(detail).status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(AppTimeLimit.objects.filter(id=limit.id).exists())


def _device(dashboard_response, device):
    """Testda qulaylik: panel javobidan bitta qurilmani topish."""
    for child in dashboard_response.data["children"]:
        for item in child["devices"]:
            if item["id"] == str(device.id):
                return item
    raise AssertionError(f"Qurilma panel javobida topilmadi: {device.id}")