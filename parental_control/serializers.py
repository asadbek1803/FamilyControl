from rest_framework import serializers
from django.utils import timezone
import uuid
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
    DeviceEvent,
    TelegramNotificationSetting,
)


class DeviceRegisterSerializer(serializers.Serializer):
    device_identifier = serializers.CharField(max_length=255)
    device_name = serializers.CharField(max_length=255, required=False, allow_blank=True)

    def validate_device_identifier(self, value):
        # XAVFSIZLIK: bu endpoint `AllowAny`. Agar allaqach ota-onaga ulangan
        # qurilma uchun yangi kod chiqarib berilsa, `device_identifier`ni bilgan
        # har kim o'z akkauntiga ulab, qurilmani ota-onasidan o'g'irlay oladi.
        existing = ChildDevice.objects.filter(device_identifier=value).first()
        if existing is not None and existing.is_paired:
            raise serializers.ValidationError(
                "Bu qurilma allaqach ota-onaga ulangan. "
                "Ota-onaning ilovasidan qurilmani birinchi o'chirish kerak."
            )
        return value

    def create(self, validated_data):
        device, created = ChildDevice.objects.get_or_create(
            device_identifier=validated_data["device_identifier"],
            defaults={
                "device_name": validated_data.get("device_name", ""),
            },
        )
        if not created:
            if validated_data.get("device_name"):
                device.device_name = validated_data["device_name"]
                device.save(update_fields=["device_name"])
            # Eskirgan yoki noto'g'ri kodlarni tozalab, yangisini chiqaramiz
            device.clear_pairing_code()

        device.generate_pairing_code()
        return device

    def to_representation(self, instance):
        return {
            "device_id": instance.id,
            "device_identifier": instance.device_identifier,
            "pairing_code": instance.pairing_code,
            "expires_at": instance.pairing_code_expires_at,
        }


class DevicePairSerializer(serializers.Serializer):
    pairing_code = serializers.CharField(max_length=6)

    def validate_pairing_code(self, value):
        if not value.isdigit():
            raise serializers.ValidationError("Pairing code must be 6 digits.")
        return value

    def validate(self, attrs):
        pairing_code = attrs["pairing_code"]
        # `select_for_update` — ikki ota-ona bir vaqtda bir kodni ishlatib
        # qurilmani o'z akkauntiga ulashining oldini oladi.
        # Transaction ichida chaqirilishi shart (DevicePairView.post).
        try:
            device = ChildDevice.objects.select_for_update().get(pairing_code=pairing_code)
        except ChildDevice.DoesNotExist:
            raise serializers.ValidationError({"pairing_code": "Ulanish kodi noto'g'ri yoki eskirgan."})

        if not device.verify_pairing_code(pairing_code):
            raise serializers.ValidationError({"pairing_code": "Ulanish kodi muddati tugagan."})

        if device.is_paired:
            raise serializers.ValidationError({"pairing_code": "Bu qurilma allaqach boshqa ota-onaga ulangan."})

        attrs["device"] = device
        return attrs

    def save(self, **kwargs):
        device = self.validated_data["device"]
        device.parent = self.context["request"].user
        device.clear_pairing_code()
        token = device.generate_device_token()
        self.token = token
        return device

    def to_representation(self, instance):
        return {
            "device_id": instance.id,
            "device_token": getattr(self, "token", None),
            "is_active": instance.is_active,
        }


class ClientGeneratedIdMixin(serializers.Serializer):
    """Klient yuborgan `id` ni saqlash.

    XATO: DRF primary key maydonini avtomatik `read_only=True` qiladi, ya'ni
    `validated_data` dan `id` chiqib ketadi. Natijada `bulk_create` har bir
    syncda YANGI tasodifiy UUID yaratadi va `ignore_conflicts=True` hech qachon
    ishga tushmaydi — natijada bir xil log har syncda yana yoziladi
    (baza sekin tortiladi, statistika noto'g'ri chiqadi).

    Tuzatish: `id` ni o'qiladigan (lekin majburiy emas) qilib belgilaymiz —
    mavjud bo'lsa klientning UUID si saqlanadi, bo'lmasa yangisi yaratiladi.
    Shu tarzda batch sync idempotent bo'ladi.

    DIQQAT: bu `serializers.Serializer` dan merosxo'r bo'lishi SHART. Oddiy
    klass bo'lsa, DRF metaclass'i undagi maydonlarni yig'maydi va tuzatish
    jimgina ishlamay qoladi (jimgina `read_only` holatiga qaytadi).
    """

    id = serializers.UUIDField(required=False, default=uuid.uuid4)


class LocationLogSerializer(ClientGeneratedIdMixin, serializers.ModelSerializer):
    class Meta:
        model = LocationLog
        fields = ["id", "latitude", "longitude", "accuracy", "recorded_at"]

    def validate_latitude(self, value):
        if not (-90.0 <= value <= 90.0):
            raise serializers.ValidationError("Latitude must be between -90 and 90.")
        return value

    def validate_longitude(self, value):
        if not (-180.0 <= value <= 180.0):
            raise serializers.ValidationError("Longitude must be between -180 and 180.")
        return value


