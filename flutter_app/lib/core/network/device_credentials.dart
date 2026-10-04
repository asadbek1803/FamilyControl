import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Farzand qurilmasining o'z autentifikatsiya ma'lumotlari.
///
/// Pairing ota-onaning ilovasida amalga oshadi va `device_token` ota-onaning
/// telefonida qoladi. Farzand qurilmasi esa o'z tokenini
/// `POST /devices/claim/` orqali oladi (boshqa hech kim `device_identifier`ni
/// bilmaydi — u qurilmada UUIDv4 sifatida generatsiya qilinadi).
///
/// Token `SharedPreferences` emas, `FlutterSecureStorage` da saqlanadi.
class DeviceCredentials {
  static const _deviceIdKey = 'device_id';
  static const _tokenKey = 'device_token';

  static const _storage = FlutterSecureStorage();

  final String deviceId;
  final String token;

  const DeviceCredentials({required this.deviceId, required this.token});

  bool get isValid => deviceId.isNotEmpty && token.isNotEmpty;

  static Future<DeviceCredentials?> load() async {
    final deviceId = await _storage.read(key: _deviceIdKey);
    final token = await _storage.read(key: _tokenKey);
    if (deviceId == null || token == null || deviceId.isEmpty || token.isEmpty) {
      return null;
    }
    return DeviceCredentials(deviceId: deviceId, token: token);
  }

  static Future<void> save({required String deviceId, required String token}) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _deviceIdKey);
    await _storage.delete(key: _tokenKey);
  }
}
