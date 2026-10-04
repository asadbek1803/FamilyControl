/// Bolaning yuborgan SOS signali.
///
/// `resolved` — ota-ona signalni ko'rib chiqganini belgilashi.
class SOSAlert {
  final String id;
  final double latitude;
  final double longitude;
  final bool resolved;
  final String? createdAt;

  const SOSAlert({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.resolved = false,
    this.createdAt,
  });

  factory SOSAlert.fromJson(Map<String, dynamic> json) {
    return SOSAlert(
      id: json['id'] as String,
      // `(x as num)` xatosi berishi mumkin — `null` yoki `String` kelsa
      // `toDouble()` chaqirilmaydi, 0 ga tushadi.
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      resolved: json['resolved'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'resolved': resolved,
        'created_at': createdAt,
      };

  SOSAlert copyWith({bool? resolved}) => SOSAlert(
        id: id,
        latitude: latitude,
        longitude: longitude,
        resolved: resolved ?? this.resolved,
        createdAt: createdAt,
      );
}