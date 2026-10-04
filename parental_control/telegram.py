"""Server tomondagi Telegram Bot API klienti.

Nima uchun bu modul kerak: bot tokeni FAQAT serverda bo'lishi kerak.
Agar token mobil ilovada saqlansa, APK ni ochgan har kim botga to'liq
kirish huquqiga ega bo'ladi (xabar yuborish, o'quvchi ma'lumotlarni ko'rish).

Shuning uchun `flutter_app/lib/core/network/telegram_service.dart` dagi
hardcoded token va "Telegram orqali yangi server URL qabul qilish" mexanizmi
butunlay olib tashlandi — u hujumchilar uchun ochiq eshik edi.
"""

import json
import logging
import urllib.error
import urllib.parse
import urllib.request

from django.conf import settings

logger = logging.getLogger(__name__)

TELEGRAM_API_BASE = "https://api.telegram.org"
DEFAULT_TIMEOUT = 5


def get_bot_token() -> str:
    """Token faqat server sozlamalaridan olinadi (env: TELEGRAM_BOT_TOKEN)."""
    return getattr(settings, "TELEGRAM_BOT_TOKEN", "") or ""


def is_configured() -> bool:
    return bool(get_bot_token())


def _call(method: str, payload: dict | None = None, timeout: int = DEFAULT_TIMEOUT):
    token = get_bot_token()
    if not token:
        logger.warning("TELEGRAM_BOT_TOKEN sozlanmagan, Telegram ishlatilmaydi")
        return None

    url = f"{TELEGRAM_API_BASE}/bot{token}/{method}"
    data = urllib.parse.urlencode(payload or {}).encode("utf-8")
    request = urllib.request.Request(url, data=data, method="POST")

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        logger.warning("Telegram %s -> HTTP %s", method, exc.code)
        return None
    except (urllib.error.URLError, TimeoutError, ValueError, OSError) as exc:
        logger.warning("Telegram %s xatosi: %s", method, exc)
        return None

    if not body.get("ok"):
        logger.warning("Telegram %s ok=false: %s", method, body.get("description"))
        return None
    return body.get("result")


def get_chat(chat_id: int | str):
    """Chat mavjudligi va botga ulanishini tekshiradi.

    Telegram bot faqat OLDINGINA o'ziga yozgan (yoki /start bosgan) chat'ga
    xabar yubora oladi. Shu sababli bu tekshiruv ota-onaga "ID to'g'ri" degan
    ishonchli javob beradi.
    """
    return _call("getChat", {"chat_id": str(chat_id)})


def get_me():
    """Botning o'zi haqidagi ma'lumot (username — sozlamalar ekrani uchun)."""
    return _call("getMe")


def send_message(chat_id: int | str, text: str) -> bool:
    return _call("sendMessage", {"chat_id": str(chat_id), "text": text}) is not None
