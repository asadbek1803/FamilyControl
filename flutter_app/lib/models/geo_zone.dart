/// Xavfsizlik zonasi — bolaning bo'lishi kerak bo'lgan joy.
///
/// XATO (tuzatildi): avvalgi model server javobiga mos kelmasdi — u
/// `latitude`, `longitude`, `radius` maydonlarini kutardi, server esa faqat
/// `radius_meters` qaytarardi. Natijada `fromJson` har doim `null`ni
/// `double` ga o'girishda xato berar va zona ro'yxati bo'sh chiqardi.
///
/// Hozir server ham `latitude`/`longitude` qaytaradi (0/0 qabul qilinmaydi —
/// bu Osiyo chekkasidagi nuqta).
class GeoZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String? createdAt;

  const GeoZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.createdAt,
  });

  factory GeoZone.fromJson(Map<String, dynamic> json) {
    return GeoZone(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'created_at': createdAt,
      };

  /// Lokal bazadagi eski `geo_zones` jadvali `radius` ustunini ishlatadi,
  /// `latitude`/`longitude` esa `NOT NULL` — shuning uchun `device_id` ham
  /// kerak. Bu fallback `DeviceRepository.getZones` da ishlatiladi.
  factory GeoZone.fromDb(Map<String, dynamic> row, {String deviceId = ''}) {
    return GeoZone(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (row['radius'] as num?)?.toDouble() ?? 0.0,
      createdAt: row['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb({String deviceId = ''}) => {
        'id': id,
        'device_id': deviceId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radiusMeters,
        'created_at': createdAt,
      };
}