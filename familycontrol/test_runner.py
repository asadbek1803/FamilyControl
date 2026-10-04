"""Test runner — Neon/PgBouncer muammosini hal qiladi.

Nima uchun kerak
----------------
Neon bergan `DATABASE_URL` odatda `-pooler.` bilan tugaydi. Bu PgBouncer
(transaction rejimi): u mijoz ulanishi tugasa ham, o'z server ulanishlarini
havuzda ushlab turadi.

Django test tugaganda `DROP DATABASE` bajaradi va shu sababdan:

    OperationalError: database "test_neondb" is being accessed by other users

xatosi chiqadi. Testlar `OK` bo'lganiga qaramaydi, buyruq xato bilan tugaydi
va keyingi ishga tushirish ham xuddi shu yerda to'xtaydi.

Yechim: test bazasi bir marta qo'lda yaratiladi (`prepare_test_db`) va Django
uni YO'Q QILMAYDI. `--keepdb` shu ishni qiladi, lekin Django uni faqat
buyruq qatoridan `--keepdb` berilsa yoqaydi — `TEST["KEEP_DB"]` sozlama
SKIP qilinadi (Django `global_settings.TEST` da bu kalit umuman yo'q).

Shuning uchun bu runner `keepdb=True` ni avtomatik yoqadi. O'chirish uchun:

    TEST_KEEP_DB=0 python manage.py test parental_control

yoki test bazasini to'liq qaytadan qurish:

    python manage.py prepare_test_db --reset
"""

import os

from django.db.utils import OperationalError
from django.test.runner import DiscoverRunner


class FamilyControlTestRunner(DiscoverRunner):
    """`--keepdb` ni standart qilib qo'yadigan runner."""

    def __init__(self, *args, **kwargs):
        # CLI `--keepdb` ham bo'lsa, yutqazamiz (True qo'yamiz).
        # `TEST_KEEP_DB=0` bilan butunlay o'chiriladi.
        keepdb = os.environ.get("TEST_KEEP_DB", "1").strip().lower()
        kwargs["keepdb"] = keepdb not in ("0", "false", "no", "off")

        super().__init__(*args, **kwargs)

    def setup_databases(self, **kwargs):
        # `keepdb` ni o'zimiz qo'shmaymiz: `DiscoverRunner` uni `self.keepdb`
        # dan o'zi yuboradi (`_setup_databases(keepdb=self.keepdb, ...)`).
        try:
            return super().setup_databases(**kwargs)
        except OperationalError as exc:
            message = str(exc).lower()
            if "does not exist" not in message:
                raise

            from django.conf import settings

            test_name = (
                settings.DATABASES["default"].get("TEST", {}).get("NAME")
                or f"test_{settings.DATABASES['default']['NAME']}"
            )

            raise OperationalError(
                f"{exc}\n\n"
                f"Test bazasi `{test_name}` hali yaratilmagan. Buni bir marta "
                f"bajarib, keyin testni qayta ishga tushiring:\n\n"
                f"    python manage.py prepare_test_db\n\n"
                f"(Har gal `python manage.py test` — shu yerda o'zi to'xtaydi.)"
            ) from exc