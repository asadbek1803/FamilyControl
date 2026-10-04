import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/event_presentation.dart';
import '../../models/device_event.dart';
import '../../models/parent_dashboard.dart';
import '../../providers/dashboard_provider.dart';
import '../devices/device_detail_screen.dart';

/// Ota-onaning boshqaruv paneli — BARCHA farzandlar bir ekranda.
///
/// Bu ekran butun ilovaning markaziy bo'limi: avval har bir bo'limga o'tish
/// uchun avval bitta qurilma tanlash kerak edi, shuning uchun bir nechta
/// farzandni yonma-yon solishtirib bo'lmasdi.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  Future<void> _refresh() => context.read<DashboardProvider>().load();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final dashboard = provider.dashboard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boshqaruv paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yangilash',
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(provider, dashboard),
      ),
    );
  }

  Widget _buildBody(DashboardProvider provider, ParentDashboard? dashboard) {
    if (dashboard == null) {
      if (provider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.cloud_off, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            provider.errorMessage ?? 'Panelni yuklab bo\'lmadi',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Internetni tekshirib, qayta urinib ko\'ring',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Qayta urinish'),
            ),
          ),
        ],
      );
    }

    if (!dashboard.hasChildren) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.family_restroom, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Hali birorta farzand ulanmagan',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Asosiy menyudan "Qurilma ulash" orqali bolaning telefonini\n'
            'pairing code bilan ulang. Ulanganach haqiqiy ma\'lumot ko\'rinadi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (dashboard.hasActiveSos) _SosBanner(dashboard: dashboard),
        if (provider.errorMessage != null) _StaleDataNotice(message: provider.errorMessage!),
        _SummaryCard(summary: dashboard.summary),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Farzandlar',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${dashboard.children.length} ta',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final child in dashboard.children) ...[
          _ChildCard(child: child),
          const SizedBox(height: 12),
        ],
        if (dashboard.recentEvents.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Oxirgi hodisalar',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _RecentEventsCard(events: dashboard.recentEvents),
        ],
      ],
    );
  }
}

/// Yechilmagan SOS borligini bildiruvchi qizil banner.
///
/// Bu panelning eng muhim qismi: shu signalni ko'rmay qolish ota-onaning
/// eng ko'p e'tibor beradigan vazifasidan biri chig'ishiga olib keladi.
class _SosBanner extends StatelessWidget {
  final ParentDashboard dashboard;

  const _SosBanner({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.sos, color: Colors.red.shade700, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dashboard.summary.activeSosCount == 1
                      ? 'Yordam signali!'
                      : '${dashboard.summary.activeSosCount} ta yordam signali!',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bolangiz yordam so\'radi. Signalni ko\'rib chiqing.',
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eski ma'lumot ko'rsatilayotganini ogohlantirish.
///
/// Panel internet yo'q holatda eski ma'lumotni ko'rsatadi — bu yaxshi, lekin
/// ota-ona "hozirgi" deb tushmasligi kerak.
class _StaleDataNotice extends StatelessWidget {
  final String message;

  const _StaleDataNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 20, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$message Ko\'rsatilgan ma\'lumot eski bo\'lishi mumkin.',
              style: const TextStyle(fontSize: 12, color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }
}

/// Butun oila bo'yicha umumiy raqamlar.
class _SummaryCard extends StatelessWidget {
  final DashboardSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bugungi umumiy holat',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.family_restroom,
                    value: '${summary.childrenCount}',
                    label: 'farzand',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    icon: Icons.wifi_tethering,
                    value: '${summary.onlineCount}',
                    label: 'faol qurilma',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    icon: Icons.schedule,
                    value: AppDateUtils.formatDuration(summary.todayScreenTimeMs),
                    label: 'bugun',
                    color: Colors.teal,
                    compactValue: true,
                  ),
                ),
              ],
            ),
            if (summary.lowBatteryCount > 0 || summary.blockedAppsCount > 0) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (summary.lowBatteryCount > 0)
                    _MiniChip(
                      icon: Icons.battery_alert,
                      text: '${summary.lowBatteryCount} ta batareya past',
                      color: Colors.orange,
                    ),
                  if (summary.blockedAppsCount > 0)
                    _MiniChip(
                      icon: Icons.block,
                      text: '${summary.blockedAppsCount} ta ilova bloklangan',
                      color: Colors.purple,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool compactValue;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.compactValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: compactValue ? 14 : 22,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MiniChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

/// Bitta farzand va uning qurilmalari.
class _ChildCard extends StatelessWidget {
  final ChildSummary child;

  const _ChildCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.childName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${child.devicesCount} ta qurilma · '
                        '${child.onlineCount} ta faol · '
                        'bugun ${AppDateUtils.formatDuration(child.todayScreenTimeMs)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < child.devices.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _DeviceRow(device: child.devices[i]),
          ],
        ],
      ),
    );
  }
}

/// Paneldagi bitta qurilma qatori.
class _DeviceRow extends StatelessWidget {
  final DeviceSummary device;

  const _DeviceRow({required this.device});

  @override
  Widget build(BuildContext context) {
    final batteryColor = device.batteryLevel == null
        ? Colors.grey
        : device.batteryLevel! > 50
            ? Colors.green
            : device.batteryLevel! > 20
                ? Colors.orange
                : Colors.red;

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeviceDetailScreen(device: device.toChildDevice()),
          ),
        );
      },
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.smartphone,
            color: device.isActive ? Colors.green : Colors.grey,
          ),
          if (device.hasActiveSos)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.priority_high,
                    size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              device.deviceName.isEmpty ? 'Nomsiz qurilma' : device.deviceName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: device.isActive ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${AppDateUtils.timeAgo(device.lastSeen)} · '
            'bugun ${AppDateUtils.formatDuration(device.todayScreenTimeMs)}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (device.batteryLevel != null)
                _TinyChip(
                  icon: Icons.battery_std,
                  text: '${device.batteryLevel!.round()}%',
                  color: batteryColor,
                ),
              if (device.blockedAppsCount > 0)
                _TinyChip(
                  icon: Icons.block,
                  text: '${device.blockedAppsCount}',
                  color: Colors.purple,
                ),
              if (device.activeLimitsCount > 0)
                _TinyChip(
                  icon: Icons.timer,
                  text: '${device.activeLimitsCount}',
                  color: Colors.teal,
                ),
              if (device.zonesCount > 0)
                _TinyChip(
                  icon: Icons.shield,
                  text: '${device.zonesCount}',
                  color: Colors.indigo,
                ),
            ],
          ),
          if (device.lastEventMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              device.lastEventMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: device.lastEventType == DeviceEvent.typeAdminDisabled
                    ? Colors.red
                    : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      isThreeLine: true,
    );
  }
}

class _TinyChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _TinyChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

/// Panel oxiridagi oxirgi hodisalar — barcha qurilmalar bo'yicha.
class _RecentEventsCard extends StatelessWidget {
  final List<DeviceEvent> events;

  const _RecentEventsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < events.length && i < 8; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              dense: true,
              leading: Icon(
                iconForEventType(events[i].eventType),
                color: colorForEvent(events[i]),
                size: 20,
              ),
              title: Text(
                events[i].message,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                AppDateUtils.timeAgo(events[i].createdAt),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
