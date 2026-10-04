import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/utils/carto_tiles.dart';
import '../models/geo_zone.dart';

/// Xarita vidjetlari — Carto plitkalari + `flutter_map`.
///
/// Nima uchun `google_maps_flutter` emas: u Google Maps API key talab qiladi.
/// Key yo'q holatda xarita bo'sh kulrang kvadrat ko'rsatadi — foydalanuvchi
/// "ishlaydi" deb o'ylab, aslida hech narsani ko'rmaydi. Carto ochiq kalit
/// bilan ishlaydi va API key talab qilmaydi.
///
/// Nima uchun o'z `errorTileCallback`imiz bor: `flutter_map` standart xato
/// plitkasini (og'irlangan "shox") chizadi. Bu ilovada chalkash ko'rinadi
/// (oddiy ro'yxat ajratgichlari bilan aralashadi), shuning uchun tinch rang
/// va bir marta chiqadigan ogohlantirish ko'rsatamiz.
class MapTileLayer extends StatefulWidget {
  /// `true` — "light" uslubi (marker yorqinroq ko'rinadi).
  final bool light;

  /// Plitkalar yuklanmaganida chaqiriladi.
  ///
  /// Nima uchun bu muhim: Carto noto'g'ri yoki muddati tugagan kalitda ham
  /// xato qaytarmaydi — **bo'sh PNG** qaytaradi (biz tekshirdik: 2049 bayt,
  /// `HTTP 200`). Ya'ni xarita jimgina bo'sh ko'rinadi va foydalanuvchi
  /// "internet yo'q" deb o'ylaydi, holbuki aslida kalit muammosi.
  ///
  /// Shuning uchun bu qaytiriladi va foydalanuvchiga ochiq aytiladi.
  final VoidCallback? onTileError;

  const MapTileLayer({super.key, this.light = false, this.onTileError});

  @override
  State<MapTileLayer> createState() => _MapTileLayerState();
}

class _MapTileLayerState extends State<MapTileLayer> {
  /// Internet yo'q holatda `errorTileCallback` **har bir** plitka uchun
  /// chaqiriladi — ekranda 20-30 ta, ya'ni bitta ogohlantirish 30 marta
  /// chiqadi. Shuning uchun faqat birinchisini xabar qilamiz.
  bool _reported = false;

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: widget.light ? lightTileTemplate : voyagerTileTemplate,
      userAgentPackageName: 'com.familycontrol.family_control_app',
      errorTileCallback: (tile, error, stackTrace) {
        if (_reported) return;
        _reported = true;
        debugPrint('Xarita plitkalari yuklanmadi: $error');
        widget.onTileError?.call();
      },
    );
  }
}

/// Bolaning joylashuvi va xavfsizlik zonalari ko'rsatilgan xarita.
///
/// [location] — bolaning oxirgi joylashuvi (yo'q bo'lsa xarita markazi
/// `fallbackCenter` ga tushadi, masalan Toshkent).
class ChildMapView extends StatefulWidget {
  final LatLng? location;
  final List<GeoZone> zones;
  final LatLng fallbackCenter;
  final double height;

  const ChildMapView({
    super.key,
    this.location,
    this.zones = const [],
    this.fallbackCenter = const LatLng(41.2995, 69.2401),
    this.height = 240,
  });

  @override
  State<ChildMapView> createState() => _ChildMapViewState();
}

class _ChildMapViewState extends State<ChildMapView> {
  final MapController _controller = MapController();
  bool _didFit = false;
  bool _tilesFailed = false;

  @override
  void didUpdateWidget(ChildMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Joylashuv kelganda yoki o'zgarganda kamerani yangilaymiz. Aks holda
    // xarita "Toshkent"da qolib, haqiqiy joylashuv ekran tashqarisida
    // qoladi — foydalanuvchi "joylashuv yo'q" deb o'ylaydi.
    if (widget.location == null) return;
    if (_didFit && widget.location == oldWidget.location) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.camera.center == widget.location) return;
      _controller.move(widget.location!, 15);
      _didFit = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.location != null;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.location ?? widget.fallbackCenter,
              initialZoom: hasLocation ? 15 : 11,
              // Chegara: ota-onaning joylashuvini kuzatishda 19-dan katta
              // masshtab kerak emas (kvartal darajasidan aniqroq bo'lmaydi,
              // aks holda xarita "ko'cha darajasida" bo'lib, qo'shimcha
              // ma'no yo'qotadi).
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              MapTileLayer(
                onTileError: () {
                  if (_tilesFailed) return;
                  setState(() => _tilesFailed = true);
                },
              ),

