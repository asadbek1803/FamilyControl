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
import '../models/app_time_limit.dart';
import '../models/device_event.dart';
import '../models/sos_alert.dart';
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

  /// Qurilma nomini va **farzand nomini** yangilash.
  ///
  /// `child_name` — boshqaruv panelida qurilma qaysi farzandga tegishli
  /// ko'rsatish uchun. Bir farzand bir nechta qurilma ishlatishi mumkin,
  /// ular shu nom bo'yicha bitta guruhda birlashadi.
  Future<ChildDevice?> updateDevice(
    String id, {
    String? childName,
    String? deviceName,
  }) async {
    final body = <String, dynamic>{
      if (childName != null) 'child_name': childName.trim(),
      if (deviceName != null) 'device_name': deviceName.trim(),
    };
    if (body.isEmpty) return getDevice(id);

    final response = await _apiClient.patch(
      '${ApiConstants.devices}$id/',
      body: body,
    );
    if (response.statusCode != 200) return null;

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final device = ChildDevice.fromJson(data);
    await _db.upsertDevice(device.toDb());
    return device;
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

  /// Xavfsizlik zonalari — FAQAT serverdan.
  ///
  /// Oldin lokal bazaga ham yozilardi, lekin `geo_zones` jadvali server
  /// javobi bilan mos kelmasdi (ustun nomlari `radius` vs `radius_meters`),
  /// shuning uchun oflayn holatda noto'g'ri ma'lumot ko'rsatilardi. Zona
  /// qo'shish — server amali; internet yo'q bo'lsa uni bajarib bo'lmaydi,
  /// shuning uchun jim qoldirish to'g'ri.
  Future<List<GeoZone>> getZones(String deviceId) async {
    final response = await _apiClient.get(ApiConstants.deviceZones(deviceId));
    if (response.statusCode != 200) return [];

    final List<dynamic> data =
        jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(GeoZone.fromJson)
        .toList();
  }

  Future<bool> createZone(String deviceId, Map<String, dynamic> data) async {
    final response = await _apiClient.post(
      ApiConstants.deviceZones(deviceId),
      body: data,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> updateZone(
    String deviceId,
    String zoneId,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.patch(
      ApiConstants.deviceZone(deviceId, zoneId),
      body: data,
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteZone(String deviceId, String zoneId) async {
    final response =
        await _apiClient.delete(ApiConstants.deviceZone(deviceId, zoneId));
    return response.statusCode == 204 || response.statusCode == 200;
  }

  // ---- Contacts ----

  /// Kontaktlar — FAQAT serverdan (bo'sa `[]`).
  ///
  /// Server `contact_name`/`is_new` yuboradi, eski lokal jadval esa
  /// `name`/`is_blocked` saqlagan edi — mos kelmagandi.
  Future<List<Contact>> getContacts(String deviceId) async {
    try {
      final response =
          await _apiClient.get(ApiConstants.deviceContacts(deviceId));
      if (response.statusCode != 200) return [];

      final List<dynamic> data =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(Contact.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> updateContact(
    String deviceId,
    String contactId,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.patch(
      ApiConstants.deviceContact(deviceId, contactId),
      body: data,
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteContact(String deviceId, String contactId) async {
    final response = await _apiClient
        .delete(ApiConstants.deviceContact(deviceId, contactId));
    return response.statusCode == 204 || response.statusCode == 200;
  }

  // ---- App Time Limits ----

  /// Kunlik vaqt limitlari — serverdan ro'yxat.
  Future<List<AppTimeLimit>> getTimeLimits(String deviceId) async {
    try {
      final response =
          await _apiClient.get(ApiConstants.deviceTimeLimits(deviceId));
      if (response.statusCode != 200) return [];

      final List<dynamic> data =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(AppTimeLimit.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Yangi limit yaratish.
  ///
  /// DIQQAT: serverda `max_daily_minutes` 1..1440 oralig'ida bo'lishi
  /// shart. Avval `setAppLimit` hech qanday tekshiruvsiz `true` qaytardi —
  /// server 400 bersa ham ilova "muvaffaqiyatli" deb ko'rsatardi.
  Future<bool> setAppLimit(String deviceId, Map<String, dynamic> data) async {
    final response = await _apiClient.post(
      ApiConstants.deviceTimeLimits(deviceId),
      body: data,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> updateTimeLimit(
    String deviceId,
    String limitId,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.patch(
      ApiConstants.deviceTimeLimit(deviceId, limitId),
      body: data,
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteTimeLimit(String deviceId, String limitId) async {
    final response =
        await _apiClient.delete(ApiConstants.deviceTimeLimit(deviceId, limitId));
    return response.statusCode == 204 || response.statusCode == 200;
  }

  // ---- Device Events (ota-onaning uchun) ----

  /// Qurilma hodisalari tarixi (ulandi, bloklandi, SOS, batareya, zona).
  ///
  /// [eventType] va [days] — ixtiyoriy server tomonidagi filtrlar.
  Future<List<DeviceEvent>> getEvents(
    String deviceId, {
    String? eventType,
    int? days,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.deviceEventHistory(deviceId, eventType: eventType, days: days),
      );
      if (response.statusCode != 200) return [];

      final List<dynamic> data =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(DeviceEvent.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---- SOS Alerts ----
  // `SOSAlertSerializer` `latitude` va `longitude` maydonlarini majburiy qiladi.
  // Avval yuborilgan `{device_id, status, created_at}` tani serializer'da yo'q
  // edi -> har doim 400 ValidationError qaytardi.

  /// SOS signallari tarixi — ota-ona uchun.
  ///
  /// Avval faqat `POST` bor edi: bola yuborsa, ota-ona uni ilovada ko'ra
  /// olmasdi. [unresolvedOnly] faqat ko'rib chiqilmagan signallarni oladi.
  Future<List<SOSAlert>> getSOSAlerts(
    String deviceId, {
    bool unresolvedOnly = false,
  }) async {
    try {
      final url = unresolvedOnly
          ? '${ApiConstants.deviceSOS(deviceId)}?unresolved=1'
          : ApiConstants.deviceSOS(deviceId);
      final response = await _apiClient.get(url);
      if (response.statusCode != 200) return [];

      final List<dynamic> data =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(SOSAlert.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Ota-ona signalni ko'rib chiqganini belgilaydi.
  Future<bool> setSOSResolved(
    String deviceId,
    String alertId,
    bool resolved,
  ) async {
    final response = await _apiClient.patch(
      ApiConstants.deviceSOSDetail(deviceId, alertId),
      body: {'resolved': resolved},
    );
    return response.statusCode == 200;
  }

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
      return response.statusCode == 200 || response.statusCode == 201;
    } else {
      // Internet yo'q — keyinroq yuborish uchun navbatga solamiz
      await _db.addToSyncQueue(
        endpoint: ApiConstants.deviceSOS(deviceId),
        method: 'POST',
        body: jsonEncode(data),
      );
      return true; // Optimistic
    }
  }
}
