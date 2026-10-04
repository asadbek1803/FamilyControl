import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../models/child_device.dart';
import '../../models/notification_log.dart';
import '../../providers/device_provider.dart';

/// Bildirishnomalar tarixi.
///
/// ---------------------------------------------------------------------------
/// CHEGARA (bu eklan haqiqiy): Android ilovasi bu ma'lumotni yig'maydi.
///
/// Android manifestida `NotificationListenerService` yo'q — ya'ni boshqa
/// ilovalarning bildirishnoma matni o'qilmaydi. `ChildAccessibilityService`
/// esa faqat "Sozlamalar" va ilova o'rnatish ekranlarini PIN bilan bloklaydi.
///
/// Shuning uchun bu ro'yxat amalda DOIM bo'sh bo'ladi. Ekran bo'sh holatni
/// tushuntiruvchi matn bilan ko'rsatadi — aks holda foydalanuvchi "ilova
/// buzilgan" deb o'ylaydi va xato xabar yuboradi.
///
/// Nima uchun bu eklan umuman bor: serverda `NotificationLog` modeli va
/// `GET /devices/<id>/notifications/` endpointi mavjud. Ularni olib tashlash
/// boshqa vazifa; hozirgi holatda esa hech qanday maxfiy ma'lumot
/// ko'rsatilmaydi, chunki hech narsa yig'ilmaydi.
/// ---------------------------------------------------------------------------
class NotificationsScreen extends StatefulWidget {
  final ChildDevice device;

  const NotificationsScreen({super.key, required this.device});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadNotifications(widget.device.id);
    });
  }

  Future<void> _load() =>
      context.read<DeviceProvider>().loadNotifications(widget.device.id);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final logs = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirishnomalar - ${widget.device.displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yangilash',
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(provider, logs),
    );
  }

  Widget _buildBody(DeviceProvider provider, List<NotificationLog> logs) {
    if (provider.isLoading && logs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (logs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            Icon(Icons.notifications_off, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Bildirishnoma yig\'ilmaydi',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user,
                            color: Colors.green[800], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Bu maxfiylik uchun ataylab qilingan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'FamilyControl boshqa ilovalarning bildirishnoma '
                      'matnini o\'qimaydi. Shuning uchun bu yerda SMS, chat '
                      'yoki boshqa ilova xabarlari KO\'RINMAYDI.',
                      style: TextStyle(fontSize: 13, color: Colors.green[900]),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Siz ota-onalik nazorati uchun qulay bo\'lgan '
                      'ma\'lumotlarni ko\'rasiz: ilovalar, ekran vaqti, '
                      'joylashuv, bloklangan ilovalar va qurilma holati.',
                      style: TextStyle(fontSize: 13, color: Colors.green[800]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Ma'lumot bo'lsa (kelajakda Android service qo'shilsa) — ko'rsatamiz.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: logs.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final log = logs[index];
          return ListTile(
            leading: const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue,
              child: Icon(Icons.notifications, color: Colors.white, size: 20),
            ),
            title: Text(log.title, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              '${log.packageName}\n${AppDateUtils.formatDateTime(log.recordedAt)}',
              style: const TextStyle(fontSize: 11),
            ),
            isThreeLine: log.text.isNotEmpty,
          );
        },
      ),
    );
  }
}
