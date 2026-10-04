import 'package:flutter/material.dart';
import '../repositories/notification_repository.dart';

/// Ota-onaning Telegram bildirishnoma sozlamalari.
class NotificationSettingsProvider extends ChangeNotifier {
  final _repo = NotificationRepository();

  TelegramSetting _setting = const TelegramSetting();
  bool _isLoading = false;
  String? _errorMessage;

  TelegramSetting get setting => _setting;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _setting = await _repo.getTelegramSetting();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save({required int chatId, required bool isEnabled}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repo.saveTelegramSetting(chatId: chatId, isEnabled: isEnabled);
      _setting = await _repo.getTelegramSetting();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendTestMessage() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repo.sendTestTelegramMessage();
      _setting = await _repo.getTelegramSetting();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
