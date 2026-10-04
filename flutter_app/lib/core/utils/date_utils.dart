import 'package:intl/intl.dart';

class AppDateUtils {
  static String formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Noma\'lum';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  static String formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Noma\'lum';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd.MM.yyyy').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  static String formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '$hours soat $minutes daqiqa';
    return '$minutes daqiqa';
  }

  static String timeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Hech qachon';
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Hozir';
      if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
      if (diff.inHours < 24) return '${diff.inHours} soat oldin';
      return '${diff.inDays} kun oldin';
    } catch (_) {
      return isoString;
    }
  }
}