class InstalledAppSerializer(serializers.ModelSerializer):
    class Meta:
        model = InstalledApp
        fields = ["id", "app_name", "package_name", "is_blocked", "updated_at"]


class AppUsageLogSerializer(ClientGeneratedIdMixin, serializers.ModelSerializer):
    class Meta:
        model = AppUsageLog
        fields = ["id", "package_name", "total_time_in_foreground_ms", "start_time", "end_time", "recorded_at"]

    def validate(self, attrs):
        start_time = attrs.get("start_time")
        end_time = attrs.get("end_time")
        if start_time and end_time and end_time < start_time:
            raise serializers.ValidationError("end_time must be >= start_time")
        return attrs


class NotificationLogSerializer(ClientGeneratedIdMixin, serializers.ModelSerializer):
    class Meta:
        model = NotificationLog
        fields = ["id", "package_name", "title", "text", "recorded_at"]


class AccessibilityTextLogSerializer(
    ClientGeneratedIdMixin, serializers.ModelSerializer
):
    class Meta:
        model = AccessibilityTextLog
        fields = ["id", "package_name", "extracted_text", "context_type", "recorded_at"]

class ChildDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChildDevice
        fields = ['id', 'device_identifier', 'device_name', 'is_active', 'battery_level', 'last_seen', 'created_at']
        read_only_fields = ['id', 'created_at', 'last_seen']

from django.contrib.auth.models import User

class ParentRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['username', 'password', 'email']

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password']
        )
        return user

class GeoZoneSerializer(serializers.ModelSerializer):
    class Meta:
        model = GeoZone
        fields = ["id", "name", "radius_meters", "created_at"]
        read_only_fields = ["id", "created_at"]

class AppTimeLimitSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppTimeLimit
        fields = ["id", "package_name", "max_daily_minutes", "block_after_time", "is_active"]
        read_only_fields = ["id"]

class ContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = Contact
        fields = ["id", "contact_name", "phone_number", "is_new", "updated_at"]
        read_only_fields = ["id", "updated_at"]

class SOSAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = SOSAlert
        fields = ["id", "latitude", "longitude", "resolved", "created_at"]
        read_only_fields = ["id", "created_at"]


class DeviceEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceEvent
        fields = ["id", "event_type", "message", "data", "created_at"]
        read_only_fields = ["id", "created_at"]

    def validate_event_type(self, value):
        valid = {choice for choice, _label in DeviceEvent.EVENT_TYPE_CHOICES}
        if value not in valid:
            raise serializers.ValidationError(
                f"Bunday hodisa turi yo'q. Ruxsat etilgan: {sorted(valid)}"
            )
        return value

    def validate_data(self, value):
        # G'ishtdan tashqari kiritilgan JSON hajmini cheklaymiz
        import json

        if len(json.dumps(value, default=str)) > 4000:
            raise serializers.ValidationError("data maydoni juda katta (limit 4000 belgi).")
        return value


class TelegramNotificationSettingSerializer(serializers.ModelSerializer):
    """Ota-onaning Telegram chat ID sini ulashi.

    Chat ID serverda `getChat` orqali tekshiriladi — shunda "ID to'g'ri" degan
    javob ishonchli bo'ladi (bot faqat o'ziga yozgan chat'larga xabar yubora
    oladi). So'ng test xabari yuboriladi.
    """

    class Meta:
        model = TelegramNotificationSetting
        fields = ["chat_id", "chat_title", "is_enabled", "last_sent_at", "updated_at"]
        read_only_fields = ["chat_title", "last_sent_at", "updated_at"]

    def validate_chat_id(self, value):
        if value is None:
            return value

        from . import telegram

        if not telegram.is_configured():
            raise serializers.ValidationError(
                "Serverda TELEGRAM_BOT_TOKEN sozlanmagan. "
                "Administrator bilan bog'laning."
            )

        chat = telegram.get_chat(value)
        if chat is None:
            raise serializers.ValidationError(
                "Bu chat ID topilmadi yoki bot uni hali tanimaydi. "
                "Avval botga /start yuboring, keyin qayta urinib ko'ring."
            )

        # Bir chat ID faqat bir ota-onaga tegishli bo'lishi kerak
        taken = TelegramNotificationSetting.objects.filter(chat_id=value).exclude(
            user=self.context["request"].user
        )
        if taken.exists():
            raise serializers.ValidationError("Bu Telegram allaqach boshqa akkauntga ulangan.")

        self.context["resolved_chat_title"] = chat.get("title") or chat.get("username") or ""
        return value

    def create(self, validated_data):
        setting, _ = TelegramNotificationSetting.objects.update_or_create(
            user=self.context["request"].user,
            defaults=validated_data,
        )
        setting.chat_title = self.context.get("resolved_chat_title", "")
        setting.save(update_fields=["chat_title"])
        return setting

    def update(self, instance, validated_data):
        instance = super().update(instance, validated_data)
        if self.context.get("resolved_chat_title"):
            instance.chat_title = self.context["resolved_chat_title"]
            instance.save(update_fields=["chat_title"])
        return instance
