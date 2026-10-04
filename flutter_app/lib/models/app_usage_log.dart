class AppUsageLog {
  final String id;
  final String deviceId;
  final String packageName;
  final int totalTimeMs;
  final String startTime;
  final String endTime;
  final String recordedAt;

  AppUsageLog({
    required this.id,
    required this.deviceId,
    required this.packageName,
    required this.totalTimeMs,
    required this.startTime,
    required this.endTime,
    required this.recordedAt,
  });

  factory AppUsageLog.fromJson(Map<String, dynamic> json,
      {String deviceId = ''}) {
    return AppUsageLog(
      id: json['id'] as String,
      deviceId: deviceId,
      packageName: json['package_name'] as String? ?? '',
      totalTimeMs: json['total_time_in_foreground_ms'] as int? ?? 0,
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      recordedAt: json['recorded_at'] as String? ?? '',
    );
  }

  factory AppUsageLog.fromDb(Map<String, dynamic> row) {
    return AppUsageLog(
      id: row['id'] as String,
      deviceId: row['device_id'] as String,
      packageName: row['package_name'] as String? ?? '',
      totalTimeMs: row['total_time_ms'] as int? ?? 0,
      startTime: row['start_time'] as String? ?? '',
      endTime: row['end_time'] as String? ?? '',
      recordedAt: row['recorded_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'device_id': deviceId,
        'package_name': packageName,
        'total_time_ms': totalTimeMs,
        'start_time': startTime,
        'end_time': endTime,
        'recorded_at': recordedAt,
      };
}
