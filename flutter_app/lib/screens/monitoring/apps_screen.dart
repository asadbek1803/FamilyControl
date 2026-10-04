import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/child_device.dart';
import '../../models/installed_app.dart';
import '../../providers/device_provider.dart';
import '../../providers/connectivity_provider.dart';

class AppsScreen extends StatefulWidget {
  final ChildDevice device;

  const AppsScreen({super.key, required this.device});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  String _searchQuery = '';
  bool _showBlockedOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadApps(widget.device.id);
    });
  }

  List<InstalledApp> _filtered(List<InstalledApp> apps) {
    return apps.where((app) {
      final matchQuery = _searchQuery.isEmpty ||
          app.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchBlocked = !_showBlockedOnly || app.isBlocked;
      return matchQuery && matchBlocked;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final conn = context.watch<ConnectivityProvider>();
    final filtered = _filtered(provider.apps);

    final blockedCount = provider.apps.where((a) => a.isBlocked).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ilovalar - ${widget.device.deviceName.isNotEmpty ? widget.device.deviceName : "Qurilma"}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<DeviceProvider>().loadApps(widget.device.id),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline indicator
          if (!conn.isOnline)
            Container(
              color: Colors.orange.withOpacity(0.15),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Offline rejim. O\'zgarishlar internet kelganda saqlanadi.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ),
          // Stats bar
          if (provider.apps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StatChip(
                    label: 'Jami: ${provider.apps.length}',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Bloklangan: $blockedCount',
                    color: Colors.red,
                  ),
                  const Spacer(),
                  FilterChip(
                    label: const Text('Faqat bloklangan'),
                    selected: _showBlockedOnly,
                    onSelected: (v) => setState(() => _showBlockedOnly = v),
                  ),
                ],
              ),
            ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Ilova qidirish...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('Ilovalar topilmadi'))
                    : RefreshIndicator(
                        onRefresh: () => context
                            .read<DeviceProvider>()
                            .loadApps(widget.device.id),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final app = filtered[index];
                            return _AppTile(
                              app: app,
                              deviceId: widget.device.id,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final InstalledApp app;
  final String deviceId;

  const _AppTile({required this.app, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: app.isBlocked
                ? Colors.red.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.android,
            color: app.isBlocked ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(
          app.appName.isNotEmpty ? app.appName : app.packageName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: app.isBlocked ? Colors.red : null,
          ),
        ),
        subtitle: Text(
          app.packageName,
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.timer, color: Colors.orange),
              tooltip: 'Vaqt limiti',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('${app.appName} uchun Limit'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Kunlik limitni belgilang (daqiqa):'),
                        const SizedBox(height: 8),
                        const TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(hintText: 'Masalan: 60'),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('22:00 dan keyin bloklash (Uyqu vaqti)'),
                          value: true,
                          onChanged: (v) {},
                        )
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor')),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ilova uchun limit saqlandi!')),
                          );
                        },
                        child: const Text('Saqlash'),
                      ),
                    ],
                  ),
                );
              },
            ),
            Switch(
              value: app.isBlocked,
              activeColor: Colors.red,
              onChanged: (value) async {
                final provider = context.read<DeviceProvider>();
                await provider.toggleAppBlock(deviceId, app);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
