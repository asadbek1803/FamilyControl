class NotificationLog {
  final String id;
  final String deviceId;
  final String packageName;
  final String title;
  final String text;
  final String recordedAt;

  NotificationLog({
    required this.id,
    required this.deviceId,
    required this.packageName,
    required this.title,
    required this.text,
    required this.recordedAt,
  });

  factory NotificationLog.fromJson(Map<String, dynamic> json,
      {String deviceId = ''}) {
    return NotificationLog(
      id: json['id'] as String,
      deviceId: deviceId,
      packageName: json['package_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      recordedAt: json['recorded_at'] as String? ?? '',
    );
  }

  factory NotificationLog.fromDb(Map<String, dynamic> row) {
    return NotificationLog(
      id: row['id'] as String,
      deviceId: row['device_id'] as String,
      packageName: row['package_name'] as String? ?? '',
      title: row['title'] as String? ?? '',
      text: row['notification_text'] as String? ?? '',
      recordedAt: row['recorded_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'device_id': deviceId,
        'package_name': packageName,
        'title': title,
        'notification_text': text,
        'recorded_at': recordedAt,
      };
}
