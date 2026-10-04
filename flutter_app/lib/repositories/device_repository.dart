import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/network/connectivity_service.dart';
import '../core/database/local_database.dart';
import '../core/constants/api_constants.dart';
import '../models/child_device.dart';
import '../models/installed_app.dart';
import '../models/location_log.dart';
import '../models/app_usage_log.dart';
import '../models/notification_log.dart';
import '../models/geo_zone.dart';
import '../models/contact.dart';
class DeviceRepository {
  final _apiClient = ApiClient();
  final _connectivity = ConnectivityService();
  final _db = LocalDatabase.instance;

  // ---- Devices ----

  Future<List<ChildDevice>> getDevices() async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      try {
        final response = await _apiClient.get(ApiConstants.devices);
        if (response.statusCode == 200) {
          final List<dynamic> data =
              jsonDecode(utf8.decode(response.bodyBytes));
          final devices =
              data.map((j) => ChildDevice.fromJson(j as Map<String, dynamic>)).toList();

          // Cache locally
          for (final device in devices) {
            await _db.upsertDevice(device.toDb());
          }
          return devices;
        }
      } catch (_) {
        // fall through to local
      }
    }

    // Offline: return from local DB
    final rows = await _db.getDevices();
    return rows.map((r) => ChildDevice.fromDb(r)).toList();
  }

  Future<ChildDevice?> getDevice(String id) async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      try {
        final response =
            await _apiClient.get('${ApiConstants.devices}$id/');
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final device = ChildDevice.fromJson(data as Map<String, dynamic>);
          await _db.upsertDevice(device.toDb());
          return device;
        }
      } catch (_) {}
    }

    final row = await _db.getDevice(id);
    return row != null ? ChildDevice.fromDb(row) : null;
  }

  Future<Map<String, dynamic>> registerDevice({
    required String deviceIdentifier,
    String deviceName = '',
  }) async {
    final response = await _apiClient.publicPost(
      ApiConstants.deviceRegister,
      body: {
        'device_identifier': deviceIdentifier,
        'device_name': deviceName,
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {'success': true, 'data': data};
    }
    return {
      'success': false,
      'error': jsonDecode(utf8.decode(response.bodyBytes))
    };
  }

  Future<Map<String, dynamic>> pairDevice({
    required String pairingCode,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.devicePair,
      body: {
        'pairing_code': pairingCode,
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {'success': true, 'data': data};
    }
    return {
      'success': false,
      'error': jsonDecode(utf8.decode(response.bodyBytes))
    };
  }

  Future<bool> deleteDevice(String id) async {
    final response = await _apiClient.delete('${ApiConstants.devices}$id/');
    if (response.statusCode == 204 || response.statusCode == 200) {
      await _db.deleteDevice(id);
      return true;
    }
    return false;
  }

  // ---- Installed Apps ----

  Future<List<InstalledApp>> getApps(String deviceId) async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      try {
        final response =
            await _apiClient.get(ApiConstants.deviceApps(deviceId));
        if (response.statusCode == 200) {
          final List<dynamic> data =
              jsonDecode(utf8.decode(response.bodyBytes));
          final apps = data
              .map((j) => InstalledApp.fromJson(j as Map<String, dynamic>,
                  deviceId: deviceId))
              .toList();
          await _db.upsertApps(apps.map((a) => a.toDb()).toList());
          return apps;
        }
      } catch (_) {}
    }

    final rows = await _db.getApps(deviceId);
    return rows.map((r) => InstalledApp.fromDb(r)).toList();
  }

  Future<bool> setAppBlocked(
      String deviceId, String appId, bool isBlocked) async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      final response = await _apiClient.patch(
        ApiConstants.deviceApp(deviceId, appId),
        body: {'is_blocked': isBlocked},
      );
      if (response.statusCode == 200) {
        await _db.updateAppBlocked(appId, isBlocked);
        return true;
      }
      return false;
    } else {
      // Offline: update locally and add to sync queue
      await _db.updateAppBlocked(appId, isBlocked);
      await _db.addToSyncQueue(
        endpoint: ApiConstants.deviceApp(deviceId, appId),
        method: 'PATCH',
        body: jsonEncode({'is_blocked': isBlocked}),
      );
      return true; // optimistic update
    }
  }

  // ---- Location Logs ----

  Future<List<LocationLog>> getLocations(String deviceId,
      {int limit = 20}) async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      try {
        final response =
            await _apiClient.get(ApiConstants.deviceLocations(deviceId));
        if (response.statusCode == 200) {
          final List<dynamic> data =
              jsonDecode(utf8.decode(response.bodyBytes));
          final logs = data
              .map((j) => LocationLog.fromJson(j as Map<String, dynamic>,
                  deviceId: deviceId))
              .toList();
          await _db.upsertLocations(logs.map((l) => l.toDb()).toList());
          return logs.take(limit).toList();
        }
      } catch (_) {}
    }

    final rows = await _db.getLocations(deviceId, limit: limit);
    return rows.map((r) => LocationLog.fromDb(r)).toList();
  }

  // ---- App Usage Logs ----

  Future<List<AppUsageLog>> getUsageLogs(String deviceId) async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      try {
        final response =
            await _apiClient.get(ApiConstants.deviceUsage(deviceId));
        if (response.statusCode == 200) {
          final List<dynamic> data =
              jsonDecode(utf8.decode(response.bodyBytes));
          final logs = data
              .map((j) => AppUsageLog.fromJson(j as Map<String, dynamic>,
                  deviceId: deviceId))
              .toList();
          await _db.upsertUsageLogs(logs.map((l) => l.toDb()).toList());
          return logs;
        }
      } catch (_) {}
    }

    final rows = await _db.getUsageLogs(deviceId);
    return rows.map((r) => AppUsageLog.fromDb(r)).toList();
  }

  // ---- Notification Logs ----

  Future<List<NotificationLog>> getNotifications(String deviceId) async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      try {
        final response =
            await _apiClient.get(ApiConstants.deviceNotifications(deviceId));
        if (response.statusCode == 200) {
          final List<dynamic> data =
              jsonDecode(utf8.decode(response.bodyBytes));
          final logs = data
              .map((j) => NotificationLog.fromJson(j as Map<String, dynamic>,
                  deviceId: deviceId))
              .toList();
          await _db.upsertNotifications(logs.map((l) => l.toDb()).toList());
          return logs;
        }
      } catch (_) {}
    }

    final rows = await _db.getNotifications(deviceId);
    return rows.map((r) => NotificationLog.fromDb(r)).toList();
  }

  // ---- Geo Zones ----
  Future<List<GeoZone>> getZones(String deviceId) async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      try {
        final response = await _apiClient.get(ApiConstants.deviceZones(deviceId));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
          final zones = data.map((j) => GeoZone.fromJson(j as Map<String, dynamic>)).toList();
          await _db.upsertGeoZones(zones.map((z) => z.toDb()).toList());
          return zones;
        }
      } catch (_) {}
    }

    final rows = await _db.getGeoZones(deviceId);
    return rows.map((r) => GeoZone.fromDb(r)).toList();
  }

  Future<bool> createZone(String deviceId, Map<String, dynamic> data) async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      final response = await _apiClient.post(
        ApiConstants.deviceZones(deviceId),
        body: data,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } else {
      await _db.addToSyncQueue(
        endpoint: ApiConstants.deviceZones(deviceId),
        method: 'POST',
        body: jsonEncode(data),
      );
      return true; // Optimistic
    }
    return false;
  }

  // ---- Contacts ----
  Future<List<Contact>> getContacts(String deviceId) async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      try {
        final response = await _apiClient.get(ApiConstants.deviceContacts(deviceId));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
          final contacts = data.map((j) => Contact.fromJson(j as Map<String, dynamic>)).toList();
          await _db.upsertContacts(contacts.map((c) => c.toDb()).toList());
          return contacts;
        }
      } catch (_) {}
    }

    final rows = await _db.getContacts(deviceId);
    return rows.map((r) => Contact.fromDb(r)).toList();
  }

  // ---- App Time Limits ----
  Future<bool> setAppLimit(String deviceId, Map<String, dynamic> data) async {
    final isOnline = await _connectivity.isOnline;

    if (isOnline) {
      final response = await _apiClient.post(
        ApiConstants.deviceTimeLimits(deviceId),
        body: data,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } else {
      await _db.addToSyncQueue(
        endpoint: ApiConstants.deviceTimeLimits(deviceId),
        method: 'POST',
        body: jsonEncode(data),
      );
      return true; // Optimistic
    }
    return false;
  }

  // ---- SOS Alerts ----
  // `SOSAlertSerializer` `latitude` va `longitude` maydonlarini majburiy qiladi.
  // Avval yuborilgan `{device_id, status, created_at}` tani serializer'da yo'q
  // edi -> har doim 400 ValidationError qaytardi.
  Future<bool> sendSOS(
    String deviceId, {
    required double latitude,
    required double longitude,
  }) async {
    final isOnline = await _connectivity.isOnline;
    final data = {
      'latitude': latitude,
      'longitude': longitude,
    };

    if (isOnline) {
      final response = await _apiClient.post(
        ApiConstants.deviceSOS(deviceId),
        body: data,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } else {
      // Internet yo'q — keyinroq yuborish uchun navbatga solamiz
      await _db.addToSyncQueue(
        endpoint: ApiConstants.deviceSOS(deviceId),
        method: 'POST',
        body: jsonEncode(data),
      );
      await _db.insertSOSAlert(data);
      return true; // Optimistic
    }
    return false;
  }
}
