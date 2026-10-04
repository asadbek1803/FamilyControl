class GeoZone {
  final String id;
  final String deviceId;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final String? createdAt;

  GeoZone({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.createdAt,
  });

  factory GeoZone.fromJson(Map<String, dynamic> json) {
    return GeoZone(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'created_at': createdAt,
      };

  factory GeoZone.fromDb(Map<String, dynamic> row) {
    return GeoZone(
      id: row['id'] as String,
      deviceId: row['device_id'] as String,
      name: row['name'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      radius: (row['radius'] as num).toDouble(),
      createdAt: row['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'device_id': deviceId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'created_at': createdAt,
      };
}
