"""Qurilma hodisalarini ota-onaning Telegram chat'iga yetkazish."""

import logging
from datetime import timedelta

from django.utils import timezone

from . import telegram
from .models import DeviceEvent, TelegramNotificationSetting

logger = logging.getLogger(__name__)

# Telegram'ga yuboriladigan hodisalar
NOTIFIABLE_EVENTS = {
    DeviceEvent.EVENT_PAIRED,
    DeviceEvent.EVENT_UNPAIRED,
    DeviceEvent.EVENT_SOS,
    DeviceEvent.EVENT_BATTERY_LOW,
    DeviceEvent.EVENT_ADMIN_DISABLED,
    DeviceEvent.EVENT_ADMIN_ENABLED,
    DeviceEvent.EVENT_CHILD_MODE_ENABLED,
    DeviceEvent.EVENT_ZONE_EXIT,
    DeviceEvent.EVENT_APP_BLOCKED,
    DeviceEvent.EVENT_APP_UNBLOCKED,
}


def _format_message(event: DeviceEvent) -> str:
    device_label = event.device.device_name or event.device.device_identifier
    stamp = timezone.localtime(event.created_at).strftime("%Y-%m-%d %H:%M")
    return f"🔔 FamilyControl — {event.get_event_type_display()}\n\n" f"{event.message}\n\n" f"Qurilma: {device_label}\nVaqt: {stamp}"


def notify_parent(device, event_type: str, message: str, data: dict | None = None) -> DeviceEvent:
    """Hodisani bazaga yozadi va Telegram orqali yuborishga urinadi.

    Telegram nosozligi API javobini buzmasligi SHART — shuning uchun har bir
    qadam try/atch ichida va natija `is_delivered` da qayd etiladi.
    """
    event = DeviceEvent.objects.create(
        device=device,
        event_type=event_type,
        message=message,
        data=data or {},
    )

    if event_type not in NOTIFIABLE_EVENTS:
        return event

    setting = TelegramNotificationSetting.objects.filter(
        user=device.parent, is_enabled=True, chat_id__isnull=False
    ).first()
    if setting is None:
        return event

    try:
        delivered = telegram.send_message(setting.chat_id, _format_message(event))
    except Exception:  # noqa: BLE001 — Telegram hech qachon asosiy oqimni buzmasin
        logger.exception("Telegram yuborishda istalnomagan xato")
        delivered = False

    event.is_delivered = delivered
    event.save(update_fields=["is_delivered"])
    if delivered:
        setting.last_sent_at = timezone.now()
        setting.save(update_fields=["last_sent_at"])
    return event


def retry_pending(max_age_days: int = 1, limit: int = 200) -> int:
    """Yuborilmagan hodisalarni qayta yuborish.

    Telegram vaqtincha nosoz bo'lsa yoki server Telegram'ga ulana olmasa,
    hodisa `is_delivered=False` bilan saqlanib qoladi. Ushbu funksiya
    management command orqali (`send_pending_notifications`) chaqiriladi.
    """
    since = timezone.now() - timedelta(days=max_age_days)
    pending = DeviceEvent.objects.filter(
        is_delivered=False, created_at__gte=since, event_type__in=NOTIFIABLE_EVENTS
    )[:limit]

    delivered_count = 0
    for event in pending:
        setting = TelegramNotificationSetting.objects.filter(
            user=event.device.parent, is_enabled=True, chat_id__isnull=False
        ).first()
        if setting is None:
            continue
        try:
            if telegram.send_message(setting.chat_id, _format_message(event)):
                event.is_delivered = True
                event.save(update_fields=["is_delivered"])
                delivered_count += 1
        except Exception:  # noqa: BLE001
            logger.exception("Telegram qayta yuborishda xato")
    return delivered_count
