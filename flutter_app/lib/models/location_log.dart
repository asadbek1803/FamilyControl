class LocationLog {
  final String id;
  final String deviceId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String recordedAt;

  LocationLog({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.recordedAt,
  });

  factory LocationLog.fromJson(Map<String, dynamic> json,
      {String deviceId = ''}) {
    return LocationLog(
      id: json['id'] as String,
      deviceId: deviceId,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      recordedAt: json['recorded_at'] as String,
    );
  }

  factory LocationLog.fromDb(Map<String, dynamic> row) {
    return LocationLog(
      id: row['id'] as String,
      deviceId: row['device_id'] as String,
      latitude: row['latitude'] as double,
      longitude: row['longitude'] as double,
      accuracy: row['accuracy'] as double?,
      recordedAt: row['recorded_at'] as String,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'device_id': deviceId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'recorded_at': recordedAt,
      };
}
