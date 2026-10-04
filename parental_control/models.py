import hashlib
import secrets
import uuid
from datetime import timedelta
from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone

# Pairing code qancha vaqt amal qiladi. Sozlamalar orqali o'zgartirilishi mumkin.
PAIRING_CODE_TTL = timedelta(minutes=30)


class ChildDevice(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    parent = models.ForeignKey(User, on_delete=models.CASCADE, related_name="devices", null=True, blank=True)
    device_identifier = models.CharField(max_length=255, unique=True)
    device_name = models.CharField(max_length=255, blank=True)
    # Qurilma qaysi farzandga tegishli. Bitta farzand bir nechta qurilma
    # ishlatishi mumkin (telefon + planshet) — boshqaruv panelida shu nom
    # bo'yicha guruhlanadi. Bo'sh bo'lsa, eski ma'lumot `device_name` dan
    # olinadi.
    child_name = models.CharField(max_length=120, blank=True, default="")
    pairing_code = models.CharField(max_length=6, blank=True, null=True, db_index=True)
    pairing_code_expires_at = models.DateTimeField(blank=True, null=True)
    device_token_hash = models.CharField(max_length=64, blank=True, null=True, db_index=True)
    is_active = models.BooleanField(default=False)
    battery_level = models.FloatField(blank=True, null=True)
    last_seen = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["pairing_code"]),
            models.Index(fields=["device_token_hash"]),
        ]

    def generate_pairing_code(self):
        code = secrets.randbelow(1000000)
        self.pairing_code = f"{code:06d}"
        self.pairing_code_expires_at = timezone.now() + PAIRING_CODE_TTL
        self.save(update_fields=["pairing_code", "pairing_code_expires_at"])
        return self.pairing_code

    def verify_pairing_code(self, code):
        if not self.pairing_code or not self.pairing_code_expires_at:
            return False
        if timezone.now() > self.pairing_code_expires_at:
            return False
        if self.pairing_code != code:
            return False
        return True

    def clear_pairing_code(self):
        self.pairing_code = None
        self.pairing_code_expires_at = None
        self.save(update_fields=["pairing_code", "pairing_code_expires_at"])

    @property
    def is_paired(self):
        """Ota-ona shu qurilma bilan bog'langanmi."""
        return self.parent_id is not None and self.is_active

    @property
    def display_child_name(self):
        """Boshqaruv panelida ko'rsatiladigan farzand nomi.

        `child_name` ota-ona tomonidan qo'yiladi. Uni o'zgartirmaganlar uchun
        `device_name` ga qaytamiz — aks holda panelda "Nomsiz" bo'lib qolardi.
        """
        return self.child_name or self.device_name or ""

    @property
    def pairing_code_is_valid(self):
        if not self.pairing_code or not self.pairing_code_expires_at:
            return False
        return timezone.now() <= self.pairing_code_expires_at

    def attach_parent(self, parent):
        """Ota-onani qurilmaga bog'lash.

        Nima uchun alohida metod: bu modeldagi boshqa holat o'zgarish
        metodlari (`clear_pairing_code`, `generate_device_token`,
        `update_last_seen`) `save(update_fields=[...])` bilan saqlaydi. Ularning
        ro'yxatida `parent` YO'Q — ya'ni ular chaqirilganda bu yerda o'rnatilgan
        `parent` bazaga yozilmaydi, faqat xotirada qoladi.

        Bu xato juda yashirin edi va butun ilovani ishdan chiqardi:

        - `DevicePairView` pairingni muvaffaqiyatli deb hisoblar (200 + token),
        - Telegram'ga "Qurilma ulandi" xabari keladi,
        - lekin bazada `parent` NULL qoladi, shuning uchun
          `GET /devices/` (`filter(parent=request.user)`) bo'sh qaytadi,
        - boshqaruv panelida farzand ko'rinmaydi,
        - `DeviceClaimView` ham `is_paired == False` deb qaraydi, ya'ni
          farzand ilovasi token olmaydi va hech qanday ma'lumot yubormaydi.

        Ya'ni foydalanuvchi "ulandi, lekin hech narsa chiqmayapti" holatini
        ko'radi. Shu sababli `parent` o'zgarishi avval alohida yoziladi —
        keyingi `update_fields` chaqiruvlari uni tegmaydi.
        """
        self.parent = parent
        self.save(update_fields=["parent"])

    def generate_device_token(self):
        token = secrets.token_urlsafe(48)
        self.device_token_hash = hashlib.sha256(token.encode()).hexdigest()
        self.is_active = True
        self.save(update_fields=["device_token_hash", "is_active"])
        return token

    def verify_device_token(self, token):
        if not self.device_token_hash:
            return False
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        return secrets.compare_digest(token_hash, self.device_token_hash)

    def update_last_seen(self):
        self.last_seen = timezone.now()
        self.save(update_fields=["last_seen"])

    def __str__(self):
        # `parent` NULL bo'lishi mumkin: qurilma ro'yxatdan o'tgan, lekin
        # ota-ona uni hali ulamagan. Aks holda `self.parent.username` None
        # bo'yicha xato berib, butun admin sahifasini (barcha qurilmalar
        # ro'yxati) ochib bo'lmaydigan qiladi.
        owner = self.parent.username if self.parent else "ulangan emas"
        return f"{self.device_name or self.device_identifier} ({owner})"


class LocationLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="location_logs")
    latitude = models.FloatField()
    longitude = models.FloatField()
    accuracy = models.FloatField(blank=True, null=True)
    recorded_at = models.DateTimeField(db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["device", "recorded_at"]),
        ]

    def __str__(self):
        return f"{self.device} - {self.recorded_at}"


class InstalledApp(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="installed_apps")
    app_name = models.CharField(max_length=255)
    package_name = models.CharField(max_length=255)
    is_blocked = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("device", "package_name")
        indexes = [
            models.Index(fields=["device"]),
        ]

    def __str__(self):
        return f"{self.package_name} ({self.device})"


class AppUsageLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="app_usage_logs")
    package_name = models.CharField(max_length=255)
    total_time_in_foreground_ms = models.BigIntegerField()
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    recorded_at = models.DateTimeField(db_index=True)

    class Meta:
        indexes = [
            models.Index(fields=["device", "recorded_at"]),
        ]

    def __str__(self):
        return f"{self.package_name} - {self.recorded_at}"


class NotificationLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="notification_logs")
    package_name = models.CharField(max_length=255)
    title = models.CharField(max_length=255, blank=True)
    text = models.TextField(blank=True)
    recorded_at = models.DateTimeField(db_index=True)

    class Meta:
        indexes = [
            models.Index(fields=["device", "recorded_at"]),
        ]

    def __str__(self):
        return f"{self.package_name} - {self.recorded_at}"


