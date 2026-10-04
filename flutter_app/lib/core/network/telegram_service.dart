/// DIQQAT: bu fayl butunlay bo'sh qoldirilgan va xizmatga ulanmagan.
///
/// AVVAL shu yerda quyidagi xavfli mexanizm bor edi:
///   1) Bot tokeni va ota-onaning chat ID si APK ichida hardcoded edi
///      (`botToken`, `chatId` statik maydonlari);
///   2) `checkNewApiUrl()` botga kelgan oxirgi xabarni o'qib, agar u `http`
///      bilan boshlansa, uni ilovaning BACKEND URL si sifatida qabul qilib
///      `SharedPreferences` ga yozardi.
///
/// APK ni ochish juda oson (Flutter bosh kod ochiq saqlanadi), ya'ni token
/// allaqach oshkor bo'lgan edi. Bundan keyin hujumchi:
///   - botga o'z server manzilini yuboradi,
///   - ilova uni qabul qilib, `ApiConstants.baseUrl` ni o'zgaradi,
///   - natijada BARCHA ota-ona va farzand qurilmalari o'z JWT tokenlarini,
///     joylashuvlarini va ma'lumotlarini hujumchining serveriga yuboradi.
///
/// Endi bu xavf yo'q qilingandi:
///   - Bot tokeni FAQAT serverda (`TELEGRAM_BOT_TOKEN` muhit o'zgaruvchisi);
///   - Telegram integratsiyasi butunlay server tomonda
///     (`parental_control/telegram.py` va `notifications.py`);
///   - Ota-onaning chat ID si autentifikatsiyalanган endpoint orqali
///     `PUT /settings/telegram/` da saqlanadi va `getChat` bilan tekshiriladi;
///   - Qurilma hodisalari `POST /devices/events/` ga yuboriladi, Telegram ga
///     esa SERVER yuboradi.
///
/// Eski mexanizmni tiklash kerak bo'lsa, avval @BotFather orqali eski tokenni
/// bekor qiling (revoke) — u allaqach oshkor.
library;

// Bu yerda maxfiy ma'lumot yoki backend URL almashtirish logikasi yo'q.
// Telegram bildirishnomalari uchun `core/network/telegram_api.dart`
// (server orqali) va `repositories/notification_repository.dart` ishlatiladi.
