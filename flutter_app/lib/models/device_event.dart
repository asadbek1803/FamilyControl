/// Qurilma yuborgan yoki server yaratgan hodisa.
///
/// DIQQAT ( chegaraviy ): bu FAQAT ilova va qurilma holati hodisalari —
/// ulandi, bloklandi, SOS, batareya, himoya o'chirildi, zonadan chiqdi.
/// Boshqa ilovalarning xabarlari yoki chat yozishmalari bu modelga
/// KIRMAYDI (serverda `DeviceEvent` shunday hujjatlashtirilgan).
class DeviceEvent {
  final String id;
  final String eventType;
  final String message;

  /// Hodisaga qo'shimcha ma'lumot (masalan `{"percent": 12}`).
  final Map<String, dynamic> data;

  final String? createdAt;

  const DeviceEvent({
    required this.id,
    required this.eventType,
    required this.message,
    this.data = const {},
    this.createdAt,
  });

  // Server'dagi `DeviceEvent.EVENT_*` qiymatlariga mos.
  static const String typePaired = 'paired';
  static const String typeUnpaired = 'unpaired';
  static const String typeSos = 'sos';
  static const String typeBatteryLow = 'battery_low';
  static const String typeAdminDisabled = 'admin_disabled';
  static const String typeAdminEnabled = 'admin_enabled';
  static const String typeChildModeEnabled = 'child_mode_enabled';
  static const String typeZoneExit = 'zone_exit';
  static const String typeAppBlocked = 'app_blocked';
  static const String typeAppUnblocked = 'app_unblocked';

  factory DeviceEvent.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return DeviceEvent(
      id: json['id'] as String,
      eventType: json['event_type'] as String? ?? '',
      message: json['message'] as String? ?? '',
      data: raw is Map<String, dynamic> ? raw : const {},
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_type': eventType,
        'message': message,
        'data': data,
        'created_at': createdAt,
      };

  /// Ota-onaga alohida ahamiyat berish kerakmi (panelda ajratib ko'rsatish).
  ///
  /// `admin_disabled` — bola himoyani o'chirgani; `sos` — aniq yordam
  /// so'rovi. Ikkalasi ham darhol ko'rinishi kerak.
  bool get isUrgent =>
      eventType == typeAdminDisabled ||
      eventType == typeSos ||
      eventType == typeBatteryLow;
}