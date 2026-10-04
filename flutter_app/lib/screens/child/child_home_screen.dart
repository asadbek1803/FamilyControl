import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../repositories/device_repository.dart';
import '../../repositories/notification_repository.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  String? _pairingCode;
  DateTime? _expiresAt;
  bool _isRefreshing = false;
  bool _isLoading = true;
  bool _isPaired = false;
  Timer? _countdown;

  final _notificationRepo = NotificationRepository();

  @override
  void initState() {
    super.initState();
    _loadPairingCode();
    _checkPairing();
    // Qolgan vaqt har soniyada yangilanib turishi uchun timer.
    // `setState` faqat pairing code oynasi ko'rinib turgan paytda ishlaydi.
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _expiresAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  /// Eski kodda `_getPairingCode()` `build()` ichida chaqirilardi — har bir
  /// rebuild'da yangi `Future` yaratilib, `FutureBuilder` qayta ishlardi.
  /// Endi `initState`da bir marta yuklanadi va holatda saqlanadi.
  Future<void> _loadPairingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('pairing_code');
    final expires = prefs.getString('pairing_code_expires_at');

    if (!mounted) return;
    setState(() {
      _pairingCode = code;
      _expiresAt = expires != null ? DateTime.tryParse(expires) : null;
      _isLoading = false;
    });
  }

  /// Kod 30 daqiqada muddati tugaydi. Eskirgan bo'lsa, ota-ona hech qachon
  /// ulana olmay qoladi — shuning uchun qayta olish kerak.
  Future<void> _refreshPairingCode() async {
    setState(() => _isRefreshing = true);

    final prefs = await SharedPreferences.getInstance();
    final repo = DeviceRepository();
    final deviceId = prefs.getString('child_device_id') ?? const Uuid().v4();
    await prefs.setString('child_device_id', deviceId);

    try {
      final res = await repo.registerDevice(
        deviceIdentifier: deviceId,
        deviceName: 'Farzand Telefon',
      );
      final data = res['success'] == true ? res['data'] : null;
      final code = data is Map ? data['pairing_code'] : null;

      if (code == null) {
        _showMessage('Kodni yangilab bo\'lmadi. Internetni tekshirib, qayta urinib ko\'ring.');
        return;
      }

      final expiresRaw = data is Map ? data['expires_at'] : null;
      final expires = expiresRaw != null
          ? DateTime.tryParse(expiresRaw.toString())?.toLocal()
          : null;

      await prefs.setString('pairing_code', code.toString());
      if (expires != null) {
        await prefs.setString('pairing_code_expires_at', expires.toIso8601String());
      }

      if (!mounted) return;
      setState(() {
        _pairingCode = code.toString();
        _expiresAt = expires;
      });
    } catch (e) {
      _showMessage('Serverga ulanib bo\'lmadi. Internetni tekshirib, qayta urinib ko\'ring.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ota-onaning shu qurilmani ulaganini tekshiradi va, ulagan bo'lsa,
  /// o'z `device_token`imizni olamiz.
  ///
  /// Nima uchun kerak: pairing ota-onaning ilovasida amalga oshadi, ya'ni
  /// `device_token` ota-onaning telefonida qoladi. Farzand qurilmasi esa
  /// hodisa yuborishi (SOS, batareya, himoya o'chirilishi) uchun o'z
  /// tokeni kerak.
  Future<void> _checkPairing() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('child_device_id');
    if (deviceId == null) return;

    try {
      final paired = await _notificationRepo.claimDeviceToken(deviceId);
      if (!mounted) return;
      setState(() => _isPaired = paired);

      // Farzand rejimi faqat ota-onaning ilovasi orqali yoqiladi, shuning
      // uchun bu hodisani shu zahoti yuboramiz — ilova endi ota-onaga ulangan.
      if (paired && prefs.getBool('child_mode_reported') != true) {
        await _notificationRepo.sendEvent(
          eventType: DeviceEventTypes.childModeEnabled,
          message: '🛡️ Farzand xavfsizlik rejimi yoqildi. Sozlamalar PIN bilan '
              'bloklangan.',
        );
        await prefs.setBool('child_mode_reported', true);
      }
    } catch (_) {
      // Internet yo'q bo'lishi mumkin — keyinroq urinib ko'ramiz
    }
  }

  /// SOS: farzand hodisa yuboradi, Telegram xabari esa SERVER yuboradi
  /// (bot tokeni hech qachon ilovada saqlanmaydi).
  Future<void> _sendSos() async {
    _showMessage('SOS signali yuborilmoqda...');

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('child_device_id');

    // Ota-onaning ilovasi endi yangi kod ko'rsatishi mumkin — eskirganini
    // yangilab qo'yamiz, shunda ota-ona darhol ulana oladi.
    if (!_isPaired) {
      await _checkPairing();
      if (!_isPaired) await _refreshPairingCode();
    }

    var sent = false;
    try {
      sent = await _notificationRepo.sendEvent(
        eventType: DeviceEventTypes.sos,
        message: '🚨 SOS! Farzand yordam so' 'rab qo' 'ng yerga uzoq bosdi.',
        data: {'device_identifier': deviceId ?? ''},
      );
    } catch (_) {
      sent = false;
    }

    if (!mounted) return;
    _showMessage(
      sent
          ? 'SOS signali yuborildi! Ota-onangizga xabar ketdi.'
          : 'SOS yuborilmadi: qurilma hali ota-onaga ulanmagan yoki internet yo\'q.',
    );
  }

  String get _remainingLabel {
    if (_expiresAt == null) return '';
    final left = _expiresAt!.difference(DateTime.now());
    if (left.isNegative) return 'Kod muddati tugagan';
    final minutes = left.inMinutes;
    final seconds = left.inSeconds % 60;
    return 'Yana ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} dan keyin eskiradi';
  }

  bool get _isExpired =>
      _expiresAt != null && DateTime.now().isAfter(_expiresAt!);

  @override
  Widget build(BuildContext context) {
    final expired = _isExpired;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.blue.shade500],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Xavfsizlik rejimi faol',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Qurilma ota-ona nazorati ostida',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Ota-ona telefoniga ulash kodi:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoading)
                          const CircularProgressIndicator(color: Colors.white)
                        else
                          Text(
                            _pairingCode ?? 'Kod topilmadi',
                            style: TextStyle(
                              color: expired ? Colors.amberAccent : Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                        if (_remainingLabel.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _remainingLabel,
                            style: TextStyle(
                              color: expired ? Colors.amberAccent : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _isRefreshing ? null : _refreshPairingCode,
                          icon: _isRefreshing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh, color: Colors.white, size: 18),
                          label: const Text(
                            'Yangi kod olish',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Qurilma holati: ota-onaga ulangan yoki ulanmagan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isPaired ? Icons.cloud_done : Icons.cloud_off,
                        color: _isPaired ? Colors.greenAccent : Colors.white60,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPaired
                            ? 'Ota-onangizga ulangan'
                            : 'Ota-onangizga ulanmagan',
                        style: TextStyle(
                          color: _isPaired
                              ? Colors.greenAccent
                              : Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // SOS Tugmasi
                  GestureDetector(
                    onLongPress: _sendSos,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade600,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 10,
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: const Center(
                        child: Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Favqulodda yordam uchun uzoq bosing',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade900,
                    ),
                    onPressed: () => SystemNavigator.pop(),
                    child: const Text('Tizimdan chiqish (Uy ekrani)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
