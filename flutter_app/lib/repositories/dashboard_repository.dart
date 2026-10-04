import 'dart:convert';

import '../core/network/api_client.dart';
import '../core/network/connectivity_service.dart';
import '../core/constants/api_constants.dart';
import '../models/parent_dashboard.dart';

/// `GET /dashboard/` — ota-onaning barcha farzandlari bir so'rovda.
///
/// Nima uchun alohida repository: panel ma'lumotni serverdan agregatsiya
/// qilib oladi. Ilova tomonda har bir qurilma uchun alohida so'rov yuborish
/// (N+1) 10 ta farzandda 60+ so'rovga chiqardi va sekinlashardi.
class DashboardRepository {
  final _apiClient = ApiClient();
  final _connectivity = ConnectivityService();

  Future<ParentDashboard?> getDashboard() async {
    final isOnline = await _connectivity.isOnline;
    if (!isOnline) return null;

    try {
      final response = await _apiClient.get(ApiConstants.dashboard);
      if (response.statusCode != 200) return null;

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return ParentDashboard.fromJson(data);
    } catch (_) {
      // Panel qaytarsa bo'sh ekran ko'rsatadi — jim qolish ma'qul, chunki
      // `DashboardProvider` allaqach `null` ni "server topilmadi" deb
      // ko'rsatadi.
      return null;
    }
  }
}