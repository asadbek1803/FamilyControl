import 'package:flutter/material.dart';
import '../models/child_device.dart';
import '../models/installed_app.dart';
import '../models/location_log.dart';
import '../models/app_usage_log.dart';
import '../models/notification_log.dart';
import '../models/geo_zone.dart';
import '../models/contact.dart';
import '../models/app_time_limit.dart';
import '../models/device_event.dart';
import '../models/sos_alert.dart';
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
  List<AppTimeLimit> _timeLimits = [];
  List<DeviceEvent> _events = [];
  List<SOSAlert> _sosAlerts = [];

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
  List<AppTimeLimit> get timeLimits => _timeLimits;
  List<DeviceEvent> get events => _events;
  List<SOSAlert> get sosAlerts => _sosAlerts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Yechilmagan SOS signallari soni — panel banner'i uchun.
  int get unresolvedSosCount =>
      _sosAlerts.where((alert) => !alert.resolved).length;

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
  Future<List<AppTimeLimit>> loadTimeLimits(String deviceId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _timeLimits = await _repo.getTimeLimits(deviceId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _timeLimits;
  }

  /// Yangi vaqt limiti qo'shish. `false` qaytsa — server rad etgan
  /// (masalan limit 0 yoki 1440 dan tashqarida).
  Future<bool> setAppLimit(String deviceId, Map<String, dynamic> data) async {
    final success = await _repo.setAppLimit(deviceId, data);
    if (success) {
      await loadTimeLimits(deviceId);
    }
    return success;
  }

  Future<bool> updateTimeLimit(
    String deviceId,
    String limitId,
    Map<String, dynamic> data,
  ) async {
    final success = await _repo.updateTimeLimit(deviceId, limitId, data);
    if (success) {
      await loadTimeLimits(deviceId);
    }
    return success;
  }

  Future<bool> deleteTimeLimit(String deviceId, String limitId) async {
    final success = await _repo.deleteTimeLimit(deviceId, limitId);
    if (success) {
      _timeLimits.removeWhere((limit) => limit.id == limitId);
      notifyListeners();
    }
    return success;
  }

  // ---- Device Events ----
  Future<List<DeviceEvent>> loadEvents(
    String deviceId, {
    String? eventType,
    int? days,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      _events = await _repo.getEvents(deviceId, eventType: eventType, days: days);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _events;
  }

  // ---- SOS Alerts ----
  Future<List<SOSAlert>> loadSOSAlerts(
    String deviceId, {
    bool unresolvedOnly = false,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      _sosAlerts = await _repo.getSOSAlerts(deviceId, unresolvedOnly: unresolvedOnly);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _sosAlerts;
  }

  Future<bool> setSOSResolved(
    String deviceId,
    String alertId,
    bool resolved,
  ) async {
    final success = await _repo.setSOSResolved(deviceId, alertId, resolved);
    if (success) {
      final index = _sosAlerts.indexWhere((a) => a.id == alertId);
      if (index != -1) {
        _sosAlerts[index] = _sosAlerts[index].copyWith(resolved: resolved);
        notifyListeners();
      }
    }
    return success;
  }

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

  /// Qurilma nomini va farzand nomini saqlash.
  Future<bool> updateDeviceNames(
    String deviceId, {
    String? childName,
    String? deviceName,
  }) async {
    final updated = await _repo.updateDevice(
      deviceId,
      childName: childName,
      deviceName: deviceName,
    );
    if (updated == null) return false;

    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      _devices[index] = updated;
      notifyListeners();
    }
    if (_selectedDevice?.id == deviceId) {
      _selectedDevice = updated;
      notifyListeners();
    }
    return true;
  }

  // ---- Geo Zones: o'chirish/tahrirlash ----
  Future<bool> updateZone(
    String deviceId,
    String zoneId,
    Map<String, dynamic> data,
  ) async {
    final success = await _repo.updateZone(deviceId, zoneId, data);
    if (success) {
      await loadZones(deviceId);
    }
    return success;
  }

  Future<bool> deleteZone(String deviceId, String zoneId) async {
    final success = await _repo.deleteZone(deviceId, zoneId);
    if (success) {
      _zones.removeWhere((zone) => zone.id == zoneId);
      notifyListeners();
    }
    return success;
  }

  // ---- Contacts: o'chirish ----
  Future<bool> deleteContact(String deviceId, String contactId) async {
    final success = await _repo.deleteContact(deviceId, contactId);
    if (success) {
      _contacts.removeWhere((contact) => contact.id == contactId);
      notifyListeners();
    }
    return success;
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
    _timeLimits = [];
    _events = [];
    _sosAlerts = [];
    notifyListeners();
  }
}
