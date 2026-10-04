import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _repo = AuthRepository();

  AuthStatus _status = AuthStatus.unknown;
  String? _errorMessage;
  bool _isLoading = false;
  String? _username;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  String? get username => _username;

  AuthProvider() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await _repo.isLoggedIn();
    if (loggedIn) {
      _username = await _repo.getSavedUsername();
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repo.login(username: username, password: password);
      if (result['success'] == true) {
        _username = username;
        _status = AuthStatus.authenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = _parseError(result['error']);
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Serverga ulanib bo\'lmadi. Internet aloqasini tekshiring.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repo.register(
        username: username,
        email: email,
        password: password,
      );
      if (result['success'] == true) {
        // Auto-login after register
        return await login(username, password);
      } else {
        _errorMessage = _parseError(result['error']);
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Serverga ulanib bo\'lmadi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    _status = AuthStatus.unauthenticated;
    _username = null;
    notifyListeners();
  }

  String _parseError(dynamic error) {
    if (error == null) return 'Noma\'lum xato';
    if (error is Map) {
      final values = error.values.expand((v) {
        if (v is List) return v.map((e) => e.toString());
        return [v.toString()];
      }).toList();
      return values.join('\n');
    }
    return error.toString();
  }
}
