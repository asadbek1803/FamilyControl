import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/event_presentation.dart';
import '../../models/child_device.dart';
import '../../models/device_event.dart';
import '../../providers/device_provider.dart';

/// Qurilma hodisalari tarixi — ota-ona uchun.
///
/// Nima uchun bu muhim: ilovada "Hodisa" bo'limi yo'q edi. Ota-onaga
/// Telegram orqali xabar borib kelar edi, lekin ilova ichida "nima bo'ldi?"
/// degan savolga javob topib bo'lmasdi.
///
/// Chegara: bu FAQAT ilova va qurilma holati hodisalari (ulandi, bloklandi,
/// SOS, batareya, himoya o'chirildi, zonadan chiqdi). Boshqa ilovalarning
/// xabarlari yoki chat yozishmalari bu ro'yxatga TUSHMAYDI.
class EventsScreen extends StatefulWidget {
  final ChildDevice device;

  const EventsScreen({super.key, required this.device});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String? _eventTypeFilter;
  int? _daysFilter;

  /// Filtr chip'lari. `null` — filtrsiz (barchasi).
  static const List<(String?, String)> _typeFilters = [
    (null, 'Barchasi'),
    (DeviceEvent.typeSos, 'SOS'),
    (DeviceEvent.typeBatteryLow, 'Batareya'),
    (DeviceEvent.typeAdminDisabled, 'Himoya o\'chirilgan'),
    (DeviceEvent.typeAppBlocked, 'Bloklangan'),
    (DeviceEvent.typeAppUnblocked, 'Ochilgan'),
    (DeviceEvent.typeZoneExit, 'Zona'),
    (DeviceEvent.typePaired, 'Ulangan'),
  ];

  static const List<(int?, String)> _rangeFilters = [
    (null, 'Barcha vaqt'),
    (1, 'Bugun'),
    (7, '7 kun'),
    (30, '30 kun'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    return context.read<DeviceProvider>().loadEvents(
          widget.device.id,
          eventType: _eventTypeFilter,
          days: _daysFilter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hodisalar - ${widget.device.displayName}'),
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
          _FilterBar(
            typeFilters: _typeFilters,
            rangeFilters: _rangeFilters,
            selectedType: _eventTypeFilter,
            selectedDays: _daysFilter,
            onTypeChanged: (value) {
              setState(() => _eventTypeFilter = value);
              _load();
            },
            onDaysChanged: (value) {
              setState(() => _daysFilter = value);
              _load();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildBody(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(DeviceProvider provider) {
    if (provider.isLoading && provider.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final events = provider.events;

    if (events.isEmpty) {
      // Filtr tanlangan bo'lsa "tarix yo'q" emas, "bu filtrga mos hodisa
      // yo'q" deyish to'g'ri — aks holda ota-ona filtrni noto'g'ri
      // tanlaganini o'ylaydi.
      final filtered = _eventTypeFilter != null || _daysFilter != null;
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Icon(
              filtered ? Icons.filter_alt_off : Icons.history,
              size: 72,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? 'Bu filtrga mos hodisa yo\'q' : 'Hali hodisa yo\'q',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? 'Boshqa filtrni tanlab ko\'ring'
                  : 'Qurilmada o\'zgarishlar bo\'lganda shu yerda ko\'rinadi:\n'
                      'ulash, bloklash, SOS, batareya, himoya holati.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (filtered) ...[
              const SizedBox(height: 20),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _eventTypeFilter = null;
                      _daysFilter = null;
                    });
                    _load();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Filtrni tozalash'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: events.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) => _EventTile(event: events[index]),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<(String?, String)> typeFilters;
  final List<(int?, String)> rangeFilters;
  final String? selectedType;
  final int? selectedDays;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<int?> onDaysChanged;

  const _FilterBar({
    required this.typeFilters,
    required this.rangeFilters,
    required this.selectedType,
    required this.selectedDays,
    required this.onTypeChanged,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: typeFilters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final (value, label) = typeFilters[index];
              return ChoiceChip(
                label: Text(label),
                selected: selectedType == value,
                onSelected: (_) => onTypeChanged(value),
              );
            },
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            itemCount: rangeFilters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final (value, label) = rangeFilters[index];
              return FilterChip(
                label: Text(label),
                selected: selectedDays == value,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onDaysChanged(value),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final DeviceEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = colorForEvent(event);
    final typeLabel = labelForEventType(event.eventType);

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(iconForEventType(event.eventType), color: color, size: 20),
      ),
      title: Text(
        event.message,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${typeLabel ?? event.eventType} · ${AppDateUtils.formatDateTime(event.createdAt)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (event.data.isNotEmpty) _EventData(data: event.data),
        ],
      ),
      isThreeLine: event.data.isNotEmpty,
    );
  }
}

/// Hodisa qo'shimcha ma'lumotlari (masalan `{"percent": 12}`).
///
/// Har bir kalit alohida qatorda ko'rsatiladi — server JSON'ni string
/// sifatida yuborsa, foydalanuvchi `{percent: 12}` o'rniga `{"percent": 12}`
/// ko'radi (xom JSON ko'rinishi chalkash).
class _EventData extends StatelessWidget {
  final Map<String, dynamic> data;

  const _EventData({required this.data});

  static const Map<String, String> _labels = {
    'percent': 'Batareya',
    'package_name': 'Ilova',
    'app_name': 'Ilova',
    'zone_name': 'Zona',
    'latitude': 'Kenglik',
    'longitude': 'Uzunlik',
    'battery_level': 'Batareya',
    'device_name': 'Qurilma',
  };

  @override
  Widget build(BuildContext context) {
    // Juda ko'p kalit bo'lsa (bug'ga o'xshash hodisa) ko'rsatmay qo'yamiz —
    // aks holda ro'yxatni buzadi.
    if (data.length > 5) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final entry in data.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_labels[entry.key] ?? entry.key}: ${_formatValue(entry.value)}',
                // `Colors.grey[800]` const emas (`MaterialColor` indeksi
                // `shade800` getter'ini chaqiradi), shuning uchun `const`
                // bilan ishlatib bo'lmaydi.
                style: const TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ),
        ],
      ),
    );
  }

  /// `double` qiymatni `12.0` emas, `12` ko'rinishida chiqaradi.
  static String _formatValue(Object? value) {
    if (value is num) {
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.toStringAsFixed(2);
    }
    return value?.toString() ?? '-';
  }
}
