"""Ota-onaning boshqaruv paneli (`GET /dashboard/`).

Nima uchun alohida fayl
------------------------
`views_parent.py` allaqach qurilma qurilma qilib o'tgan. Panel barcha
qurilmalarni BIR so'rovda qaytaradi — bu boshqa barcha bo'limlardan farqli
o'laroq "bir qurilma tanlash" qadamini talab qilmaydi.

N+1 muammosi
-------------
Ota-onada 5 ta farzand, har birida 6 ta agregat (ilovalar, kontaktlar,
zonalar, limitlar, SOS, ekran vaqti) bo'lsa, `for device in devices:` ichida
`device.apps.count()` yozsak 30+ so'rov yuboriladi. Bu yerda barcha agregatlar
`values('device_id').annotate(...)` bilan bittadan o'qiladi — jami 7 so'rov,
qurilmalar sonidan qat'i nazar.

Ma'lumot chegarasi
------------------
Bu endpoint FAQAT ilova va qurilma holatini qaytaradi (batareya, faollik,
bloklangan ilovalar soni, ekran vaqti, SOS, hodisa tarixi). Boshqa
ilovalarning xabarlari yoki chat yozishmalari bu yerga KIRMAYDI.
"""

from datetime import datetime, time as dt_time

from django.db.models import Count, Max, Q, Sum
from django.utils import timezone
from rest_framework import permissions
from rest_framework.response import Response
from rest_framework.views import APIView

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
from .serializers import ParentDashboardSerializer

# Batareya "qullab qolmoqda" deb hisoblanadigan daraja (%).
LOW_BATTERY_PERCENT = 20

# Panel oxirida ko'rsatiladigan oxirgi hodisalar soni.
RECENT_EVENTS_LIMIT = 20


