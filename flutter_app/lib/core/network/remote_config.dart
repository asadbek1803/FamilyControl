import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Server manzilini GitHub'dan oladi.
///
/// NIMA UCHUN: server manzili vaqt vaqtida o'zgaradi (boshqa port, yangi
/// domen). Eski yechim — Telegram bot orqali — juda qulay edi, lekin xavfli:
///
///   1) Bot tokeni APK ichida hardcoded bo'lgani uchun APK ni ochgan har kim
///      botga o'z server manzilini yubora olardi;
///   2) Ilova uni qabul qilib, `ApiConstants.baseUrl` ni almashtirardi;
///   3) Natijada BARCHA ota-ona va farzand qurilmalari o'z JWT tokenlarini,
///      joylashuvlarini va ota-ona akkauntlarini hujumchi serveriga yuborardi.
///
/// Endi oqim shunday:
///
///   GitHub (raw.githubusercontent.com) -> config.json -> base_url
///
/// XAVFSIZLIK CHEGARALARI (imzo yo'qligi sababli):
///   - FAQAT `https://` qabul qilinadi (mahalliy ishlash uchun emas
///     `http://` ruxsat beriladi: `10.0.2.2`, `localhost`, `127.0.0.1`);
///   - so'rov jarayonni to'xtatmaydi — GitHub ishlamasa eski URL saqlanadi;
///   - javob validatsiyadan o'tmasa URL o'zgartirilmaydi;
///   - ilovada hech qanday maxfiy narsa (bot tokeni) yo'q.
///
/// QOLDIQ XAVF: bu fayl imzolanmagan. Kimdir GitHub repozitoriysiga yoki DNS'ga
/// kirish huquqiga ega bo'lsa, u `base_url` ni o'z serveriga almashtirishi
/// mumkin. Yechim — repo'ni himoyalash (2FA, kamaygan xodimlar) va yana ham
/// yaxshiroq variant: faylni shaxsiy kalit bilan imzolash (`signed_url` qarang).
class RemoteConfig {
  const RemoteConfig._();

  /// GitHub'da joylashtiriladigan fayl manzili.
  ///
  /// Misol uchun repo `oilabek/familycontrol` bo'lsa, fayl `main` branch'da
  /// `familycontrol_config.json` nomi bilan turishi kerak va uning mazmuni:
  ///
  /// ```json
  /// { "base_url": "https://api.mening-domainim.uz/api/v1" }
  /// ```
  static const String sourceUrl =
      'https://raw.githubusercontent.com/asadbek1803/FamilyControl/refs/heads/main/familycontrol_config.json';

  /// Kamida shuncha vaqt oralig'ida GitHub'ga so'rov yuborilmaydi.
  /// Sababi: har ilova ochilishida so'rov yuborish kerak emas (tezlik +
  /// GitHub rate limit). Bundan tashqari `http` so'rov MainThread'da
  /// bloklamasligi uchun bu qiymat katta qoldirilgan.
  static const Duration minInterval = Duration(hours: 6);

  static const String prefsKey = 'remote_base_url';
  static const String prefsFetchedAt = 'remote_base_url_fetched_at';

  /// Ilova boshlanganda chaqiriladi: joriy server manzilini aniqlaydi.
  ///
  /// [fallback] — kodda yozilgan manzil (odatda `ApiConstants.defaultBaseUrl`).
  /// Hech qanday xatolik bo'lsa shu qiymat qaytariladi, ya'ni ilova ishlashdan
  /// to'xtamaydi.
  static Future<String> resolveBaseUrl(String fallback) async {
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString(prefsKey);
    final cachedAt = prefs.getInt(prefsFetchedAt) ?? 0;
    final fresh = DateTime.now().millisecondsSinceEpoch - cachedAt <
        minInterval.inMilliseconds;

    // Yaqinda tekshirilgan bo'lsa — tarmoqqa umuman chiqmaymiz.
    if (fresh && cached != null && _isAcceptable(cached)) return cached;

    try {
      final response = await http
          .get(Uri.parse(sourceUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return _keep(fallback, cached);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final raw = decoded is Map ? decoded['base_url']?.toString().trim() : null;

      if (raw == null || raw.isEmpty) return _keep(fallback, cached);

      // Oxiridagi `/` ni olib tashlaymiz, aks holda endpointlar `//` bo'lib
      // ketadi (`.../api/v1//devices/`).
      final normalized = raw.endsWith('/')
          ? raw.substring(0, raw.length - 1)
          : raw;

      if (!_isAcceptable(normalized)) return _keep(fallback, cached);

      await prefs.setString(prefsKey, normalized);
      await prefs.setInt(
        prefsFetchedAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      return normalized;
    } catch (_) {
      // Internet yo'q, GitHub ishlamayapti, JSON noto'g'ri — ilova ishlayveradi.
      return _keep(fallback, cached);
    }
  }

  /// Keshni tozalash (server manzali noto'g'ri bo'lib qolsa).
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    await prefs.remove(prefsFetchedAt);
  }

  /// Qachon oxirgi marta tekshirilganini qaytaradi (sozlamalar ekrani uchun).
  static Future<DateTime?> lastFetchedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(prefsFetchedAt);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Manzilni qabul qilishimiz mumkinmi.
  ///
  /// Asosiy qoida: FAQAT `https`. `http` faqat mahalliy ishlash uchun
  /// (emulator va kompyuter) — aks holda trafikni oddiy `http` orqali
  /// ochiq qoldirish, ya'ni o'zgartirilgan manzilni MITM qilish osonlashadi.
  static bool _isAcceptable(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;

    const localHosts = {'10.0.2.2', 'localhost', '127.0.0.1'};
    final isLocal = localHosts.contains(uri.host);

    if (uri.scheme == 'https') return true;
    return isLocal && uri.scheme == 'http';
  }

  /// Xato bo'lgan holda: eski keshni saqlab qolamiz, u bo'lmasa `fallback`.
  static String _keep(String fallback, String? cached) =>
      (cached != null && _isAcceptable(cached)) ? cached : fallback;
}