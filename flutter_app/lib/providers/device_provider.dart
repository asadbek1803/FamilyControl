import 'package:flutter/material.dart';
import '../models/child_device.dart';
import '../models/installed_app.dart';
import '../models/location_log.dart';
import '../models/app_usage_log.dart';
import '../models/notification_log.dart';
import '../models/geo_zone.dart';
import '../models/contact.dart';
import '../repositories/device_repository.dart';

class DeviceProvider extends ChangeNotifier {
  final _repo = DeviceRepository();

  List<ChildDevice> _devices = [];
  ChildDevice? _selectedDevice;
  List<InstalledApp> _apps = [];
  List<LocationLog> _locations = [];
  List<AppUsageLog> _usageLogs = [];
  List<NotificationLog> _notifications = [];
  List<GeoZone> _zones = [];
  List<Contact> _contacts = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<ChildDevice> get devices => _devices;
  ChildDevice? get selectedDevice => _selectedDevice;
  List<InstalledApp> get apps => _apps;
  List<LocationLog> get locations => _locations;
  List<AppUsageLog> get usageLogs => _usageLogs;
  List<NotificationLog> get notifications => _notifications;
  List<GeoZone> get zones => _zones;
  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void selectDevice(ChildDevice device) {
    _selectedDevice = device;
    notifyListeners();
  }

  Future<void> loadDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _devices = await _repo.getDevices();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadApps(String deviceId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _apps = await _repo.getApps(deviceId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLocations(String deviceId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _locations = await _repo.getLocations(deviceId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUsageLogs(String deviceId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _usageLogs = await _repo.getUsageLogs(deviceId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNotifications(String deviceId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await _repo.getNotifications(deviceId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleAppBlock(String deviceId, InstalledApp app) async {
    final newBlocked = !app.isBlocked;
    // Optimistic update
    final idx = _apps.indexWhere((a) => a.id == app.id);
    if (idx != -1) {
      _apps[idx] = app.copyWith(isBlocked: newBlocked);
      notifyListeners();
    }
    final success = await _repo.setAppBlocked(deviceId, app.id, newBlocked);
    if (!success) {
      // Revert
      if (idx != -1) {
        _apps[idx] = app;
        notifyListeners();
      }
    }
    return success;
  }

  Future<Map<String, dynamic>> pairDevice({
    required String pairingCode,
  }) async {
    final result = await _repo.pairDevice(
      pairingCode: pairingCode,
    );
    if (result['success'] == true) {
      await loadDevices();
    }
    return result;
  }

  Future<bool> deleteDevice(String deviceId) async {
    final success = await _repo.deleteDevice(deviceId);
    if (success) {
      _devices.removeWhere((d) => d.id == deviceId);
      notifyListeners();
    }
    return success;
  }

  // ---- Geo Zones ----
  Future<void> loadZones(String deviceId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _zones = await _repo.getZones(deviceId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createZone(String deviceId, Map<String, dynamic> data) async {
    final success = await _repo.createZone(deviceId, data);
    if (success) {
      await loadZones(deviceId);
    }
    return success;
  }

  // ---- Contacts ----
  Future<void> loadContacts(String deviceId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _contacts = await _repo.getContacts(deviceId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---- App Time Limit ----
  Future<bool> setAppLimit(String deviceId, Map<String, dynamic> data) async {
    return await _repo.setAppLimit(deviceId, data);
  }

  // ---- SOS Alerts ----
  Future<bool> sendSOS(
    String deviceId, {
    required double latitude,
    required double longitude,
  }) async {
    return await _repo.sendSOS(
      deviceId,
      latitude: latitude,
      longitude: longitude,
    );
  }

  void clear() {
    _devices = [];
    _selectedDevice = null;
    _apps = [];
    _locations = [];
    _usageLogs = [];
    _notifications = [];
    _zones = [];
    _contacts = [];
    notifyListeners();
  }
}
