class ChildDevice {
  final String id;
  final String deviceIdentifier;
  final String deviceName;
  final bool isActive;
  final double? batteryLevel;
  final String? lastSeen;
  final String? createdAt;

  ChildDevice({
    required this.id,
    required this.deviceIdentifier,
    required this.deviceName,
    required this.isActive,
    this.batteryLevel,
    this.lastSeen,
    this.createdAt,
  });

  factory ChildDevice.fromJson(Map<String, dynamic> json) {
    return ChildDevice(
      id: json['id'] as String,
      deviceIdentifier: json['device_identifier'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      batteryLevel: (json['battery_level'] as num?)?.toDouble(),
      lastSeen: json['last_seen'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_identifier': deviceIdentifier,
        'device_name': deviceName,
        'is_active': isActive,
        'battery_level': batteryLevel,
        'last_seen': lastSeen,
        'created_at': createdAt,
      };

  factory ChildDevice.fromDb(Map<String, dynamic> row) {
    return ChildDevice(
      id: row['id'] as String,
      deviceIdentifier: row['device_identifier'] as String? ?? '',
      deviceName: row['device_name'] as String? ?? '',
      isActive: (row['is_active'] as int?) == 1,
      batteryLevel: row['battery_level'] as double?,
      lastSeen: row['last_seen'] as String?,
      createdAt: row['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'device_identifier': deviceIdentifier,
        'device_name': deviceName,
        'is_active': isActive ? 1 : 0,
        'battery_level': batteryLevel,
        'last_seen': lastSeen,
        'created_at': createdAt,
      };

  ChildDevice copyWith({
    String? id,
    String? deviceIdentifier,
    String? deviceName,
    bool? isActive,
    double? batteryLevel,
    String? lastSeen,
    String? createdAt,
  }) {
    return ChildDevice(
      id: id ?? this.id,
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
      deviceName: deviceName ?? this.deviceName,
      isActive: isActive ?? this.isActive,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
