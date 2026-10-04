import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/network/api_client.dart';
import '../core/database/local_database.dart';
import '../core/constants/api_constants.dart';

class AuthRepository {
  final _apiClient = ApiClient();
  final _db = LocalDatabase.instance;
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.publicPost(
      ApiConstants.login,
      body: {'username': username, 'password': password},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      await _apiClient.saveTokens(
        accessToken: data['access'],
        refreshToken: data['refresh'],
      );
      await _storage.write(key: 'username', value: username);
      return {'success': true, 'data': data};
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      return {'success': false, 'error': error};
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.publicPost(
      ApiConstants.register,
      body: {
        'username': username,
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {'success': true, 'data': data};
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      return {'success': false, 'error': error};
    }
  }

  Future<void> logout() async {
    await _apiClient.clearTokens();
    await _storage.delete(key: 'username');
    await _db.clearAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }

  Future<String?> getSavedUsername() async {
    return await _storage.read(key: 'username');
  }
}
