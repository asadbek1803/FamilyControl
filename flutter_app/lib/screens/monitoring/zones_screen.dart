import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../models/child_device.dart';
import '../../models/geo_zone.dart';
import '../../models/location_log.dart';
import '../../providers/device_provider.dart';
import '../../widgets/child_map.dart';

/// Xavfsizlik zonalari — bolaning bo'lishi kerak bo'lgan joylar.
///
/// Xarita: Carto plitkalari (`flutter_map`) — API key talab qilmaydi.
/// Google Maps kaliti kerak bo'lgan edi, yo'q bo'lsa xarita bo'sh kulrang
/// kvadrat ko'rinib, foydalanuvchi "ishlamoqda" deb o'ylaydi edi.
///
/// Har bir zona xaritada doira sifatida chiziladi. Markaz xaritada
/// bormasdan tanlanadi — qo'lda koordinata yozish xato ehtimolini oshiradi.
class ZonesScreen extends StatefulWidget {
  final ChildDevice device;

  const ZonesScreen({super.key, required this.device});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadZones(widget.device.id);
      // Joylashuv zona markazi uchun kerak (dialogni tez ochganda ham
      // tayyor bo'lishi uchun). Ro'yxat oxirgi sanaga qarab saralanadi,
      // shuning uchun birinchi element — oxirgi joylashuv.
      context.read<DeviceProvider>().loadLocations(widget.device.id);
    });
  }

  Future<void> _showZoneDialog({GeoZone? zone}) async {
    final provider = context.read<DeviceProvider>();

    // Eski zonani tahrirlashda uning o'z koordinatasidan boshlanadi —
    // aks holda foydalanuvchi har bir tahrirlashda koordinatani qayta
    // kiritishi kerak bo'lardi.
    LocationLog? reference;
    if (zone == null) {
      reference = provider.locations.isNotEmpty ? provider.locations.first : null;
    }

    final result = await showDialog<_ZoneResult>(
      context: context,
      builder: (_) => _ZoneDialog(zone: zone, reference: reference),
    );

    if (result == null || !mounted) return;

    final data = <String, dynamic>{
      'name': result.name,
      'latitude': result.latitude,
      'longitude': result.longitude,
      'radius_meters': result.radiusMeters,
    };

    final ok = zone == null
        ? await provider.createZone(widget.device.id, data)
        : await provider.updateZone(widget.device.id, zone.id, data);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (zone == null ? 'Zona qo\'shildi' : 'Zona yangilandi')
            : 'Saqlanmadi. Serverga ulanib, qayta urinib ko\'ring.'),
      ),
    );
  }

  Future<void> _deleteZone(GeoZone zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zonani o\'chirish'),
        content: Text('"${zone.name}" zonasi o\'chirilsinmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await context
        .read<DeviceProvider>()
        .deleteZone(widget.device.id, zone.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Zona o\'chirildi' : 'O\'chirilmadi'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final zones = provider.zones;
    final locations = provider.locations;

    return Scaffold(
      appBar: AppBar(
        title: Text('Xavfsizlik zonalari - ${widget.device.displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yangilash',
            onPressed: () => context.read<DeviceProvider>().loadZones(
                  widget.device.id,
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showZoneDialog(),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Zona qo\'shish'),
      ),
      body: Column(
        children: [
          // Umumiy xarita: barcha zonalar + bolaning oxirgi joylashuvi.
          // Bo'sh ro'yxatda ham ko'rsatamiz — chunki zona qo'shish uchun
          // xarita kerak (dialogda markazni shu yerda tanash mumkin).
          ChildMapView(
            location: locations.isNotEmpty
                ? LatLng(
                    locations.first.latitude,
                    locations.first.longitude,
                  )
                : null,
            zones: zones,
            height: zones.isEmpty ? 180 : 240,
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody(provider, zones)),
        ],
      ),
    );
  }

  Widget _buildBody(DeviceProvider provider, List<GeoZone> zones) {
    if (provider.isLoading && zones.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (zones.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            context.read<DeviceProvider>().loadZones(widget.device.id),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          children: [
            Icon(Icons.shield_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Xavfsizlik zona qo\'shilmagan',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Zona — bolangiz doim bo\'lishi kerak bo\'lgan joy\n'
              '(maktab, uy). Chiqib ketishda Telegram orqali\n'
              'xabar beriladi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          context.read<DeviceProvider>().loadZones(widget.device.id),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: zones.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, index) {
          final zone = zones[index];
          return Dismissible(
            key: ValueKey(zone.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) async {
              await _deleteZone(zone);
              // O'chirilmagan bo'lsa, swipe'ni qaytarish kerak —
              // aks holda qator ro'yxatdan butunlay yo'qoladi, holat esa
              // serverda saqlanib qolgan bo'ladi.
              return false;
            },
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.indigo,
                child: Icon(Icons.shield, color: Colors.white),
              ),
              title: Text(zone.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    '${zone.radiusMeters.round()} m radius · '
                    '${zone.latitude.toStringAsFixed(4)}, ${zone.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    AppDateUtils.formatDate(zone.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              onTap: () => _showZoneDialog(zone: zone),
            ),
          );
        },
      ),
    );
  }
}

class _ZoneResult {
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const _ZoneResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}

class _ZoneDialog extends StatefulWidget {
  final GeoZone? zone;
  final LocationLog? reference;

  const _ZoneDialog({this.zone, this.reference});

  @override
  State<_ZoneDialog> createState() => _ZoneDialogState();
}

class _ZoneDialogState extends State<_ZoneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  // Server `latitude`/`longitude`ni 0 dan tashqarida talab qiladi:
  // (0, 0) — Osiyo chekkasidagi nuqta (Gulf of Guinea), ota-onaning xatosi.
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _radiusController;

  /// Qo'lda kiritish maydonlari yashirilgan bo'lib, faqat xarita ishlash
  /// izohi chiqarilgan holda ochiladi.
  ///
  /// Nima uchun: koordinatani qo'lda yozish xato ehtimolini juda oshiradi
  /// (belgilar tushib ketadi, o'nlik xatosi). Xaritada bosing — aniq.
  bool _showManualCoordinates = false;

  /// Xaritada bosilgan nuqta (maydonlardan kelgan qiymat bilan bir emas).
  LatLng? _picked;

  @override
  void initState() {
    super.initState();

    final zone = widget.zone;
    final reference = widget.reference;

    _nameController = TextEditingController(text: zone?.name ?? '');
    _latController = TextEditingController(
      text: zone != null
          ? zone.latitude.toStringAsFixed(5)
          // Yangi zona uchun bolaning oxirgi joylashuvi qulay boshlang'ich
          // nuqta. Yo'q bo'lsa bo'sh qoldiramiz — foydalanuvchi qo'lda
          // kiritishi kerak (server (0,0) ni rad etadi).
          : (reference?.latitude.toStringAsFixed(5) ?? ''),
    );
    _lngController = TextEditingController(
      text: zone != null
          ? zone.longitude.toStringAsFixed(5)
          : (reference?.longitude.toStringAsFixed(5) ?? ''),
    );
    _radiusController =
        TextEditingController(text: (zone?.radiusMeters ?? 200).round().toString());

    // Mavjud zonani tahrirlashda xarita o'sha markazda ochiladi.
    if (zone != null) {
      _picked = LatLng(zone.latitude, zone.longitude);
    }
  }

  /// Xaritada bosilgan nuqtani maydonlarga yozamiz.
  ///
  /// Ikkala yo'l bir xil natija berishi kerak: keyinchalik `_submit`
  /// faqat **kontrollerdan** o'qiydi. Aks holda xaritada bosilgan, lekin
  /// `_latController` bo'sh qolgan holatda "koordinata kiritilmagan" xatosi
  /// chiqardi.
  void _onMapPick(LatLng point) {
    setState(() {
      _picked = point;
      _latController.text = point.latitude.toStringAsFixed(6);
      _lngController.text = point.longitude.toStringAsFixed(6);
    });
    // Qo'lda tahrir qilingan bo'lsa, validator xatosi qolmasligi kerak
    // (aks holda ekranda "noto'g'ri format" yozib turib, xatolik yo'q).
    _formKey.currentState?.validate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  /// radius qiymatini server qoidalariga mos tekshiradi (10 m – 10 km).
  String? _validateRadius(String? value) {
    final radius = int.tryParse(value ?? '');
    if (radius == null) return 'Raqam kiriting';
    if (radius < 10) return 'Kamida 10 metr';
    if (radius > 10000) return 'Ko\'pi bilan 10 km';
    return null;
  }

  String? _validateLatitude(String? value) {
    final lat = double.tryParse(value ?? '');
    if (lat == null) return 'Raqam kiriting';
    if (lat < -90 || lat > 90) return '-90 dan 90 orasida';
    return null;
  }

  String? _validateLongitude(String? value) {
    final lng = double.tryParse(value ?? '');
    if (lng == null) return 'Raqam kiriting';
    if (lng < -180 || lng > 180) return '-180 dan 180 orasida';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.parse(_latController.text);
    final lng = double.parse(_lngController.text);

    // Server ham buni tekshiradi, lekin foydalanuvchiga darhol aytish
    // yaxshiroq (uzoq kutib, keyin umumiy "xato" olishdan).
    if (lat == 0 && lng == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Zona markazi (0, 0) bo\'lmaydi — bu Osiyo chekkasi. '
            'To\'g\'ri koordinata kiriting.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _ZoneResult(
        name: _nameController.text.trim(),
        latitude: lat,
        longitude: lng,
        radiusMeters: double.parse(_radiusController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.zone != null;
    final hasReference = widget.reference != null;

    return AlertDialog(
      title: Text(isEditing ? 'Zonani tahrirlash' : 'Yangi zona'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Zona nomi',
                    hintText: 'Maktab, Uy...',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Nom kiriting' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _radiusController,
                  decoration: const InputDecoration(
                    labelText: 'Radius (metr)',
                    helperText: '10 m dan 10 km gacha',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateRadius,
                ),
                const SizedBox(height: 16),

                // ------------------------------------------------------------------
                // XARITA
                //
                // Nima uchun: koordinatani qo'lda yozish xato ehtimolini
                // juda oshiradi (12.34567 -> 1.234567, belgi tushib ketadi).
                // Noto'g'ri markazli zona bolaning haqiqiy joyida bo'lmaydi
                // va hamma "zonadan chiqdi" tekshiruvlari ishlamaydi.
                // ------------------------------------------------------------------
                Text(
                  'Zona markazini xaritada tanlang',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ZoneCenterPicker(
                  initialCenter: _picked,
                  onPick: _onMapPick,
                ),
                const SizedBox(height: 4),

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                      () => _showManualCoordinates = !_showManualCoordinates,
                    ),
                    icon: Icon(
                      _showManualCoordinates
                          ? Icons.expand_less
                          : Icons.keyboard_alt_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _showManualCoordinates
                          ? 'Qo\'lda kiritishni yashirish'
                          : 'Koordinatani qo\'lda kiritish',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),

                if (_showManualCoordinates) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          decoration: const InputDecoration(
                            labelText: 'Kenglik',
                            hintText: '41.31108',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          validator: _validateLatitude,
                          // Qo'lda tahrir qilinganda xarita markeri ham
                          // yangilansin — aks holda ikki xil koordinata
                          // ko'rinib, qaysi saqlanadiganini bilib bo'lmaydi.
                          onChanged: (_) => setState(() => _picked = _readPoint()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          decoration: const InputDecoration(
                            labelText: 'Uzunlik',
                            hintText: '69.24056',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          validator: _validateLongitude,
                          onChanged: (_) => setState(() => _picked = _readPoint()),
                        ),
                      ),
                    ],
                  ),
                ],

                if (!isEditing && !hasReference) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Bolaning oxirgi joylashuvi hali kelmagan. '
                    'Xaritada to\'g\'ri joyni tanlang.',
                    style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Saqlash' : 'Qo\'shish'),
        ),
      ],
    );
  }

  /// Kontrollerdagi qiymatni o'qib, `LatLng` ga aylantiradi.
  ///
  /// Raqam emas bo'lsa `null` qaytaradi — xarita o'sha holatda eski
  /// markerni ko'rsatadi (bu yaxshi: foydalanuvchi noto'g'ri qiymatni
  /// ko'rib, nima uchun xato ekanini tushunadi).
  LatLng? _readPoint() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return LatLng(lat, lng);
  }
}
