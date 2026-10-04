import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../models/child_device.dart';
import '../../models/sos_alert.dart';
import '../../providers/device_provider.dart';

/// SOS signallari — ota-ona uchun.
///
/// Oldin shu yerda hech narsa yo'q edi: `DeviceDetailScreen` dagi "SOS"
/// kartasi vaqtincha `AppsScreen` ga ochilardi. Signal kelganda ota-ona faqat
/// Telegram xabarini ko'rardi, ilovada esa uni ko'rib chiqib yopish mumkin
/// edi emas — natijada yechilmagan signallar doim "active" bo'lib qolardi.
class SosScreen extends StatefulWidget {
  final ChildDevice device;

  const SosScreen({super.key, required this.device});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _onlyUnresolved = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    return context.read<DeviceProvider>().loadSOSAlerts(
          widget.device.id,
          unresolvedOnly: _onlyUnresolved,
        );
  }

  Future<void> _markResolved(SOSAlert alert) async {
    final ok = await context
        .read<DeviceProvider>()
        .setSOSResolved(widget.device.id, alert.id, true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Signal yopildi'
            : 'Yopilmadi. Serverga ulanib, qayta urinib ko\'ring.'),
      ),
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Yordam signallari - ${widget.device.displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yangilash',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            dense: true,
            title: const Text(
              'Faqat ko\'rib chiqilmaganlar',
              style: TextStyle(fontSize: 13),
            ),
            value: _onlyUnresolved,
            onChanged: (value) {
              setState(() => _onlyUnresolved = value);
              _load();
            },
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody(provider)),
        ],
      ),
    );
  }

  Widget _buildBody(DeviceProvider provider) {
    if (provider.isLoading && provider.sosAlerts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final alerts = provider.sosAlerts;

    if (alerts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Icon(
              _onlyUnresolved ? Icons.check_circle : Icons.notifications_off,
              size: 72,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            Text(
              _onlyUnresolved
                  ? 'Kutilayotgan yordam signali yo\'q'
                  : 'Hali hech qanday signal kelmagan',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Bolangiz yordam so\'raganda signal shu yerda va\n'
              'Telegram\'da ko\'rinadi. Ko\'rib chiqqandan keyin\n'
              '"Ko\'rildi" bilan yopishingiz mumkin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final unresolved = alerts.where((a) => !a.resolved).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: alerts.length + (unresolved > 0 ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, index) {
          if (unresolved > 0 && index == 0) {
            return _UnresolvedBanner(count: unresolved);
          }
          final alert = alerts[index - (unresolved > 0 ? 1 : 0)];
          return _AlertTile(
            alert: alert,
            onResolve: () => _markResolved(alert),
          );
        },
      ),
    );
  }
}

class _UnresolvedBanner extends StatelessWidget {
  final int count;

  const _UnresolvedBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.sos, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count ta signali ko\'rib chiqilmagan',
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final SOSAlert alert;
  final VoidCallback onResolve;

  const _AlertTile({required this.alert, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        alert.resolved ? Icons.check_circle : Icons.sos,
        color: alert.resolved ? Colors.green : Colors.red,
        size: 32,
      ),
      title: Text(
        alert.resolved ? 'Yopilgan signal' : 'Yordam signali!',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: alert.resolved ? Colors.grey : Colors.red,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            AppDateUtils.formatDateTime(alert.createdAt),
            style: const TextStyle(fontSize: 12),
          ),
          // Joylashuv — faqat SOS signalida. Bu maxsus holat: bola yordam
          // so'raganda ota-onaga joylashuvni ko'rsatish kerak, aks holda
          // u "yordam berish" uchun qancha yo'l yurishini bilmaydi.
          Text(
            '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      trailing: alert.resolved
          ? null
          : TextButton.icon(
              onPressed: onResolve,
              icon: const Icon(Icons.done, size: 18),
              label: const Text('Ko\'rildi'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
                visualDensity: VisualDensity.compact,
              ),
            ),
    );
  }
}
