"""Test bazalarini tayyorlash (Neon / PgBouncer uchun).

Nima uchun kerak
----------------
Neon bergan `DATABASE_URL` odatda `-pooler.` bilan tugaydi — bu PgBouncer
(transaction rejimi). Django test yakunida `DROP DATABASE` bajaradi, lekin
PgBouncer o'sha bazadagi server ulanishlarini o'z havuzida ushlab turadi va
shuning uchun:

    OperationalError: database "test_neondb" is being accessed by other users

xatosi chiqadi. Test natijasi `OK` bo'lsa ham, buyruq shu bilan xato bilan
tugatiladi va keyingi ishga tushirish ham yana shu yerda to'xtaydi.

Yechim: test bazasi bir marta qo'lda yaratiladi, Django undan foydalanadi va
O'NI YO'Q QILMAYDI (`TEST.KEEP_DB = True`). Shuning uchun:

    1) Bir marta:      python manage.py prepare_test_db
    2) Har doim:       python manage.py test parental_control

Bu qadam `settings.py` dagi `TEST_DATABASE_NAME` ni hurmat qiladi.
"""

import time

from django.conf import settings
from django.core.management import call_command
from django.core.management.base import BaseCommand, CommandError
from django.db import connections
from django.db.utils import OperationalError


class Command(BaseCommand):
    help = "Test bazalarini yaratadi va migratsiyalarni qo'llaydi (bir marta)"

    def add_arguments(self, parser):
        parser.add_argument(
            "--reset",
            action="store_true",
            help="Test bazalarini avvaldan YO'Q qilib, qaytadan yaratish",
        )

    def handle(self, *args, **options):
        db_settings = settings.DATABASES["default"]
        engine = db_settings["ENGINE"]

        if "sqlite" in engine:
            raise CommandError(
                "SQLite ishlatilmoqda — test bazasi alohida yaratilmaydi, "
                "shuning uchun bu command kerak emas. To'g'ridan-to'g'ri "
                "ishga tushiring: python manage.py test parental_control"
            )

        test_name = self._test_db_name()
        admin = self._admin_connection()

        if options["reset"]:
            self._drop(admin, test_name)
            self._drop(admin, f"test_{db_settings['NAME']}")

        exists = self._exists(admin, test_name)
        if exists:
            self.stdout.write(f"Test bazasi mavjud: {test_name}")
        else:
            self._create(admin, test_name)
            self.stdout.write(self.style.SUCCESS(f"Test bazasi yaratildi: {test_name}"))

        # Migratsiyalar asosiy bazadagi kabi `neondb` emas, test bazasiga
        # qo'llanadi.
        connections.close_all()
        original = db_settings["NAME"]
        db_settings["NAME"] = test_name
        try:
            call_command("migrate", verbosity=0, interactive=False)
            self.stdout.write(self.style.SUCCESS("Migratsiyalar qo'llandi"))
        finally:
            db_settings["NAME"] = original
            connections.close_all()

        self.stdout.write("")
        self.stdout.write("Tayyor. Endi testlarni shu tarzda ishga tushiring:")
        self.stdout.write(
            self.style.SUCCESS("    python manage.py test parental_control")
        )

    # ---------------------------------------------------------------- yordamchi

    def _test_db_name(self):
        configured = settings.DATABASES["default"].get("TEST", {}).get("NAME")
        if configured:
            return configured
        return f"test_{settings.DATABASES['default']['NAME']}"

    def _admin_connection(self):
        """`postgres` ma'lumotbazasiga ulanish (bazalarni yaratish uchun)."""
        db = connections["default"].copy(alias="admin_setup")
        db.settings_dict["NAME"] = "postgres"
        # Yaratish/o'chirish `template1` dan foydalanmaydi, shuning uchun
        # `ATOMIC_REQUESTS` o'chiriladi.
        db.settings_dict["ATOMIC_REQUESTS"] = False
        db.settings_dict["CONN_MAX_AGE"] = 0
        try:
            db.ensure_connection()
        except OperationalError as exc:
            raise CommandError(
                f"Admin ulanishi muvaffaqiyatsiz: {exc}\n\n"
                "Neon'da `neondb_owner` roli ma'lumotbazalarini yaratish huquqiga "
                "ega bo'lishi kerak. Railway Variables -> DATABASE_URL ni "
                "tekshiring."
            )
        return db

    def _exists(self, db, name):
        with db.cursor() as cursor:
            cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", [name])
            return cursor.fetchone() is not None

    def _drop(self, db, name):
        if not self._exists(db, name):
            return
        self.stdout.write(f"O'chirilmoqda: {name}")
        with db.cursor() as cursor:
            # PgBouncer ulanishlari ushlanib qolmasligi uchun avwal ularni
            # majburan uzamiz.
            cursor.execute(
                "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                "WHERE datname = %s AND pid <> pg_backend_pid()",
                [name],
            )
        # PgBouncer ulanish qaytarishi uchun biroz kutamiz.
        for attempt in range(3):
            try:
                with db.cursor() as cursor:
                    cursor.execute(f'DROP DATABASE IF EXISTS "{name}"')
                return
            except OperationalError:
                if attempt == 2:
                    raise
                time.sleep(1)

    def _create(self, db, name):
        with db.cursor() as cursor:
            cursor.execute(f'CREATE DATABASE "{name}"')