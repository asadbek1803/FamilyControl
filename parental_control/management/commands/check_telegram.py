"""Telegram bot tokenini tekshirish.

Ishlatish:
    python manage.py check_telegram                -- faqat sozlanmaganini tekshiradi
    python manage.py check_telegram 123456789      -- ushbu chat ga xabar yuborib sinaydi

Bu command Telegram'ga murojat yubormasligi mumkin (birinchi holatda
`getMe` chaqiradi — bu xabarsiz, xavfsiz). Ikkinchi holatda esa haqiqiy
test xabari yuboradi.
"""

from django.core.management.base import BaseCommand, CommandError

from parental_control import telegram


class Command(BaseCommand):
    help = "TELEGRAM_BOT_TOKEN sozlanishini va (ixtiyoriy) chat_id ni tekshirish"

    def add_arguments(self, parser):
        parser.add_argument(
            "chat_id",
            nargs="?",
            default=None,
            help="Sinab uchun xabar yuboriladigan chat ID (ixtiyoriy)",
        )

    def handle(self, *args, **options):
        token = telegram.get_bot_token()

        if not token:
            raise CommandError(
                "TELEGRAM_BOT_TOKEN sozlanmagan.\n\n"
                "Railway uchun:\n"
                "  1) Railway dashboard -> sizning servisingiz -> Variables\n"
                "  2) TELEGRAM_BOT_TOKEN  nomi bilan yangi variable qo'shing\n"
                "     qiymat: @BotFather'dan olgan tokeningiz\n"
                "  3) Deploy / Redeploy bosing (avtomatik bo'lsa ham o'zgartirish\n"
                "     keyin redeploy kerak)\n\n"
                "Mahalliy kompyuter uchun:\n"
                "  Loyiha papkasida `.env` fayli yarating va ichiga qo'ying:\n"
                "      TELEGRAM_BOT_TOKEN=123456789:ABCdef...\n"
                "  (namuna uchun `.env.example` fayliga qarang)\n"
            )

        # Token matnini to'liq ko'rsatmaymiz — ekran yozuvlari va log'larda
        # oshkor bo'lmasligi kerak.
        self.stdout.write(f"Token o'rnatilgan: {token[:10]}...{token[-4:]}")

        me = telegram.get_me()
        if not me:
            raise CommandError(
                "Token Telegram tomonidan qabul qilinmadi. Token noto'g'ri yoki\n"
                "bekor qilingan bo'lishi mumkin. @BotFather orqali yangisini oling."
            )

        self.stdout.write(self.style.SUCCESS(f"Bot ishlayapti: @{me.get('username')}"))

        chat_id = options.get("chat_id")
        if not chat_id:
            self.stdout.write(
                "Sinab uchun chat ID bering, masalan:\n"
                "    python manage.py check_telegram 123456789"
            )
            return

        chat = telegram.get_chat(chat_id)
        if not chat:
            raise CommandError(
                f"Chat {chat_id} topilmadi.\n"
                "Sabablar: ID noto'g'ri, yoki botga /start yuborilmagan.\n"
                "Telegram'da botni ochib, /start yuboring va qayta urinib ko'ring."
            )

        title = chat.get("title") or chat.get("username") or "(shaxsiy chat)"
        self.stdout.write(f"Chat topildi: {title} (id={chat_id})")

        if telegram.send_message(chat_id, "✅ FamilyControl: test xabari. Aloqa ishlayapti!"):
            self.stdout.write(self.style.SUCCESS("Test xabari yuborildi."))
        else:
            raise CommandError(
                "Chat topildi, lekin xabar yuborilmadi. Bot bloke qilingan bo'lishi mumkin."
            )