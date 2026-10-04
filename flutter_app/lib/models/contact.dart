class Contact {
  final String id;
  final String deviceId;
  final String name;
  final String phoneNumber;
  final bool isBlocked;
  final String? createdAt;

  Contact({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.phoneNumber,
    required this.isBlocked,
    this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String,
      isBlocked: json['is_blocked'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'name': name,
        'phone_number': phoneNumber,
        'is_blocked': isBlocked,
        'created_at': createdAt,
      };

  factory Contact.fromDb(Map<String, dynamic> row) {
    return Contact(
      id: row['id'] as String,
      deviceId: row['device_id'] as String,
      name: row['name'] as String,
      phoneNumber: row['phone_number'] as String,
      isBlocked: (row['is_blocked'] as int?) == 1,
      createdAt: row['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'device_id': deviceId,
        'name': name,
        'phone_number': phoneNumber,
        'is_blocked': isBlocked ? 1 : 0,
        'created_at': createdAt,
      };
}
