/// Bolaning qurilmasidagi kontakt.
///
/// XATO (tuzatildi): server `contact_name` va `is_new` yuboradi, model esa
/// `name` va `is_blocked` kutardi. `json['name'] as String` `null` uchun
/// TypeError berar edi — `getContacts` ichidagi `try` uni yutib, kontaktlar
/// ro'yxati doim bo'sh chiqardi (xato foydalanuvchiga ko'rinmasdi).
class Contact {
  final String id;
  final String contactName;
  final String phoneNumber;

  /// Qurilmada yangi kontakt qo'shilganmi.
  final bool isNew;

  final String? updatedAt;

  const Contact({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    this.isNew = false,
    this.updatedAt,
  });

  String get name => contactName;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      contactName: json['contact_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      isNew: json['is_new'] as bool? ?? false,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contact_name': contactName,
        'phone_number': phoneNumber,
        'is_new': isNew,
        'updated_at': updatedAt,
      };
}