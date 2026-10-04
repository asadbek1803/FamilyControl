import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_provider.dart';
import '../../models/child_device.dart';
import '../../core/utils/date_utils.dart';
import 'device_detail_screen.dart';
import '../monitoring/location_screen.dart';
import '../monitoring/apps_screen.dart';
import '../monitoring/usage_screen.dart';

class DeviceListScreen extends StatefulWidget {
  final String? openMonitoring;

  const DeviceListScreen({super.key, this.openMonitoring});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadDevices();
    });
  }

  void _navigateToMonitoring(BuildContext context, ChildDevice device) {
    switch (widget.openMonitoring) {
      case 'location':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LocationScreen(device: device)),
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

    String title = 'Qurilmalar';
    if (widget.openMonitoring == 'location') title = 'Joylashuv - Qurilma tanlash';
    if (widget.openMonitoring == 'apps') title = 'Ilovalar - Qurilma tanlash';
    if (widget.openMonitoring == 'usage') title = 'Foydalanish - Qurilma tanlash';
    if (widget.openMonitoring == 'notifications')
      title = 'Bildirishnomalar - Qurilma tanlash';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DeviceProvider>().loadDevices(),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.devices.isEmpty
              ? _EmptyDevices()
              : RefreshIndicator(
                  onRefresh: () => context.read<DeviceProvider>().loadDevices(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final device = provider.devices[index];
                      return _DeviceCard(
                        device: device,
                        onTap: () => _navigateToMonitoring(context, device),
                      );
                    },
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

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: device.isActive
              ? Colors.green.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          child: Icon(
            Icons.smartphone,
            color: device.isActive ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
          device.deviceName.isNotEmpty
              ? device.deviceName
              : device.deviceIdentifier,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_other, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Hech qanday qurilma topilmadi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Bolaning qurilmasini qo\'shish uchun\n"Qurilma ulash" tugmasini bosing',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
