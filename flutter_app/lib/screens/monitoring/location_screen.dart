import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/child_device.dart';
import '../../models/location_log.dart';
import '../../providers/device_provider.dart';
import '../../core/utils/date_utils.dart';

class LocationScreen extends StatefulWidget {
  final ChildDevice device;

  const LocationScreen({super.key, required this.device});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadLocations(widget.device.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Joylashuv - ${widget.device.deviceName.isNotEmpty ? widget.device.deviceName : "Qurilma"}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<DeviceProvider>().loadLocations(widget.device.id),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.locations.isEmpty
              ? _EmptyState()
              : Column(
                  children: [
                    // Latest location highlight
                    _LatestLocationCard(location: provider.locations.first),
                    // Location list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => context
                            .read<DeviceProvider>()
                            .loadLocations(widget.device.id),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.locations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final log = provider.locations[index];
                            return _LocationRow(
                              log: log,
                              isLatest: index == 0,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Yangi Geozona qo\'shish'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(decoration: InputDecoration(labelText: 'Hudud nomi (Masalan: Maktab)')),
                  SizedBox(height: 12),
                  TextField(decoration: InputDecoration(labelText: 'Radius (metrda)', hintText: 'Masalan: 500')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Xavfsiz hudud saqlandi! Bola bu yerdan chiqsa sizga Push xabar keladi.')),
                    );
                  },
                  child: const Text('Saqlash'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Zona qo\'shish'),
      ),
    );
  }
}

class _LatestLocationCard extends StatelessWidget {
  final LocationLog location;

  const _LatestLocationCard({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        color: Colors.orange.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Oxirgi joylashuv',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    AppDateUtils.timeAgo(location.recordedAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CoordTile(
                      label: 'Kenglik',
                      value: location.latitude.toStringAsFixed(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CoordTile(
                      label: 'Uzunlik',
                      value: location.longitude.toStringAsFixed(6),
                    ),
                  ),
                ],
              ),
              if (location.accuracy != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Aniqlik: ${location.accuracy!.round()} m',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              // Open in map button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Xaritada ochish'),
                  onPressed: () => _openInMaps(context, location),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openInMaps(BuildContext context, LocationLog log) {
    // Show coordinates dialog (Google Maps package will be used in production)
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Koordinatalar'),
        content: SelectableText(
          'Kenglik: ${log.latitude}\nUzunlik: ${log.longitude}\n\n'
          'Google Maps URL:\nhttps://maps.google.com/?q=${log.latitude},${log.longitude}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }
}

class _CoordTile extends StatelessWidget {
  final String label;
  final String value;

  const _CoordTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final LocationLog log;
  final bool isLatest;

  const _LocationRow({required this.log, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.location_pin,
        color: isLatest ? Colors.orange : Colors.grey,
        size: 20,
      ),
      title: Text(
        '${log.latitude.toStringAsFixed(5)}, ${log.longitude.toStringAsFixed(5)}',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      subtitle: Text(
        AppDateUtils.formatDateTime(log.recordedAt),
        style: const TextStyle(fontSize: 11),
      ),
      trailing: log.accuracy != null
          ? Text(
              '±${log.accuracy!.round()}m',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 60, color: Colors.grey),
          SizedBox(height: 12),
          Text('Joylashuv ma\'lumotlari topilmadi'),
        ],
      ),
    );
  }
}
