import 'child_device.dart';
import 'device_event.dart';

/// `GET /dashboard/` javobi — ota-onaning barcha farzandlari bir so'rovda.
///
/// Nima uchun alohida model: avval har bir bo'limga o'tish uchun avval bitta
/// qurilma tanlash kerak edi, shuning uchun bir nechta farzandni bir vaqtda
/// ko'rib bo'lmasdi. Endi server barchasini yig'ib beradi.
class ParentDashboard {
  final String generatedAt;
  final DashboardSummary summary;
  final List<ChildSummary> children;
  final List<DeviceEvent> recentEvents;

  const ParentDashboard({
    required this.generatedAt,
    required this.summary,
    required this.children,
    required this.recentEvents,
  });

  bool get hasChildren => children.isNotEmpty;

  bool get hasActiveSos => summary.activeSosCount > 0;

  factory ParentDashboard.fromJson(Map<String, dynamic> json) {
    final summaryJson = (json['summary'] as Map<String, dynamic>?) ?? {};
    final childrenJson = (json['children'] as List<dynamic>?) ?? [];
    final eventsJson = (json['recent_events'] as List<dynamic>?) ?? [];

    return ParentDashboard(
      generatedAt: json['generated_at'] as String? ?? '',
      summary: DashboardSummary.fromJson(summaryJson),
      children: childrenJson
          .whereType<Map<String, dynamic>>()
          .map(ChildSummary.fromJson)
          .toList(),
      recentEvents: eventsJson
          .whereType<Map<String, dynamic>>()
          .map(DeviceEvent.fromJson)
          .toList(),
    );
  }

  factory ParentDashboard.empty() => ParentDashboard(
        generatedAt: '',
        summary: const DashboardSummary(),
        children: const [],
        recentEvents: const [],
      );
}

/// Butun oila bo'yicha umumiy raqamlar.
class DashboardSummary {
  final int childrenCount;
  final int devicesCount;
  final int onlineCount;
  final int lowBatteryCount;
  final int blockedAppsCount;
  final int activeSosCount;
  final int todayScreenTimeMs;

  const DashboardSummary({
    this.childrenCount = 0,
    this.devicesCount = 0,
    this.onlineCount = 0,
    this.lowBatteryCount = 0,
    this.blockedAppsCount = 0,
    this.activeSosCount = 0,
    this.todayScreenTimeMs = 0,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      childrenCount: (json['children_count'] as num?)?.toInt() ?? 0,
      devicesCount: (json['devices_count'] as num?)?.toInt() ?? 0,
      onlineCount: (json['online_count'] as num?)?.toInt() ?? 0,
      lowBatteryCount: (json['low_battery_count'] as num?)?.toInt() ?? 0,
      blockedAppsCount: (json['blocked_apps_count'] as num?)?.toInt() ?? 0,
      activeSosCount: (json['active_sos_count'] as num?)?.toInt() ?? 0,
      todayScreenTimeMs: (json['today_screen_time_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Bitta farzand va uning qurilmalari.
class ChildSummary {
  final String childName;
  final int devicesCount;
  final int onlineCount;
  final int todayScreenTimeMs;
  final List<DeviceSummary> devices;

  const ChildSummary({
    required this.childName,
    required this.devicesCount,
    required this.onlineCount,
    required this.todayScreenTimeMs,
    required this.devices,
  });

  factory ChildSummary.fromJson(Map<String, dynamic> json) {
    return ChildSummary(
      childName: json['child_name'] as String? ?? 'Nomsiz farzand',
      devicesCount: (json['devices_count'] as num?)?.toInt() ?? 0,
      onlineCount: (json['online_count'] as num?)?.toInt() ?? 0,
      todayScreenTimeMs: (json['today_screen_time_ms'] as num?)?.toInt() ?? 0,
      devices: (json['devices'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DeviceSummary.fromJson)
          .toList(),
    );
  }
}

/// Bitta qurilmaning panel uchun holati.
class DeviceSummary {
  final String id;
  final String deviceName;
  final String childName;
  final bool isActive;
  final bool isPaired;
  final double? batteryLevel;
  final String? lastSeen;
  final int todayScreenTimeMs;
  final int installedAppsCount;
  final int blockedAppsCount;
  final int contactsCount;
  final int zonesCount;
  final int activeLimitsCount;
  final int activeSosCount;
  final String? lastSosAt;
  final String? lastEventType;
  final String? lastEventMessage;
  final String? lastEventAt;

  const DeviceSummary({
    required this.id,
    required this.deviceName,
    required this.childName,
    required this.isActive,
    required this.isPaired,
    required this.todayScreenTimeMs,
    required this.installedAppsCount,
    required this.blockedAppsCount,
    required this.contactsCount,
    required this.zonesCount,
    required this.activeLimitsCount,
    required this.activeSosCount,
    this.batteryLevel,
    this.lastSeen,
    this.lastSosAt,
    this.lastEventType,
    this.lastEventMessage,
    this.lastEventAt,
  });

  bool get hasActiveSos => activeSosCount > 0;

  /// Batareya "qullab qolmoqda" — server bilan bir xil chegara (20%).
  bool get isBatteryLow =>
      batteryLevel != null && batteryLevel! <= 20;

  /// Paneldan boshqa bo'limlarga o'tish uchun `ChildDevice`.
  ///
  /// Panel barcha ma'lumotni bitta agregatsiyada qaytaradi, shuning uchun
  /// `device_identifier` va `created_at` maydonlari yo'q — ular bu ekranlar
  /// uchun kerak emas (nomi va `id` yetarli).
  ChildDevice toChildDevice() => ChildDevice(
        id: id,
        deviceIdentifier: '',
        deviceName: deviceName,
        childName: childName,
        isActive: isActive,
        isPaired: isPaired,
        batteryLevel: batteryLevel,
        lastSeen: lastSeen,
        createdAt: null,
      );

  factory DeviceSummary.fromJson(Map<String, dynamic> json) {
    return DeviceSummary(
      id: json['id'] as String,
      deviceName: json['device_name'] as String? ?? '',
      childName: json['child_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      isPaired: json['is_paired'] as bool? ?? false,
      batteryLevel: (json['battery_level'] as num?)?.toDouble(),
      lastSeen: json['last_seen'] as String?,
      todayScreenTimeMs: (json['today_screen_time_ms'] as num?)?.toInt() ?? 0,
      installedAppsCount: (json['installed_apps_count'] as num?)?.toInt() ?? 0,
      blockedAppsCount: (json['blocked_apps_count'] as num?)?.toInt() ?? 0,
      contactsCount: (json['contacts_count'] as num?)?.toInt() ?? 0,
      zonesCount: (json['zones_count'] as num?)?.toInt() ?? 0,
      activeLimitsCount: (json['active_limits_count'] as num?)?.toInt() ?? 0,
      activeSosCount: (json['active_sos_count'] as num?)?.toInt() ?? 0,
      lastSosAt: json['last_sos_at'] as String?,
      lastEventType: json['last_event_type'] as String?,
      lastEventMessage: json['last_event_message'] as String?,
      lastEventAt: json['last_event_at'] as String?,
    );
  }
}