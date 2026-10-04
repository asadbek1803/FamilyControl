"""Testlar uchun umumiy asos.

Nima uchun `ThrottleCleanMixin` kerak:

`settings.py` da pairing uchun chegara qo'yilgan — `pair: 5/minute`
(`ScopedRateThrottle`). BuProduction uchun to'g'ri qaror: kodni taxmin qilib
topishga uringan bot `POST /devices/pair/` ni ko'p yuborib olmasin.

Lekin DRF throttling hisobini `django.core.cache` da saqlaydi va testlar
bitta vaqt oynasida bo'lishadi. Ya'ni birinchi 5 ta pairing so'rovi o'tadi,
6-si `429` qaytadi. Bu **boshqa** testlarni tasodifi buzadi: yangi test
qo'shilsa, butun suite qizil bo'lib chiqadi va xato pairing kodiga
yo'nalmaydi.

Shuning uchun chegara o'z-o'zidan emas, `setUp` da tozalanadi. Natija:
- har bir test mustaqil (test tartibi va soni farq qilmaydi),
- Production dagi chegara o'zgarmaydi,
- agar katalogni qidirib, chegara o'zini alohida tekshirmoqchi bo'lsa, bu
  mixinni ishlatmasin — aynan shuning uchun u alohida ajratilgan.

MUHIM: bu throttlingning o'zi ishlashini tekszirmaydi. Agar chegara
ishlashini sinab ko'rmoqchi bo'lsangiz, `ThrottleCleanMixin` ni olib
tashing kerak.
"""

from django.core.cache import cache
from rest_framework.test import APITestCase


class ThrottleCleanMixin:
    """Test boshlanishida DRF throttling hisobini tozalaydi."""

    def _pre_setup(self):  # noqa: N802 - Django ichki nomi
        # Nima uchun `setUp` EMAS: `setUp` ni test sinflari juda ko'p
        # qayta yozadi va `super().setUp()` ni chaqirishni unutish mumkin
        # (bizda ham shunday bo'ldi — mixin butunlay ishga tushmadi va
        # tasodifiy `429` paydo bo'ldi). `_pre_setup` ni esa hech kim
        # qayta yozmaydi va Django uni har bir test metodi oldidan chaqiradi.
        super()._pre_setup()
        cache.clear()
        # `LocMemCache` jarayon umriga yashaydi, shuning uchun test tugagandan
        # keyin ham tozalaymiz — aks holda qoldiq hisob keyingi testga o'tadi.
        self.addCleanup(cache.clear)


class BaseAPITestCase(ThrottleCleanMixin, APITestCase):
    """Yangi test sinflari shundan merosxo'r olsin.

    Eslatma: bu sinflardagi `setUp` `super().setUp()` ni chaqirishi SHART emas —
    throttling tozalash `_pre_setup` orqali ishlaydi. Lekin Django'ning odati
    bo'yicha `super()` ni chaqirish yaxshi.
    """
