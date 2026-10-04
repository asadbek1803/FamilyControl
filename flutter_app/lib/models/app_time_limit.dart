/// Ilovaning kunlik foydalanish vaqti limiti.
///
/// XATO (tuzatildi): avvalgi model serverdan kelmaydigan maydonlarni kutardi
/// (`device_id`, `limit_minutes`, `is_blocked`). Server esa `package_name`,
/// `max_daily_minutes`, `block_after_time`, `is_active` qaytaradi. Sababi:
/// `json['device_id'] as String` `null` uchun TypeError berib, butun
/// `getTimeLimits` chaqiruvini sindirardi.
class AppTimeLimit {
  final String id;
  final String packageName;
  final int maxDailyMinutes;
  final bool isActive;

  /// `block_after_time` — "soat 21:00 dan keyin bloklanadi" (`HH:MM`).
  /// `null` bo'lsa faqat kunlik limit qo'llaniladi.
  final String? blockAfterTime;

  const AppTimeLimit({
    required this.id,
    required this.packageName,
    required this.maxDailyMinutes,
    this.isActive = true,
    this.blockAfterTime,
  });

  factory AppTimeLimit.fromJson(Map<String, dynamic> json) {
    return AppTimeLimit(
      id: json['id'] as String,
      packageName: json['package_name'] as String? ?? '',
      maxDailyMinutes: (json['max_daily_minutes'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      blockAfterTime: json['block_after_time'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'package_name': packageName,
        'max_daily_minutes': maxDailyMinutes,
        'is_active': isActive,
        'block_after_time': blockAfterTime,
      };

  AppTimeLimit copyWith({bool? isActive, int? maxDailyMinutes}) =>
      AppTimeLimit(
        id: id,
        packageName: packageName,
        maxDailyMinutes: maxDailyMinutes ?? this.maxDailyMinutes,
        isActive: isActive ?? this.isActive,
        blockAfterTime: blockAfterTime,
      );
}