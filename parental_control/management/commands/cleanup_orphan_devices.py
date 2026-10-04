"""Ota-onaga ulanmagan ("yetim") qurilmalarni ro'yxatdan chiqaradi.

Ishlatish:
    python manage.py cleanup_orphan_devices              -- faqat ko'rsatadi (xavfsiz)
    python manage.py cleanup_orphan_devices --apply      -- haqiqatan o'chiradi

Nima uchun kerak:

`ChildDevice.parent` — `null=True`. Qurilma avval `POST /devices/register/`
orqali ro'yxatdan o'tadi (farzand ilovasi ishlay boshlagan payt), va
`POST /devices/pair/` orqali ota-onaga ulanadi. Ikkinchi qadam bajarilmasa
yoki xato bo'lsa, qurilma bazada qoladi:

    is_active=True, device_token_hash=<hash>, parent=NULL

Bunday qurilma hech qanday ma'lumot yubora olmaydi
(`IsAuthenticatedDevice` `request.user is not None` talab qiladi, yetim
qurilmada esa `request.user` — `None`), lekin bazada o'z ma'lumotlari bilan
qoladi: joylashuv loglari, ilovalar, hodisalar.

2026-10 da `parent` bir saqlashda yo'qolgani uchun bunday qurilmalar
oddiydan ko'p bo'lib ketgan edi (ota-onaga "ulandi" xabari kelgan, lekin
panelda hech narsa ko'rinmagan holat).

Nima uchun avval `--apply` kerak:

`parent IS NULL` — bu "xato" belgisi, "keraksiz" belgisi emas. Ota-onaning
o'z qurilmasi ham shu holatda bo'lishi mumkin (u hali kod kiritmagan).
Shuning uchun bu command hech narsani o'z holicha o'chirmaydi — avval
ro'yxatni ko'rsatadi, keyin qaror sizniki.

Xavfsizlik: `--apply` bilan `parent IS NULL` qurilmalar va ularning BARCHA
bog'liq ma'lumotlari (joylashuv, ilovalar, foydalanish, bildirishnomalar,
hodisalar, zonalar, chegirmalar, kontaktlar, SOS) `CASCADE` orqali
o'chadi. Bu buyruqni ota-onaning ishlaydigan qurilmalari uchun ISHLATING.

Agar ota-onaning qurilmasini saqlab qolmoqchi bo'lsangiz, uni avval
`/admin/` orqali juftlashtiring (yoki ilovada qayta ulab ko'ring) — keyin u
bu ro'yxatda chiqmaydi.
"""

from datetime import timedelta

from django.core.management.base import BaseCommand
from django.db.models import Count
from django.utils import timezone

from parental_control.models import ChildDevice


class Command(BaseCommand):
    help = "parent IS NULL bo'lgan qurilmalarni ko'rsatadi va (--apply) o'chiradi"

    def add_arguments(self, parser):
        parser.add_argument(
            "--apply",
            action="store_true",
            help="Haqiqatan o'chirish. Berilmasa faqat ro'yxat ko'rsatiladi.",
        )
        parser.add_argument(
            "--days",
            type=int,
            default=0,
            help=(
                "Faqat shu kunlardan eski qurilmalarni o'chir. 0 = barchasi. "
                "Tez-tez sinov qilinadigan muhitda foydali."
            ),
        )

    def handle(self, *args, **options):
        apply = options["apply"]
        days = options["days"]

        orphans = ChildDevice.objects.filter(parent__isnull=True).annotate(
            locations_count=Count("location_logs", distinct=True)
        )

        if days > 0:
            cutoff = timezone.now() - timedelta(days=days)
            orphans = orphans.filter(created_at__lt=cutoff)

        orphans = orphans.order_by("-created_at")
        total = orphans.count()

        if total == 0:
            self.stdout.write(self.style.SUCCESS("Yetim qurilma topilmadi."))
            return

        self.stdout.write("")
        self.stdout.write(self.style.WARNING(f"parent IS NULL bo'lgan {total} ta qurilma:"))
        for device in orphans:
            self.stdout.write(
                self.style.WARNING(
                    f"  {device.device_name or '(nom yoq)'}\n"
                    f"    id={device.device_identifier}  is_active={device.is_active}\n"
                    f"    joylashuv_logi={device.locations_count}  "
                    f"created={device.created_at:%Y-%m-%d %H:%M}  uuid={device.id}"
                )
            )
        self.stdout.write("")

        if not apply:
            self.stdout.write(
                "Bu faqat ko'rsatish. O'chirish uchun:\n"
                "    python manage.py cleanup_orphan_devices --apply\n"
                "\n"
                "Ogohlantirish: ota-onaning ISHLAYDIGAN qurilmalari ham shu\n"
                "ro'yxatda bo'lishi mumkin. Avval ularni juftlashtiring."
            )
            return

        deleted, _ = orphans.delete()
        self.stdout.write(
            self.style.SUCCESS(
                f"{deleted} ta yozuv o'chirildi (ularning barcha bog'liq ma'lumotlari bilan)."
            )
        )
