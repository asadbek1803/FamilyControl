import 'dart:convert';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/device_credentials.dart';
import '../core/network/native_bridge.dart';

/// Qurilma hodisalari — Telegram orqali ota-onaga yetkaziladigan ro'yxat.
///
/// DIQQAT: bu OLOVLAR va qurilma holati hodisalari. Boshqa ilovalarning
/// ichki xabarlari yoki chat yozishmalari bu ro'yxatga KIRMAYDI.
class DeviceEventTypes {
  static const String paired = 'paired';
  static const String unpaired = 'unpaired';
  static const String sos = 'sos';
  static const String batteryLow = 'battery_low';
  static const String adminDisabled = 'admin_disabled';
  static const String adminEnabled = 'admin_enabled';
  static const String childModeEnabled = 'child_mode_enabled';
  static const String zoneExit = 'zone_exit';
  static const String appBlocked = 'app_blocked';
  static const String appUnblocked = 'app_unblocked';

  static const Map<String, String> labels = {
    paired: 'Qurilma ulandi',
    unpaired: 'Qurilma uzildi',
    sos: 'SOS signali',
    batteryLow: 'Batareya qullab qolmoqda',
    adminDisabled: 'Himoya o\'chirildi',
    adminEnabled: 'Himoya yoqildi',
    childModeEnabled: 'Farzand rejimi yoqildi',
    zoneExit: 'Xavfsizlik zonasidan chiqdi',
    appBlocked: 'Ilova bloklandi',
    appUnblocked: 'Ilova blokdan chiqarildi',
  };
}

/// Ota-onaning Telegram bildirishnoma sozlamalari.
class TelegramSetting {
  final int? chatId;
  final String chatTitle;
  final bool isEnabled;
  final bool botConfigured;
  final String? botUsername;
  final DateTime? lastSentAt;

  const TelegramSetting({
    this.chatId,
    this.chatTitle = '',
    this.isEnabled = false,
    this.botConfigured = false,
    this.botUsername,
    this.lastSentAt,
  });

  factory TelegramSetting.fromJson(Map<String, dynamic> json) {
    return TelegramSetting(
      chatId: json['chat_id'] != null ? int.tryParse('${json['chat_id']}') : null,
      chatTitle: json['chat_title']?.toString() ?? '',
      isEnabled: json['is_enabled'] == true,
      botConfigured: json['bot_configured'] == true,
      botUsername: json['bot_username']?.toString(),
      lastSentAt: json['last_sent_at'] != null
          ? DateTime.tryParse('${json['last_sent_at']}')
          : null,
    );
  }
}

class NotificationRepository {
  final _api = ApiClient();

  // ---------- Ota-ona tomoni ----------

  Future<TelegramSetting> getTelegramSetting() async {
    final res = await _api.get(ApiConstants.telegramSetting);
    if (res.statusCode == 200) {
      return TelegramSetting.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw Exception(_errorMessage(res, 'Sozlamalarni yuklab bo\'lmadi'));
  }

  /// Chat ID serverda `getChat` orqali tekshiriladi, so'ng test xabari yuboriladi.
  Future<bool> saveTelegramSetting({
    required int chatId,
    required bool isEnabled,
  }) async {
    final res = await _api.put(
      ApiConstants.telegramSetting,
      body: {'chat_id': chatId, 'is_enabled': isEnabled},
    );
    if (res.statusCode == 200) return true;
    throw Exception(_errorMessage(res, 'Chat ID saqlanmadi'));
  }

  Future<bool> sendTestTelegramMessage() async {
    final res = await _api.post(ApiConstants.telegramSetting, body: {});
    if (res.statusCode == 200) return true;
    throw Exception(_errorMessage(res, 'Test xabar yuborilmadi'));
  }

  // ---------- Qurilma tomoni ----------

  /// Ota-ona shu qurilmani ulaganini tekshiradi va token oladi.
  Future<bool> claimDeviceToken(String deviceIdentifier) async {
    final res = await _api.publicPost(
      ApiConstants.deviceClaim,
      body: {'device_identifier': deviceIdentifier},
    );
    if (res.statusCode != 200) return false;

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (data['is_paired'] != true) return false;

    final deviceId = data['device_id']?.toString();
    final token = data['device_token']?.toString();
    if (deviceId == null || token == null) return false;

    await DeviceCredentials.save(deviceId: deviceId, token: token);
    // Native tomonga ham beramiz: `AdminReceiver` va `AccessibilityService`
    // Dart'siz ishlaydi (jarayon o'lganda ham) va o'zlari serverga murojat
    // yuborishi kerak.
    await NativeBridge.saveDeviceCredentials(
      deviceId: deviceId,
      token: token,
    );
    return true;
  }

  Future<bool> isPaired(String deviceIdentifier) async {
    final res = await _api.publicPost(
      ApiConstants.deviceClaim,
      body: {'device_identifier': deviceIdentifier},
    );
    if (res.statusCode != 200) return false;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return data['is_paired'] == true;
  }

  /// Hodisani serverga yuboradi. Telegram ga server yetkazadi.
  Future<bool> sendEvent({
    required String eventType,
    required String message,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final res = await _api.devicePost(
        ApiConstants.deviceEvents,
        body: {'event_type': eventType, 'message': message, 'data': data},
      );
      return res.statusCode == 201;
    } catch (_) {
      // Qurilma hali ulanmagan yoki internet yo'q — hodisa yuborilmadi,
      // lekin ilova ishlashda davom etadi.
      return false;
    }
  }

  String _errorMessage(dynamic response, String fallback) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map) {
        final values = data.values.expand((v) => v is List ? v : [v]).toList();
        if (values.isNotEmpty) return values.join('\n');
      }
    } catch (_) {}
    return fallback;
  }
}
