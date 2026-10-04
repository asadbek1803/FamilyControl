import 'package:flutter/material.dart';

import '../models/parent_dashboard.dart';
import '../repositories/dashboard_repository.dart';

/// Ota-onaning boshqaruv paneli — barcha farzandlar uchun umumiy holat.
class DashboardProvider extends ChangeNotifier {
  final _repo = DashboardRepository();

  ParentDashboard? _dashboard;
  bool _isLoading = false;

  /// Serverga ulanib bo'lmagan holat (internet yo'q yoki 401).
  String? _errorMessage;

  ParentDashboard? get dashboard => _dashboard;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasData => _dashboard != null;

  /// Panel bo'sh bo'lib chiqsa (hali birorta qurilma ulanmagan).
  bool get isEmpty => _dashboard != null && !_dashboard!.hasChildren;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repo.getDashboard();

    if (result == null) {
      // Aniq sababni aytmaymiz: `ApiClient` 401 da token'ni yangilashga
      // urunadi, undan keyin ham ishlamasa sabab ko'p (internet yo'q, server
      // o'chgan, akkaunt bekor qilingan). "Internetni tekshiring" desak,
      // internet bor holatda ham noto'g'ri ko'rsatma bo'ladi.
      _errorMessage = 'Panelni yuklab bo\'lmadi. Serverga ulanib, qayta '
          'urinib ko\'ring.';
      // Eski ma'lumotni saqlab qolamiz: ota-ona oflayn holatda ham oxirgi
      // holatni ko'raverishi kerak (faqat "yangilanmagan" belgisi bilan).
    } else {
      _dashboard = result;
    }

    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _dashboard = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}