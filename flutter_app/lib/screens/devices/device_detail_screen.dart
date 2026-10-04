import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../models/child_device.dart';
import '../../providers/device_provider.dart';
import '../monitoring/apps_screen.dart';
import '../monitoring/contacts_screen.dart';
import '../monitoring/events_screen.dart';
import '../monitoring/location_screen.dart';
import '../monitoring/notifications_screen.dart';
import '../monitoring/sos_screen.dart';
import '../monitoring/time_limits_screen.dart';
import '../monitoring/usage_screen.dart';
import '../monitoring/zones_screen.dart';
import 'edit_device_screen.dart';

/// Bitta qurilma tafsilotlari — ota-onaning asosiy ish maydoni.
class DeviceDetailScreen extends StatelessWidget {
  final ChildDevice device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsName = device.childName.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(device.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Nom berish',
            onPressed: () => _openEdit(context),
          ),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: device.isActive
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.smartphone,
                        size: 44,
                        color: device.isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Farzand nomi boshqa sarlavhada, qurilma nomi pastda —
                    // aks holda "Alisher" va "Alisher telefoni" chalkashadi.
                    Text(
                      needsName ? 'Nomsiz farzand' : device.childName,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (device.deviceName.isNotEmpty)
                      Text(
                        device.deviceName,
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
                    // Farzand nomi berilmagan bo'lsa, panelda qurilma
                    // alohida turadi va ota-ona uni tani olmaydi. Shu sababdan
                    // bu yerda har doim taklif qilamiz.
                    if (needsName) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openEdit(context),
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Farzand nomini bering'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
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
                    value: device.id.substring(0, 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Kuzatish',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: [
                _ActionCard(
                  icon: Icons.location_on,
                  label: 'Joylashuv',
                  color: Colors.orange,
                  onTap: () => _push(context, LocationScreen(device: device)),
                ),
                _ActionCard(
                  icon: Icons.apps,
                  label: 'Ilovalar',
                  color: Colors.purple,
                  onTap: () => _push(context, AppsScreen(device: device)),
                ),
                _ActionCard(
                  icon: Icons.bar_chart,
                  label: 'Foydalanish',
                  color: Colors.teal,
                  onTap: () => _push(context, UsageScreen(device: device)),
                ),
                _ActionCard(
                  icon: Icons.shield,
                  label: 'Xavfsizlik zonalari',
                  color: Colors.indigo,
                  onTap: () => _push(context, ZonesScreen(device: device)),
                ),
                _ActionCard(
                  icon: Icons.timer,
                  label: 'Vaqt limitlari',
                  color: Colors.deepOrange,
                  onTap: () => _push(context, TimeLimitsScreen(device: device)),
                ),
                _ActionCard(
                  icon: Icons.contacts,
                  label: 'Kontaktlar',
                  color: Colors.cyan,
                  onTap: () => _push(context, ContactsScreen(device: device)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Xavfsizlik',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: [
                // Bu kartaning navigatsiyasi avval `AppsScreen` ga borardi
                // (kodda "Bunga vaqtincha..." izohi bilan) — ya'ni ota-ona
                // SOS signalni ko'rmoqchi bo'lib, ilovalar ro'yxatini
                // ko'zga olardi. Endi o'z ekraniga boradi.
                _ActionCard(
                  icon: Icons.sos,
                  label: 'SOS signallari',
                  color: Colors.red,
                  onTap: () => _push(context, SosScreen(device: device)),
                ),
                _ActionCard(
                  icon: Icons.history,
                  label: 'Hodisa tarixi',
                  color: Colors.brown,
                  onTap: () => _push(context, EventsScreen(device: device)),
                ),
                _ActionCard(
                  icon: Icons.notifications_off,
                  label: 'Bildirishnomalar',
                  color: Colors.grey,
                  onTap: () =>
                      _push(context, NotificationsScreen(device: device)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openEdit(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditDeviceScreen(device: device),
      ),
    );

    if (changed == true && context.mounted) {
      // Qurilma nomi o'zgarganda panel va ro'yxat ham yangilanishi kerak —
      // aks holda eski nom boshqa ekranlarda ko'rinib turadi.
      await context.read<DeviceProvider>().loadDevices();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Qurilmani o\'chirish'),
        content: Text('${device.displayName} qurilmasini o\'chirishni '
            'tasdiqlaysizmi?\n\n'
            'Bolaning o\'lchovlari, ilovalari va tarixi ham '
            'o\'chadi. Qaytarib bo\'lmaydi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success =
          await context.read<DeviceProvider>().deleteDevice(device.id);
      if (!context.mounted) return;

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
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
