import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../models/child_device.dart';
import '../../providers/device_provider.dart';
import 'device_detail_screen.dart';
import '../monitoring/apps_screen.dart';
import '../monitoring/contacts_screen.dart';
import '../monitoring/events_screen.dart';
import '../monitoring/location_screen.dart';
import '../monitoring/notifications_screen.dart';
import '../monitoring/sos_screen.dart';
import '../monitoring/time_limits_screen.dart';
import '../monitoring/usage_screen.dart';
import '../monitoring/zones_screen.dart';

/// Qurilma tanlash ekrani — keyin tegishli bo'limga o'tadi.
///
/// Bu ekran har bir bo'lim uchun "qaysi farzand?" savolini beradi. Ota-ona
/// ko'p farzandli bo'lsa, bu qadam zarur: bir xil bo'lim bir nechta farzand
/// uchun turli ma'lumot ko'rsatadi.
class DeviceListScreen extends StatefulWidget {
  final String? openMonitoring;

  const DeviceListScreen({super.key, this.openMonitoring});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  /// `openMonitoring` qiymati -> ekran sarlavhasi.
  ///
  /// Eski versiya `switch` da faqat `location`/`apps`/`usage` ni
  /// ko'rib chiqar edi. `notifications`, `zones`, `limits`, `sos`, `events`,
  /// `contacts` kabi yangilar `default` ga tushib, foydalanuvchining
  /// kutilgan ekrani o'rniga **qurilma tafsilotlarini** ochardi — asosiy
  /// menyudagi 6 ta kartadan biri (`Bildirishnomalar`) butunlay ishlamardi.
  static const Map<String, String> _titles = {
    'location': 'Joylashuv',
    'apps': 'Ilovalar',
    'usage': 'Foydalanish',
    'zones': 'Xavfsizlik zonalari',
    'limits': 'Vaqt limitlari',
    'sos': 'SOS signallari',
    'events': 'Hodisa tarixi',
    'contacts': 'Kontaktlar',
    'notifications': 'Bildirishnomalar',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadDevices();
    });
  }

  void _navigateToMonitoring(BuildContext context, ChildDevice device) {
    // Har bir `case` o'z ekranini ochishi SHART. `default` ga tushib
    // ketishi — xato: foydalanuvchi boshqa bo'limni kutayotgan edi.
    switch (widget.openMonitoring) {
      case 'location':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LocationScreen(device: device)),
        );
        break;
      case 'apps':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AppsScreen(device: device)),
        );
        break;
      case 'usage':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UsageScreen(device: device)),
        );
        break;
      case 'zones':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ZonesScreen(device: device)),
        );
        break;
      case 'limits':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TimeLimitsScreen(device: device)),
        );
        break;
      case 'sos':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SosScreen(device: device)),
        );
        break;
      case 'events':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventsScreen(device: device)),
        );
        break;
      case 'contacts':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContactsScreen(device: device)),
        );
        break;
      case 'notifications':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => NotificationsScreen(device: device)),
        );
        break;
      default:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DeviceDetailScreen(device: device)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();

    final sectionTitle = _titles[widget.openMonitoring];
    final title = sectionTitle == null
        ? 'Qurilmalar'
        : '$sectionTitle — qurilmani tanlang';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yangilash',
            onPressed: () => context.read<DeviceProvider>().loadDevices(),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.devices.isEmpty
              ? _EmptyDevices(isPairingStep: sectionTitle != null)
              : RefreshIndicator(
                  onRefresh: () => context.read<DeviceProvider>().loadDevices(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (provider.devices.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${provider.devices.length} ta qurilma ulangan — '
                            'kerakli farzandni tanlang',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      for (final device in provider.devices) ...[
                        _DeviceCard(
                          device: device,
                          onTap: () => _navigateToMonitoring(context, device),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final ChildDevice device;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final batteryColor = device.batteryLevel != null
        ? (device.batteryLevel! > 50
            ? Colors.green
            : device.batteryLevel! > 20
                ? Colors.orange
                : Colors.red)
        : Colors.grey;

    // Farzand nomi bo'lmasa nom berishni taklif qilamiz — aks holda
    // ota-ona ko'p qurilmalarda "qaysi farzand?" savoliga javob topa olmaydi.
    final needsName = device.childName.trim().isEmpty;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: device.isActive
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          child: Icon(
            Icons.smartphone,
            color: device.isActive ? Colors.green : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                needsName
                    ? device.deviceName.isNotEmpty
                        ? device.deviceName
                        : device.deviceIdentifier
                    : device.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!device.isPaired)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.link_off, size: 14, color: Colors.orange),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Farzand nomi bor bo'lsa qurilma nomini mayda shriftda
            // ko'rsatamiz (bir farzandning bir nechta qurilmasi bo'lganda
            // ularni farqlash kerak).
            if (!needsName && device.deviceName.trim().isNotEmpty)
              Text(
                device.deviceName,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            if (device.lastSeen != null)
              Text(
                'Oxirgi faollik: ${AppDateUtils.timeAgo(device.lastSeen)}',
                style: const TextStyle(fontSize: 12),
              ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: device.isActive ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  device.isActive ? 'Faol' : 'Nofaol',
                  style: TextStyle(
                    fontSize: 12,
                    color: device.isActive ? Colors.green : Colors.grey,
                  ),
                ),
                if (device.batteryLevel != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.battery_std, size: 14, color: batteryColor),
                  Text(
                    '${device.batteryLevel!.round()}%',
                    style: TextStyle(fontSize: 12, color: batteryColor),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  final bool isPairingStep;

  const _EmptyDevices({this.isPairingStep = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_other, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Hech qanday qurilma topilmadi',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isPairingStep
                  ? 'Bu bo\'limni ko\'rish uchun avval boshqa bo\'limda '
                      'qurilma ulash kerak'
                  : 'Bolaning qurilmasini qo\'shish uchun\n'
                      '"Qurilma ulash" tugmasini bosing',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
