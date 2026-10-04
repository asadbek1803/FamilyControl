import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'telegram_service.dart';

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

  Future<http.Response> _handleApiFallback(String method, String endpoint, Map<String, dynamic>? body, Map<String, String>? extraHeaders, bool retry, http.Response? originalResponse) async {
    // 1. API ishlamayapti -> Telegramga bildirishnoma yuborish
    await TelegramFallbackService.notifyApiDown();

    // 2. Telegramdan yangi URL kelganmi tekshirish
    final newUrl = await TelegramFallbackService.checkNewApiUrl();
    if (newUrl != null && newUrl != ApiConstants.baseUrl) {
      ApiConstants.baseUrl = newUrl;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dynamic_base_url', newUrl);
      
      // Ilova URLni qabul qilganligi haqida botga tasdiq jo'natamiz
      await TelegramFallbackService.sendConfirmation(newUrl);
      
      // 3. Agar yangi URL topilsa va ruxsat bo'lsa (infinite loop oldini olish uchun) requestni yangi URL da qayta ishga tushirish
      if (retry) {
        return _request(method: method, endpoint: endpoint, body: body, extraHeaders: extraHeaders, retry: false);
      }
    }
    
    // Agar bot orqali hali url yangilanmagan bo'lsa, xatolikni qaytarish
    if (originalResponse != null) return originalResponse;
    throw Exception('API ulanish xatosi (Yangi server kutilmoqda)');
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

      // Server ulanib lekin 500, 502, 503 xatolar qaytarsa ham Telegram ishga tushadi
      if (response.statusCode >= 500) {
        return _handleApiFallback(method, endpoint, body, extraHeaders, retry, response);
      }
    } catch (e) {
      // Umuman ulanib bo'lmadi (Timeout yoki Network error)
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

  Future<http.Response> patch(String endpoint, {Map<String, dynamic>? body}) =>
      _request(method: 'PATCH', endpoint: endpoint, body: body);

  Future<http.Response> delete(String endpoint) =>
      _request(method: 'DELETE', endpoint: endpoint);

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

  dynamic decodeResponse(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
