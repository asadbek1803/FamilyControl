from datetime import timedelta
from io import StringIO

from django.contrib.auth.models import User
from django.core.management import call_command
from django.urls import reverse
from django.utils import timezone
from rest_framework import status

from .models import ChildDevice, LocationLog
from .tests_base import BaseAPITestCase


class PairingFlowTestCase(BaseAPITestCase):
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
        # `parent` ham baza bo'lishi SHART. Bu assertsiz test shu xatoni
        # o'tkazib yuboradi: pairing 200 qaytaradi, Telegram xabari ketadi,
        # `is_active` True bo'ladi — lekin `parent` NULL qoladi va ota-ona
        # qurilmani hech qayerda ko'rmaydi (2026-10 da shunday chiqdi).
        self.assertEqual(device.parent, self.parent)

    def test_pairing_makes_device_visible_in_list(self):
        """REGRESSIYA: pairing'dan keyin qurilma ota-onaning ro'yxatida
        ko'rinishi kerak — `GET /devices/` bo'sh qaydarmasin."""
        device = ChildDevice.objects.create(
            device_identifier="android-visible",
            device_name="Kid5",
        )
        code = device.generate_pairing_code()
        self.client.force_authenticate(user=self.parent)
        self.client.post(
            reverse("device_pair"),
            {"pairing_code": code},
            format="json",
        )
        response = self.client.get(reverse("device_list"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1, "Pairing'dan keyin ro'yxat bo'sh qoldi")
        self.assertEqual(str(response.data[0]["id"]), str(device.id))

    def test_pairing_lets_child_claim_token(self):
        """REGRESSIYA: ota-ona ulagandan keyin farzand qurilmasi o'z tokenini
        olishi kerak. `is_paired` `parent_id` ga qaraydi, shuning uchun
        `parent` yozilmasa claim ham hech qachon ishlamaydi — ya'ni joylashuv,
        ilovalar, hodisalar umuman yuborilmasdi."""
        device = ChildDevice.objects.create(
            device_identifier="android-claim",
            device_name="Kid6",
        )
        code = device.generate_pairing_code()
        self.client.force_authenticate(user=self.parent)
        self.client.post(
            reverse("device_pair"),
            {"pairing_code": code},
            format="json",
        )
        self.client.force_authenticate(user=None)
        response = self.client.post(
            reverse("device_claim"),
            {"device_identifier": "android-claim"},
            format="json",
        )
        self.assertEqual(response.data["is_paired"], True)
        self.assertTrue(response.data["device_token"])

    def test_device_str_survives_missing_parent(self):
        """`parent` NULL bo'lgan qurilma (register qilingan, lekin ulanmagan)
        admin ro'yxatini buzmasligi kerak — `__str__` `None.username` ga
        urilib, butun `ChildDevice` changelistini 500 qilardi."""
        device = ChildDevice.objects.create(
            device_identifier="android-orphan",
            device_name="Kid7",
        )
        self.assertIsNone(device.parent)
        # `device_name` bo'lsa u afzal ko'riladi; `parent` NULL bo'lganini
        # bildiruvchi matn esa barcha holatda qo'shiladi.
        self.assertIn("Kid7", str(device))
        self.assertIn("ulangan emas", str(device))

    def test_pairing_shows_child_on_dashboard(self):
        """Foydalanuvchining haqiqiy senariyosi: farzand ilovasi kod oladi,
        ota-ona kodni kiritadi va boshqaruv panelida farzandni ko'radi.

        Bu test endi boshqaruv panelining ma'nosini tekshiradi — `dashboard/`
        `filter(parent=request.user)` ga tayanadi, shuning uchun `parent`
        yozilmaganda panel bo'sh qoladi.
        """
        device = ChildDevice.objects.create(
            device_identifier="android-dash",
            device_name="Kid8",
        )
        code = device.generate_pairing_code()
        self.client.force_authenticate(user=self.parent)
        pair = self.client.post(
            reverse("device_pair"), {"pairing_code": code}, format="json"
        )
        self.assertEqual(pair.status_code, status.HTTP_200_OK)

        response = self.client.get(reverse("dashboard"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["summary"]["devices_count"], 1)
        self.assertEqual(len(response.data["children"]), 1)
        child = response.data["children"][0]
        self.assertEqual(child["child_name"], "Kid8")
        self.assertTrue(child["devices"][0]["is_paired"])
        self.assertEqual(str(child["devices"][0]["id"]), str(device.id))

    def test_broken_pairing_can_be_repeated(self):
        """QO'LDA TUZATISH YO'LI: `parent` yozilmay qolgan ("yetim") qurilmani
        ota-ona qayta ulashi MUMKIN bo'lishi kerak — aks holda production'dagi
        yetim qurilmalarni faqat admin orqali o'chirish kerak bo'lardi.

        Holat: `parent is None`, lekin `is_active=True` va token hash bor
        (ya'ni avvalgi pairing 'muvaffaqiyatli' bo'lgan, faqat `parent`
        saqlanmagan). `is_paired` `parent_id` ga qaraydi, shuning uchun
        `register` yangi kod beradi va `pair` qurilmani qabul qiladi.
        """
        device = ChildDevice.objects.create(
            device_identifier="android-broken",
            device_name="Farzand Telefon",
            is_active=True,
        )
        device.generate_device_token()
        self.assertIsNone(device.parent)
        self.assertFalse(device.is_paired, "Yetim qurilma 'ulangan' ko'rinmasin")        # 1) Farzand ilovasi yangi kod oladi
        reg = self.client.post(
            reverse("device_register"),
            {"device_identifier": "android-broken"},
            format="json",
        )
        self.assertEqual(reg.status_code, status.HTTP_200_OK)
        code = reg.data["pairing_code"]

        # 2) Ota-ona shu kodni kiritadi
        self.client.force_authenticate(user=self.parent)
        pair = self.client.post(
            reverse("device_pair"), {"pairing_code": code}, format="json"
        )
        self.assertEqual(pair.status_code, status.HTTP_200_OK)

        device.refresh_from_db()
        self.assertEqual(device.parent, self.parent)
        self.assertTrue(device.is_paired)

        # 3) Endi u ro'yxatda ko'rinadi
        listing = self.client.get(reverse("device_list"))
        self.assertEqual(len(listing.data), 1)



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


class CleanupOrphanDevicesCommandTestCase(BaseAPITestCase):
    """`cleanup_orphan_devices` — ma'lumot o'chradigani uchun alohida tekshiriladi."""

    def setUp(self):
        self.user = User.objects.create_user(username="cleanup_owner", password="pass1234")

    def _make_orphan(self, identifier):
        device = ChildDevice.objects.create(device_identifier=identifier)
        LocationLog.objects.create(
            device=device, latitude=41.3, longitude=69.24, recorded_at=timezone.now()
        )
        return device

    def test_dry_run_does_not_delete(self):
        """`--apply` BERILMAGAN holda hech narsa o'chirilmasligi SHART —
        aks holda kimdir noto'g'ri buyruqni ishga tushirib o'z qurilmasini
        yo'qotadi."""
        self._make_orphan("orphan-dry")
        out = StringIO()
        call_command("cleanup_orphan_devices", stdout=out)
        self.assertIn("orphan-dry", out.getvalue())
        self.assertIn("--apply", out.getvalue())  # keyingi qadam ko'rsatiladi
        self.assertEqual(ChildDevice.objects.count(), 1)

    def test_apply_deletes_device_and_its_data(self):
        """`--apply` qurilmani va uning bog'liq ma'lumotlarini o'chiradi."""
        device = self._make_orphan("orphan-apply")
        self.assertEqual(LocationLog.objects.count(), 1)
        out = StringIO()
        call_command("cleanup_orphan_devices", "--apply", stdout=out)
        self.assertFalse(ChildDevice.objects.filter(pk=device.pk).exists())
        self.assertEqual(LocationLog.objects.count(), 0)

    def test_paired_devices_are_never_touched(self):
        """Ota-onaga ulangan qurilma hech qachon o'chirilmasligi SHART —
        buyruq faqat `parent IS NULL` bilan ishlaydi."""
        paired = ChildDevice.objects.create(
            device_identifier="paired-keep", parent=self.user
        )
        out = StringIO()
        call_command("cleanup_orphan_devices", "--apply", stdout=out)
        self.assertTrue(ChildDevice.objects.filter(pk=paired.pk).exists())
        self.assertIn("Yetim qurilma topilmadi", out.getvalue())

