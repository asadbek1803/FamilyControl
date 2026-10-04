class ApiConstants {
  /// Server manzili. Ilova ishga tushganda `RemoteConfig` shu qiymatni GitHub'dagi
  /// `familycontrol_config.json` fayli bilan yangilaydi (boshqa holatda
  /// `defaultBaseUrl` ishlatiladi).
  ///
  /// Eski versiya bu qiymatni Telegram orqali almashtirardi — bu xavfli
  /// mexanizm edi, batafsil `lib/core/network/remote_config.dart` da.
  ///
  /// Mahalliy server bilan ishlash uchun build vaqtida bering:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  static String baseUrl = _buildBaseUrl();

  /// Build vaqtida `--dart-define=API_BASE_URL=...` orqali berilgan manzil.
  ///
  /// Berilmasa `defaultBaseUrl` (GitHub'dan olingan manzil zaxirasi).
  static String _buildBaseUrl() {
    const fromBuild = String.fromEnvironment('API_BASE_URL');
    if (fromBuild.isNotEmpty) return fromBuild;
    return defaultBaseUrl;
  }

  /// Zaxira (fallback) server manzili.
  ///
  /// Server manzili asosan GitHub'dan olinadi (qarang
  /// `lib/core/network/remote_config.dart`). Bu qiymat faqat GitHub
  /// ishlamaganda yoki internet yo'q bo'lganda ishlatiladi.
  ///
  /// Bu shuning uchun HAQIQIY server manzili bo'lishi SHART: agar emulator
  /// manzili (`10.0.2.2`) qo'yilsa, GitHub ishlamagan holatda ilova
  /// haqiqiy telefon hech narsaga ulana olmaydi va "server topilmadi"
  /// holatida qoladi.
  static const String defaultBaseUrl =
      'https://familycontrol-production.up.railway.app/api/v1';

  /// Mahalliy ishlash (emulator / kompyuter) uchun. Almashtirish uchun
  /// `flutter run` dan oldin quyidagini bajarish mumkin:
  ///   --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  static const String localBaseUrl = 'http://10.0.2.2:8000/api/v1';

  // Auth endpoints
  static const String login = '/auth/token/';
  static const String refreshToken = '/auth/token/refresh/';
  static const String register = '/auth/register/';

  // Device endpoints
  static const String devices = '/devices/';
  static const String deviceRegister = '/devices/register/';
  static const String devicePair = '/devices/pair/';
  // Qurilma o'z tokenini oladi (pairing ota-onaning ilovasida bo'lgani uchun)
  static const String deviceClaim = '/devices/claim/';
  // Qurilma hodisa yuboradi (DeviceBearer autentifikatsiyasi)
  static const String deviceEvents = '/devices/events/';

  // Ota-onaning sozlamalari
  static const String telegramSetting = '/settings/telegram/';

  // Child data endpoints (relative, device_id will be interpolated)
  static String deviceApps(String deviceId) => '/devices/$deviceId/apps/';
  static String deviceApp(String deviceId, String appId) =>
      '/devices/$deviceId/apps/$appId/';
  static String deviceLocations(String deviceId) =>
      '/devices/$deviceId/locations/';
  static String deviceUsage(String deviceId) => '/devices/$deviceId/usage/';
  static String deviceNotifications(String deviceId) =>
      '/devices/$deviceId/notifications/';
  static String deviceAccessibility(String deviceId) =>
      '/devices/$deviceId/accessibility/';
  static String deviceZones(String deviceId) =>
      '/devices/$deviceId/zones/';
  static String deviceContacts(String deviceId) =>
      '/devices/$deviceId/contacts/';
  // DIQQAT: backend'da bu yo'l `parental_control/urls.py` da
  // `devices/<uuid:device_id>/limits/` ko'rinishida. Avval bu yerda
  // `/time-limits/` edi — mos kelmasligi tufayli barcha so'rovlar 404 berardi.
  static String deviceTimeLimits(String deviceId) => '/devices/$deviceId/limits/';
  static String deviceSOS(String deviceId) =>
      '/devices/$deviceId/sos/';

  // Sync
  static const String syncBatch = '/sync/batch/';
}