              // Zonalar — bolaning "bo'lishi kerak" joylari. Ular zona
              // markaziga nisbatan `radius_meters` radiusda chiziladi.
              CircleLayer(
                circles: [
                  for (final zone in widget.zones)
                    CircleMarker(
                      point: LatLng(zone.latitude, zone.longitude),
                      radius: zone.radiusMeters,
                      // `useRadiusInMeter: true` — serverdagi radius
                      // **metr**. Aks holda `flutter_map` radiusni "ekran
                      // birligi" deb oladi va zona (250 m) kichkina doira
                      // bo'lib chiqadi.
                      useRadiusInMeter: true,
                      color: Colors.indigo.withValues(alpha: 0.12),
                      borderColor: Colors.indigo,
                      borderStrokeWidth: 2,
                    ),
                ],
              ),

              if (hasLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.location!,
                      width: 40,
                      height: 40,
                      child: const _ChildMarker(),
                    ),
                  ],
                ),
            ],
          ),

          // Pastda kartografiya atributi — Carto shartiga muvofiq
          // (`© OpenStreetMap contributors © CARTO`). Uni olib tashlash
          // Carto shartnomasi buzilishiga olib keladi.
          Positioned(
            right: 4,
            bottom: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  cartoAttribution,
                  style: TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ),
            ),
          ),

          if (_tilesFailed)
            const Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _MapNotice(icon: Icons.cloud_off, text: cartoOfflineHint),
            )
          else if (!hasLocation)
            const Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _MapNotice(
                icon: Icons.location_off,
                text: 'Bolaning joylashuvi hali kelmagan — xarita Toshkentda.',
              ),
            ),
        ],
      ),
    );
  }
}

/// Bolaning joylashuv markerasi.
class _ChildMarker extends StatelessWidget {
  const _ChildMarker();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.orange,
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Xarita ustidagi ogohlantirish.
class _MapNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MapNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.orange[800]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

/// Xarita orqali nuqtani tanlash — zona markazini belgilash uchun.
///
/// Ota-ona xaritada barmog'i bilan bosing. Bu koordinatani qo'lda yozishdan
/// ancha qulay va eng muhimi — **xato imkoniyati kamayadi**: noto'g'ri
/// koordinata yozilsa, zona bolaning haqiqiy joyida bo'lmaydi va hamma
/// tekshiruvlar ishlamaydi.
///
/// Qo'lda kiritish ham saqlanadi (`zones_screen.dart`) — internet yo'q
/// holatda yoki aniq koordinata kerak bo'lganda.
class ZoneCenterPicker extends StatefulWidget {
  final LatLng? initialCenter;
  final double initialZoom;
  final ValueChanged<LatLng> onPick;

  const ZoneCenterPicker({
    super.key,
    this.initialCenter,
    this.initialZoom = 15,
    required this.onPick,
  });

  @override
  State<ZoneCenterPicker> createState() => _ZoneCenterPickerState();
}

class _ZoneCenterPickerState extends State<ZoneCenterPicker> {
  LatLng? _picked;
  bool _tilesFailed = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 260,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: _picked ?? const LatLng(41.2995, 69.2401),
                  initialZoom: _picked != null ? widget.initialZoom : 11,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, point) {
                    setState(() => _picked = point);
                    widget.onPick(point);
                  },
                ),
                children: [
                  // "Light" uslub: marker yorqin rangda, kartografiya bilan
                  // to'qnashmaydi.
                  MapTileLayer(
                    light: true,
                    onTileError: () {
                      if (_tilesFailed) return;
                      setState(() => _tilesFailed = true);
                    },
                  ),

                  if (_picked != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _picked!,
                          width: 44,
                          height: 44,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.indigo.withValues(alpha: 0.25),
                            ),
                            child: const Center(
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: Colors.indigo,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Xarita bo'sh qolsa, ota-ona "barmoqim tegmadi" deb
              // o'ylab, tasodifiy nuqtani markaz qilib oladi. Ya'ni internet
              // yo'q holatda aynan eng xavfli xato — noto'g'ri markaz —
              // yuzaga keladi. Shuning uchun ogohlantirish majburiy.
              if (_tilesFailed)
                const Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _MapNotice(
                    icon: Icons.cloud_off,
                    text: cartoOfflineHint,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(
                _picked == null ? Icons.touch_app : Icons.check_circle,
                size: 16,
                color: _picked == null ? Colors.grey : Colors.green,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  // Xarita ishlamay turib tanlangan nuqtaga ishonish mumkin
                  // emas — barmoq qayeraga tushganini ko'rib bo'lmaydi.
                  // Qo'lda kiritishga yo'naltiramiz.
                  _tilesFailed
                      ? 'Xarita yuklanmadi — quyidagi "Ko\'lda kiritish" '
                            'maydonidan koordinata yozing'
                      : _picked == null
                      ? 'Xaritada bosing — zona markazi shu nuqtaga qo\'yiladi'
                      : '${_picked!.latitude.toStringAsFixed(5)}, '
                            '${_picked!.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _picked == null || _tilesFailed
                        ? Colors.grey
                        : Colors.green[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
