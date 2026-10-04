"""Telegram'ga yuborilmagan hodisalarni qayta yuborish.

Ishlatish:
    python manage.py send_pending_notifications            # so'nggi 1 kun
    python manage.py send_pending_notifications --days 3    # so'nggi 3 kun
    python manage.py send_pending_notifications --days 0    # barchasi

Bu command Telegram nosozligi yoki server uzilishi paytida yuborilmay
qolgan hodisalarni ota-onaga yetkazadi. Telegram'ga xabar yuborish
har doim ixtiyoriy: yo'qotilgan yuborish ma'lumotni o'chirmaydi, faqat
kechikadi.
"""

from django.core.management.base import BaseCommand

from parental_control.notifications import retry_pending


class Command(BaseCommand):
    help = "Telegram'ga yetkazilmagan hodisalarni qayta yuborish"

    def add_arguments(self, parser):
        parser.add_argument(
            "--days",
            type=int,
            default=1,
            help="Qancha kunlik hodisalarni tekshirish (0 = cheksiz)",
        )

    def handle(self, *args, **options):
        days = options["days"]
        if days <= 0:
            days = 365 * 10  # amaliy chegarasiz

        sent = retry_pending(max_age_days=days)
        self.stdout.write(
            self.style.SUCCESS(f"{sent} ta hodisa Telegram orqali yuborildi.")
        )