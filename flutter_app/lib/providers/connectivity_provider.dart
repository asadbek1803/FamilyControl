import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/network/connectivity_service.dart';
import '../repositories/sync_repository.dart';

class ConnectivityProvider extends ChangeNotifier {
  final _service = ConnectivityService();
  final _sync = SyncRepository();

  bool _isOnline = true;
  ConnectivityResult _result = ConnectivityResult.none;

  bool get isOnline => _isOnline;
  ConnectivityResult get result => _result;

  String get statusText {
    if (_isOnline) {
      switch (_result) {
        case ConnectivityResult.wifi:
          return 'WiFi';
        case ConnectivityResult.mobile:
          return 'Mobil internet';
        case ConnectivityResult.ethernet:
          return 'Ethernet';
        default:
          return 'Online';
      }
    }
    return 'Offline';
  }

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    _isOnline = await _service.isOnline;
    _result = await _service.currentResult;
    notifyListeners();

    _service.onConnectivityChanged.listen((results) async {
      final wasOnline = _isOnline;
      _result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _isOnline = results.any((r) => r != ConnectivityResult.none);

      if (!wasOnline && _isOnline) {
        // Internet qayta keldi - sync queue ni process qilamiz
        await _sync.processQueue();
      }
      notifyListeners();
    });
  }
}
