class AppTimeLimit {
  final String id;
  final String deviceId;
  final String packageName;
  final int limitMinutes;
  final bool isBlocked;
  final String? createdAt;

  AppTimeLimit({
    required this.id,
    required this.deviceId,
    required this.packageName,
    required this.limitMinutes,
    required this.isBlocked,
    this.createdAt,
  });

  factory AppTimeLimit.fromJson(Map<String, dynamic> json) {
    return AppTimeLimit(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      packageName: json['package_name'] as String,
      limitMinutes: json['limit_minutes'] as int? ?? 0,
      isBlocked: json['is_blocked'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'package_name': packageName,
        'limit_minutes': limitMinutes,
        'is_blocked': isBlocked,
        'created_at': createdAt,
      };

  factory AppTimeLimit.fromDb(Map<String, dynamic> row) {
    return AppTimeLimit(
      id: row['id'] as String,
      deviceId: row['device_id'] as String,
      packageName: row['package_name'] as String,
      limitMinutes: row['limit_minutes'] as int? ?? 0,
      isBlocked: (row['is_blocked'] as int?) == 1,
      createdAt: row['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'device_id': deviceId,
        'package_name': packageName,
        'limit_minutes': limitMinutes,
        'is_blocked': isBlocked ? 1 : 0,
        'created_at': createdAt,
      };
}
