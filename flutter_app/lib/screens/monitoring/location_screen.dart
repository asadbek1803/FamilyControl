import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/child_device.dart';
import '../../models/location_log.dart';
import '../../providers/device_provider.dart';
import '../../core/utils/date_utils.dart';
import '../../widgets/child_map.dart';
import 'zones_screen.dart';

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
      // Zonalar ham xaritada chizilishi uchun kerak.
      context.read<DeviceProvider>().loadZones(widget.device.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final locations = provider.locations;

    return Scaffold(
      appBar: AppBar(
        title: Text('Joylashuv - ${widget.device.displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<DeviceProvider>().loadLocations(widget.device.id),
          ),
        ],
      ),
      body: provider.isLoading && locations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : locations.isEmpty
              ? _EmptyState(device: widget.device)
              : Column(
                  children: [
                    // Joylashuv xaritasi + zonalar.
                    ChildMapView(
                      location: LatLng(
                        locations.first.latitude,
                        locations.first.longitude,
                      ),
                      zones: provider.zones,
                    ),
                    _LatestLocationCard(location: locations.first),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => context
                            .read<DeviceProvider>()
                            .loadLocations(widget.device.id),
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: locations.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) => _LocationRow(
                            log: locations[index],
                            isLatest: index == 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        // Eski versiya shu tugmada dialog ochib, uni yopib, "Xavfsiz hudud
        // saqlandi!" deb xabar ko'rsatardi — lekin **hech narsa saqlamagan
        // edi**. Ya'ni ota-ona muvaffaqiyat xabarini olib, keyin "mening
        // zonalarim qayerda?" degan savolga javob topa olmasdi.
        //
        // Endi haqiqiy `ZonesScreen` ga o'tadi — u serverdan yuklaydi va
        // xaritada markaz tanlashga imkon beradi.
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ZonesScreen(device: widget.device),
          ),
        ),
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
              // "Tashqi xaritada ochish" — ota-onaning telefonida Google/
              // Yandex xaritasi yuklangan bo'lishi mumkin. Bu ilova ichidagi
              // xaritadan farqli vazifa: "menda qaysi xarita ilovasi bor?"
              // savoliga javob beradi (Telegram/Google orqali ulashish uchun).
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Boshqa xaritada'),
                      onPressed: () => _openInMaps(context, location),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Koordinata'),
                      onPressed: () => _copyCoordinates(context, location),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Koordinatani boshqa xarita ilovasida ochish uchun havolani nusxalash.
  ///
  /// `url_launcher`/`share_plus` paketlari ilovada yo'q va ular bir funksiya
  /// uchun APK hajmiga yana bir necha MB qo'shardi. Nusxalash yetarli:
  /// foydalanuvchi Telegram yoki boshqa xarita ilovasiga o'zi yuboradi.
  void _openInMaps(BuildContext context, LocationLog log) {
    final lat = log.latitude;
    final lng = log.longitude;
    final url = 'https://maps.google.com/?q=$lat,$lng';

    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Xarita havolasi nusxalandi: $url'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _copyCoordinates(BuildContext context, LocationLog log) {
    Clipboard.setData(
      ClipboardData(text: '${log.latitude}, ${log.longitude}'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Koordinata nusxalandi')),
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
  final ChildDevice device;

  const _EmptyState({required this.device});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Joylashuv hali kelmagan',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bolaning qurilmasida joylashuv ruxsati berilmagan '
              'yoki ilova yopiq bo\'lib qolgan.\n\n'
              'Bolaning ilovasini ochish kerak — u har bir soatda '
              'joylashuvni yuboradi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            // Xarita bo'sh bo'lsa ham ko'rsatamiz: ota-ona zonalarni
            // ko'rishi va xaritada markaz tanlashi mumkin. Shu sababdan
            // "Zona qo'shish" ishi joylashuvga bog'liq emas.
            FilledButton.tonalIcon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ZonesScreen(device: device),
                ),
              ),
              icon: const Icon(Icons.shield),
              label: const Text('Xavfsizlik zonalari'),
            ),
          ],
        ),
      ),
    );
  }
}
