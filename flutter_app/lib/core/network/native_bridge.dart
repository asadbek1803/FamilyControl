import 'package:flutter/services.dart';

import '../constants/api_constants.dart';

/// Kotlin (`MainActivity`) bilan MethodChannel orqali aloqa.
///
/// Bu modul ikki vazifani bajaradi:
///  1) Server manzilini native tomonga yetkazadi — `ChildAccessibilityService`
///     va `AdminReceiver` hodisalarni yuborishi uchun kerak. Ular Dart'siz
///     ishlaydi (masalan, Device Admin o'chirilganda), shuning uchun manzilni
///     o'zlari bilmaydi.
///  2) Qurilma tokenini native tomonda saqlaydi — xuddi shu sabab bilan.
class NativeBridge {
  const NativeBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.familycontrol/accessibility');

  /// Server manzilini native'ga beradi.
  ///
  /// Xavfsizlik: bu manzil FAQAT shu koddan (`ApiConstants.baseUrl`) keladi.
  /// Telegram yoki boshqa tashqi kanallar orqali almashtirilmaydi — eski
  /// mexanizmda hujumchi bot orqali butun botni egallab, barcha qurilmalarni
  /// o'z serveriga yo'naltirishi mumkin edi.
  static Future<void> syncServerBaseUrl() async {
    try {
      await _channel.invokeMethod<bool>(
        'saveServerBaseUrl',
        {'baseUrl': ApiConstants.baseUrl},
      );
    } on PlatformException {
      // Platforma qo'llab-quvvatlamasa (masalan test) — jimgina o'tkazamiz.
    } on MissingPluginException {
      // Hali engine tayyor emas — keyinroq `initState` da qayta chaqiriladi.
    }
  }

  /// Qurilma tokenini native saqlashga o'tkazadi, shunda BroadcastReceiver'lar
  /// ham hodisa yubora oladi.
  static Future<void> saveDeviceCredentials({
    required String deviceId,
    required String token,
  }) async {
    try {
      await _channel.invokeMethod<bool>('saveDeviceCredentials', {
        'deviceId': deviceId,
        'token': token,
      });
    } on PlatformException {
      // Xatolik bo'lsa ham asosiy oqim buzilmaydi.
    } on MissingPluginException {
      // Engine hali tayyor emas.
    }
  }

  static Future<void> clearDeviceCredentials() async {
    try {
      await _channel.invokeMethod<bool>('clearDeviceCredentials');
    } on PlatformException {
      // Xatolikni e'tiborsiz qoldiramiz.
    } on MissingPluginException {
      // Engine hali tayyor emas.
    }
  }
}