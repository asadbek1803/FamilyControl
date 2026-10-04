import 'dart:convert';
import '../core/network/api_client.dart';
import '../core/database/local_database.dart';
import '../core/constants/api_constants.dart';

class SyncRepository {
  final _apiClient = ApiClient();
  final _db = LocalDatabase.instance;

  /// Internet qayta tiklanganda offline queudagi so'rovlarni bajaradi
  Future<void> processQueue() async {
    final items = await _db.getPendingSyncItems();

    for (final item in items) {
      final id = item['id'] as int;
      final endpoint = item['endpoint'] as String;
      final method = item['method'] as String;
      final bodyStr = item['body'] as String?;

      Map<String, dynamic>? body;
      if (bodyStr != null && bodyStr.isNotEmpty) {
        try {
          body = jsonDecode(bodyStr) as Map<String, dynamic>;
        } catch (_) {}
      }

      try {
        final response = method == 'PATCH'
            ? await _apiClient.patch(endpoint, body: body)
            : await _apiClient.post(endpoint, body: body);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _db.deleteSyncItem(id);
        } else {
          await _db.incrementSyncRetry(id);
        }
      } catch (_) {
        await _db.incrementSyncRetry(id);
      }
    }
  }
}
