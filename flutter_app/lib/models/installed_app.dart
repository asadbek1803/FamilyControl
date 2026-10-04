class InstalledApp {
  final String id;
  final String deviceId;
  final String appName;
  final String packageName;
  final bool isBlocked;
  final String? updatedAt;

  InstalledApp({
    required this.id,
    required this.deviceId,
    required this.appName,
    required this.packageName,
    required this.isBlocked,
    this.updatedAt,
  });

  factory InstalledApp.fromJson(Map<String, dynamic> json,
      {String deviceId = ''}) {
    return InstalledApp(
      id: json['id'] as String,
      deviceId: deviceId,
      appName: json['app_name'] as String? ?? '',
      packageName: json['package_name'] as String? ?? '',
      isBlocked: json['is_blocked'] as bool? ?? false,
      updatedAt: json['updated_at'] as String?,
    );
  }

  factory InstalledApp.fromDb(Map<String, dynamic> row) {
    return InstalledApp(
      id: row['id'] as String,
      deviceId: row['device_id'] as String,
      appName: row['app_name'] as String? ?? '',
      packageName: row['package_name'] as String? ?? '',
      isBlocked: (row['is_blocked'] as int?) == 1,
      updatedAt: row['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'device_id': deviceId,
        'app_name': appName,
        'package_name': packageName,
        'is_blocked': isBlocked ? 1 : 0,
        'updated_at': updatedAt,
      };

  InstalledApp copyWith({bool? isBlocked}) {
    return InstalledApp(
      id: id,
      deviceId: deviceId,
      appName: appName,
      packageName: packageName,
      isBlocked: isBlocked ?? this.isBlocked,
      updatedAt: updatedAt,
    );
  }
}
