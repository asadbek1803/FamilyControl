import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/child_device.dart';
import '../../providers/device_provider.dart';
import '../../core/utils/date_utils.dart';
import '../monitoring/location_screen.dart';
import '../monitoring/apps_screen.dart';
import '../monitoring/usage_screen.dart';
import '../monitoring/contacts_screen.dart';

class DeviceDetailScreen extends StatelessWidget {
  final ChildDevice device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(device.deviceName.isNotEmpty
            ? device.deviceName
            : device.deviceIdentifier),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Qurilmani o\'chirish',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: device.isActive
                          ? Colors.green.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      child: Icon(
                        Icons.smartphone,
                        size: 44,
                        color: device.isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      device.deviceName.isNotEmpty
                          ? device.deviceName
                          : 'Nomsiz qurilma',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.deviceIdentifier,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StatusChip(
                          label: device.isActive ? 'Faol' : 'Nofaol',
                          color: device.isActive ? Colors.green : Colors.grey,
                        ),
                        if (device.batteryLevel != null) ...[
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: '🔋 ${device.batteryLevel!.round()}%',
                            color: device.batteryLevel! > 20
                                ? Colors.green
                                : Colors.red,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Info details
            Card(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Oxirgi faollik',
                    value: AppDateUtils.timeAgo(device.lastSeen),
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Qo\'shilgan sana',
                    value: AppDateUtils.formatDateTime(device.createdAt),
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.fingerprint,
                    label: 'Qurilma ID',
                    value: device.id.substring(0, 8) + '...',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Monitoring',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Monitoring actions
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _ActionCard(
                  icon: Icons.location_on,
                  label: 'Joylashuv',
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LocationScreen(device: device)),
                  ),
                ),
                _ActionCard(
                  icon: Icons.apps,
                  label: 'Ilovalar',
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AppsScreen(device: device)),
                  ),
                ),
                _ActionCard(
                  icon: Icons.bar_chart,
                  label: 'Foydalanish',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => UsageScreen(device: device)),
                  ),
                ),
                _ActionCard(
                  icon: Icons.contacts,
                  label: 'Kontaktlar',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ContactsScreen(device: device)),
                  ),
                ),
                _ActionCard(
                  icon: Icons.notifications,
                  label: 'Bildirishnoma & SOS',
                  color: Colors.red,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AppsScreen(device: device)), // Bunga vaqtincha AppsScreen, keyin SOS alert qilinadi
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Qurilmani o\'chirish'),
        content: Text(
            '${device.deviceName.isNotEmpty ? device.deviceName : device.deviceIdentifier} qurilmasini o\'chirishni tasdiqlaysizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success =
          await context.read<DeviceProvider>().deleteDevice(device.id);
      if (context.mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Qurilma o\'chirildi')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Qurilmani o\'chirib bo\'lmadi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
