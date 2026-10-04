class ChildDevice {
  final String id;
  final String deviceIdentifier;
  final String deviceName;

  /// Qurilma qaysi farzandga tegishli. Ota-onaning ilovasidan belgilanadi
  /// (`PATCH /devices/<id>/`). Bo'sh bo'lsa, panelda qurilma nomi ko'rsatiladi.
  final String childName;

  final bool isActive;

  /// Server bilan bog'langanmi (`is_active` ham `True` bo'lishi kerak).
  /// Faqat `isActive` bo'lsa yetarli emas: qurilma `is_active=True` bo'lib,
  /// lekin hali hech kimga ulanmagan holatda ham bo'lishi mumkin.
  final bool isPaired;

  final double? batteryLevel;
  final String? lastSeen;
  final String? createdAt;

  ChildDevice({
    required this.id,
    required this.deviceIdentifier,
    required this.deviceName,
    required this.isActive,
    this.childName = '',
    this.isPaired = false,
    this.batteryLevel,
    this.lastSeen,
    this.createdAt,
  });

  /// Boshqaruv panelida va ro'yxatlarda ko'rsatiladigan nom.
  ///
  /// Farzand nomi bo'lsa u, aks holda qurilma nomi, oxirida esa identifikator.
  String get displayName {
    if (childName.trim().isNotEmpty) return childName.trim();
    if (deviceName.trim().isNotEmpty) return deviceName.trim();
    return deviceIdentifier;
  }

  factory ChildDevice.fromJson(Map<String, dynamic> json) {
    return ChildDevice(
      id: json['id'] as String,
      deviceIdentifier: json['device_identifier'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      childName: json['child_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      isPaired: json['is_paired'] as bool? ?? false,
      batteryLevel: (json['battery_level'] as num?)?.toDouble(),
      lastSeen: json['last_seen'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_identifier': deviceIdentifier,
        'device_name': deviceName,
        'child_name': childName,
        'is_active': isActive,
        'is_paired': isPaired,
        'battery_level': batteryLevel,
        'last_seen': lastSeen,
        'created_at': createdAt,
      };

  factory ChildDevice.fromDb(Map<String, dynamic> row) {
    return ChildDevice(
      id: row['id'] as String,
      deviceIdentifier: row['device_identifier'] as String? ?? '',
      deviceName: row['device_name'] as String? ?? '',
      childName: row['child_name'] as String? ?? '',
      isActive: (row['is_active'] as int?) == 1,
      // Lokal bazada `is_paired` ustuni yo'q — `is_active` ni teng deb olamiz.
      isPaired: (row['is_active'] as int?) == 1,
      batteryLevel: row['battery_level'] as double?,
      lastSeen: row['last_seen'] as String?,
      createdAt: row['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'device_identifier': deviceIdentifier,
        'device_name': deviceName,
        'child_name': childName,
        'is_active': isActive ? 1 : 0,
        'battery_level': batteryLevel,
        'last_seen': lastSeen,
        'created_at': createdAt,
      };

  ChildDevice copyWith({
    String? id,
    String? deviceIdentifier,
    String? deviceName,
    String? childName,
    bool? isActive,
    bool? isPaired,
    double? batteryLevel,
    String? lastSeen,
    String? createdAt,
  }) {
    return ChildDevice(
      id: id ?? this.id,
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
      deviceName: deviceName ?? this.deviceName,
      childName: childName ?? this.childName,
      isActive: isActive ?? this.isActive,
      isPaired: isPaired ?? this.isPaired,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}