class ParentDashboardView(APIView):
    """Ota-onaning barcha farzandlari bir javobda.

    GET -> {
        "generated_at": "...",
        "summary":  { ... },          # umumiy raqamlar
        "children": [ { ... } ],      # farzand -> qurilmalar
        "recent_events": [ ... ]      # oxirgi hodisalar (barcha qurilmalar)
    }
    """

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        devices = list(
            ChildDevice.objects.filter(parent=request.user).order_by(
                "child_name", "device_name", "created_at"
            )
        )

        if not devices:
            return Response(self._empty_payload())

        device_ids = [d.id for d in devices]
        day_start = self._day_start()

        usage_today = self._usage_today(device_ids, day_start)
        app_stats = self._app_stats(device_ids)
        contact_counts = self._count_by_device(Contact, device_ids)
        zone_counts = self._count_by_device(GeoZone, device_ids)
        limit_counts = self._active_limit_counts(device_ids)
        sos_stats = self._sos_stats(device_ids)

        # Oxirgi hodisa: `distinct('device_id')` faqat PostgreSQL'da ishlaydi,
        # SQLite'da esa (testlar uchun) xato beradi. Shuning uchun portativ
        # yo'l: jami 200 ta yaqin hodisa yuklab, `device_id` bo'yicha
        # birinchisini olamiz (ro'yxat `-created_at` bo'yiya tartiblangan).
        events = list(
            DeviceEvent.objects.filter(device_id__in=device_ids)
            .select_related("device")
            .order_by("-created_at")[:200]
        )
        last_event_by_device = {}
        for event in events:
            last_event_by_device.setdefault(event.device_id, event)

        children = []
        totals = {
            "devices_count": len(devices),
            "online_count": 0,
            "low_battery_count": 0,
            "blocked_apps_count": 0,
            "active_sos_count": 0,
            "today_screen_time_ms": 0,
        }
        groups = {}

        for device in devices:
            stats = app_stats.get(device.id, {"installed": 0, "blocked": 0})
            sos = sos_stats.get(device.id, {"active": 0, "last": None})
            usage = usage_today.get(device.id, 0)
            last_event = last_event_by_device.get(device.id)

            battery = device.battery_level
            is_online = device.is_active

            # Nom bo'lmasa har bir qurilma o'z guruhida turadi: nomi yo'q ikki
            # qurilma (ikki farzand) bitta "Nomsiz" guruhiga tushib, ota-onani
            # chalg'itmasligi kerak.
            if device.child_name.strip():
                group_key = device.child_name.strip()
            else:
                group_key = f"__device__:{device.id}"

            label = (
                device.child_name.strip()
                or device.device_name.strip()
                or "Nomsiz farzand"
            )

            summary = {
                "id": str(device.id),
                "device_name": device.device_name or device.device_identifier,
                "child_name": label,
                "is_active": is_online,
                "is_paired": device.is_paired,
                "battery_level": battery,
                "last_seen": device.last_seen,
                "today_screen_time_ms": usage,
                "installed_apps_count": stats["installed"],
                "blocked_apps_count": stats["blocked"],
                "contacts_count": contact_counts.get(device.id, 0),
                "zones_count": zone_counts.get(device.id, 0),
                "active_limits_count": limit_counts.get(device.id, 0),
                "active_sos_count": sos["active"],
                "last_sos_at": sos["last"],
                "last_event_type": last_event.event_type if last_event else None,
                "last_event_message": last_event.message if last_event else None,
                "last_event_at": last_event.created_at if last_event else None,
            }

            group = groups.setdefault(
                group_key,
                {
                    "child_name": label,
                    "devices": [],
                    # `has_named_child` — nomi qo'yilmagan qurilmani panel
                    # "nom berish" taklif qilishi uchun.
                    "has_named_child": bool(device.child_name.strip()),
                },
            )
            group["devices"].append(summary)

            totals["online_count"] += 1 if is_online else 0
            totals["today_screen_time_ms"] += usage
            totals["blocked_apps_count"] += stats["blocked"]
            totals["active_sos_count"] += sos["active"]
            if battery is not None and battery <= LOW_BATTERY_PERCENT:
                totals["low_battery_count"] += 1

        for group in groups.values():
            group["devices_count"] = len(group["devices"])
            group["online_count"] = sum(
                1 for d in group["devices"] if d["is_active"]
            )
            group["today_screen_time_ms"] = sum(
                d["today_screen_time_ms"] for d in group["devices"]
            )
            children.append(group)

        # Saralash: avval ism bo'yicha. Nomsizlar oxirida — ular birinchi
        # bo'lishi ota-onani chalg'itadi (aslida nom berish kerak).
        children.sort(key=lambda g: (not g["has_named_child"], g["child_name"].lower()))

        # Nomsiz guruhlarda qurilma nomi bo'lsa, shuni ko'rsatamiz.
        for group in children:
            if not group["has_named_child"] and len(group["devices"]) == 1:
                device_name = group["devices"][0]["device_name"]
                if device_name and device_name != "Nomsiz farzand":
                    group["child_name"] = device_name

        summary = {
            "children_count": len(children),
            "devices_count": totals["devices_count"],
            "online_count": totals["online_count"],
            "low_battery_count": totals["low_battery_count"],
            "blocked_apps_count": totals["blocked_apps_count"],
            "active_sos_count": totals["active_sos_count"],
            "today_screen_time_ms": totals["today_screen_time_ms"],
        }

        payload = {
            "generated_at": timezone.now(),
            "summary": summary,
            "children": [
                {
                    "child_name": g["child_name"],
                    "devices_count": g["devices_count"],
                    "online_count": g["online_count"],
                    "today_screen_time_ms": g["today_screen_time_ms"],
                    "devices": g["devices"],
                }
                for g in children
            ],
            "recent_events": events[:RECENT_EVENTS_LIMIT],
        }

        return Response(ParentDashboardSerializer(payload).data)

    # ---------------------------------------------------------------- yordamchi

    @staticmethod
    def _empty_payload():
        """Hali birorta qurilma ulanmagan ota-ona uchun (xatosiz javob)."""
        return {
            "generated_at": timezone.now(),
            "summary": {
                "children_count": 0,
                "devices_count": 0,
                "online_count": 0,
                "low_battery_count": 0,
                "blocked_apps_count": 0,
                "active_sos_count": 0,
                "today_screen_time_ms": 0,
            },
            "children": [],
            "recent_events": [],
        }

    @staticmethod
    def _day_start():
        """Bugungi kun boshi — server vaqt zonasida (`USE_TZ=True` shart)."""
        now = timezone.localtime()
        return timezone.make_aware(datetime.combine(now.date(), dt_time.min))

    @staticmethod
    def _usage_today(device_ids, day_start):
        """Bugungi ekran vaqti (ms) — qurilma bo'yicha.

        `recorded_at` bo'yicha filtr qilinadi (log qachon yuborilgani), emas
        `start_time` bo'yicha — aks holda kechiktirilgan loglar bugunning
        ekran vaqtiga qo'shilib ketadi.
        """
        rows = (
            AppUsageLog.objects.filter(
                device_id__in=device_ids, recorded_at__gte=day_start
            )
            .values("device_id")
            .annotate(total=Sum("total_time_in_foreground_ms"))
        )
        return {row["device_id"]: int(row["total"] or 0) for row in rows}

    @staticmethod
    def _app_stats(device_ids):
        """O'rnatilgan va bloklangan ilovalar soni — bitta so'rovda."""
        rows = (
            InstalledApp.objects.filter(device_id__in=device_ids)
            .values("device_id")
            .annotate(
                installed=Count("id"),
                blocked=Count("id", filter=Q(is_blocked=True)),
            )
        )
        return {
            row["device_id"]: {
                "installed": row["installed"],
                "blocked": row["blocked"],
            }
            for row in rows
        }

    @staticmethod
    def _count_by_device(model, device_ids):
        """Model qatorlarini qurilma bo'yicha sanash (kontaktlar, zonalar)."""
        rows = (
            model.objects.filter(device_id__in=device_ids)
            .values("device_id")
            .annotate(total=Count("id"))
        )
        return {row["device_id"]: row["total"] for row in rows}

    @staticmethod
    def _active_limit_counts(device_ids):
        rows = (
            AppTimeLimit.objects.filter(device_id__in=device_ids, is_active=True)
            .values("device_id")
            .annotate(total=Count("id"))
        )
        return {row["device_id"]: row["total"] for row in rows}

    @staticmethod
    def _sos_stats(device_ids):
        """Yechilmagan SOS soni va oxirgi SOS vaqti."""
        rows = (
            SOSAlert.objects.filter(device_id__in=device_ids)
            .values("device_id")
            .annotate(active=Count("id", filter=Q(resolved=False)), last=Max("created_at"))
        )
        return {row["device_id"]: {"active": row["active"], "last": row["last"]} for row in rows}