class GeoZone(models.Model):
    """Xavfsizlik zonasi: bolaning bo'lishi kerak bo'lgan joy.

    DIQQAT: `AccessibilityTextLog` modeli 2026-10 da olib tashlandi — u ekran
    matnini saqlash kanali edi. Android ilovasi hech qachon to'ldirmagan
    (`canRetrieveWindowContent="false"`), ya'ni o'lik tuzilmish edi.

    Xarita: ilova Carto raster plitkalaridan foydalanadi (`flutter_map`).
    Google Maps API key kerak emas — Carto kaliti ochiq (public) bo'lib,
    APK ichida saqlanishi mo'ljallangan.

    `latitude`/`longitude` avval yo'q edi — faqat nom va radius bor edi, ya'ni
    "qayerda" degan savolga javob berib bo'lmasdi.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="zones")
    name = models.CharField(max_length=255)
    latitude = models.FloatField(default=0.0)
    longitude = models.FloatField(default=0.0)
    radius_meters = models.FloatField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} - {self.device}"


class AppTimeLimit(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="limits")
    package_name = models.CharField(max_length=255)
    max_daily_minutes = models.IntegerField()
    block_after_time = models.TimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.package_name} - {self.device}"


class Contact(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="contacts")
    contact_name = models.CharField(max_length=255)
    phone_number = models.CharField(max_length=255)
    is_new = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.contact_name} - {self.device}"


class SOSAlert(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(ChildDevice, on_delete=models.CASCADE, related_name="sos_alerts")
    latitude = models.FloatField()
    longitude = models.FloatField()
    resolved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"SOS - {self.device} at {self.created_at}"


class TelegramNotificationSetting(models.Model):
    """Ota-onaning Telegram orqali bildirishnoma olishi sozlamalari.

    Bot tokeni bu yerda emas — u faqat server sozlamalarida (`TELEGRAM_BOT_TOKEN`)
    saqlanadi. Shu yerda faqat ota-onaning o'z chat ID si bor.
    """

    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="telegram_setting"
    )
    # Telegram chat ID si 32-bit chegaradan oshishi mumkin (-100... guruhlar),
    # shuning uchun BigInteger.
    chat_id = models.BigIntegerField(null=True, blank=True)
    chat_title = models.CharField(max_length=255, blank=True)
    is_enabled = models.BooleanField(default=False)
    last_sent_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Telegram bildirishnoma sozlamasi"
        verbose_name_plural = "Telegram bildirishnoma sozlamalari"

    def __str__(self):
        return f"Telegram: {self.user.username} ({self.chat_id})"


class DeviceEvent(models.Model):
    """Qurilma tomonidan xabar beriladigan hodisalar.

    DIQQAT: bu OLOVLAR ILOVA va qurilma holati hodisalari (ulandi, bloklandi,
    SOS, batareya, zonadan chiqdi). Boshqa ilovalarning ichki xabarlari yoki
    chat yozishmalari bu modelga KIRMAYDI.
    """

    EVENT_PAIRED = "paired"
    EVENT_UNPAIRED = "unpaired"
    EVENT_SOS = "sos"
    EVENT_BATTERY_LOW = "battery_low"
    EVENT_ADMIN_DISABLED = "admin_disabled"
    EVENT_ADMIN_ENABLED = "admin_enabled"
    EVENT_CHILD_MODE_ENABLED = "child_mode_enabled"
    EVENT_ZONE_EXIT = "zone_exit"
    EVENT_APP_BLOCKED = "app_blocked"
    EVENT_APP_UNBLOCKED = "app_unblocked"

    EVENT_TYPE_CHOICES = [
        (EVENT_PAIRED, "Qurilma ulandi"),
        (EVENT_UNPAIRED, "Qurilma uzildi"),
        (EVENT_SOS, "SOS signali"),
        (EVENT_BATTERY_LOW, "Batareya qullab qolmoqda"),
        (EVENT_ADMIN_DISABLED, "Himoya o'chirildi"),
        (EVENT_ADMIN_ENABLED, "Himoya yoqildi"),
        (EVENT_CHILD_MODE_ENABLED, "Farzand rejimi yoqildi"),
        (EVENT_ZONE_EXIT, "Xavfsizlik zonasidan chiqdi"),
        (EVENT_APP_BLOCKED, "Ilova bloklandi"),
        (EVENT_APP_UNBLOCKED, "Ilova blokdan chiqarildi"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey(
        ChildDevice, on_delete=models.CASCADE, related_name="events"
    )
    event_type = models.CharField(max_length=40, choices=EVENT_TYPE_CHOICES)
    message = models.TextField()
    data = models.JSONField(default=dict, blank=True)
    is_delivered = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["device", "created_at"]),
            models.Index(fields=["is_delivered", "created_at"]),
        ]

    def __str__(self):
        return f"{self.get_event_type_display()} - {self.device} ({self.created_at})"
