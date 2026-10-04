import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import 'device_credentials.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _storage = const FlutterSecureStorage();

  Future<String?> _getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<String?> _getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<bool> refreshAccessToken() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refreshToken}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(
          accessToken: data['access'],
          refreshToken: data['refresh'] ?? refreshToken,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Tarmoq yoki server xatosi.
  ///
  /// DIQQAT: eski versiya bu yerda Telegram orqali yangi server URL qabul qilardi.
  /// Bu xavfli mexanizm edi — bot tokeni APK ichida hardcoded bo'lgani uchun
  /// APK ni ochgan hujumchi botga o'z server manzilini yuborib, BARCHA ota-ona
  /// va farzand qurilmalarining JWT tokenlarini o'z serveriga yo'naltirishi
  /// mumkin edi. Endi server manzili faqat `ApiConstants.baseUrl` dan olinadi
  /// va hech qanday tashqi manzildan o'zgartirilmaydi.
  Future<http.Response> _handleApiFallback(
    String method,
    String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
    bool retry,
    http.Response? originalResponse,
  ) async {
    if (originalResponse != null) return originalResponse;
    throw Exception(
      "Serverga ulanib bo'lmadi. Internetni tekshirib, qayta urinib ko'ring.",
    );
  }

  Future<http.Response> _request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
    bool retry = true,
  }) async {
    final token = await _getAccessToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?extraHeaders,
    };

    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    http.Response? response;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
          break;
        case 'POST':
          response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 10));
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 10));
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 10));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));
          break;
        default:
          throw Exception('Unknown HTTP method: $method');
      }

      if (response.statusCode >= 500) {
        return _handleApiFallback(method, endpoint, body, extraHeaders, retry, response);
      }
    } catch (e) {
      return _handleApiFallback(method, endpoint, body, extraHeaders, retry, null);
    }

    // Agar 401 kelsa token yangilab ko'ramiz
    if (response.statusCode == 401 && retry) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        return _request(
          method: method,
          endpoint: endpoint,
          body: body,
          extraHeaders: extraHeaders,
          retry: false,
        );
      }
    }

    return response;
  }

  Future<http.Response> get(String endpoint) =>
      _request(method: 'GET', endpoint: endpoint);

  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) =>
      _request(method: 'POST', endpoint: endpoint, body: body);

  Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) =>
      _request(method: 'PUT', endpoint: endpoint, body: body);

  Future<http.Response> patch(String endpoint, {Map<String, dynamic>? body}) =>
      _request(method: 'PATCH', endpoint: endpoint, body: body);

  Future<http.Response> delete(String endpoint) =>
      _request(method: 'DELETE', endpoint: endpoint);

  /// Autentifikatsiyasiz so'rov (ro'yxatdan o'tkazish, pairing kodi olish).
  Future<http.Response> publicPost(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode >= 500) {
        return _handleApiFallback('POST', endpoint, body, null, true, res);
      }
      return res;
    } catch (e) {
      return _handleApiFallback('POST', endpoint, body, null, true, null);
    }
  }

  /// Qurilma tokeni bilan so'rov (`DeviceBearer <device_id>:<token>`).
  ///
  /// Pairing ota-onaning ilovasida bo'lgani uchun token ota-onada qoladi;
  /// farzand qurilmasi uni `POST /devices/claim/` orqali oladi.
  Future<http.Response> devicePost(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final credentials = await DeviceCredentials.load();
    if (credentials == null || !credentials.isValid) {
      throw Exception('Qurilma hali ota-onaga ulanmagan.');
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'DeviceBearer ${credentials.deviceId}:${credentials.token}',
          },
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 10));

    return res;
  }

  dynamic decodeResponse(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
