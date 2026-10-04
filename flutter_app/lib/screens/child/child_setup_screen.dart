import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../repositories/device_repository.dart';
import 'child_home_screen.dart';

class ChildSetupScreen extends StatefulWidget {
  const ChildSetupScreen({super.key});

  @override
  State<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends State<ChildSetupScreen> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();
  bool _setupComplete = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _savePinAndContinue() async {
    final pin = _pinController.text;
    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN kod 6 ta raqamdan iborat bo\'lishi kerak')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    // ---- 1. Qurilmani ro'yxatdan o'tkazish va pairing code olish ----
    // Internet bo'lmasa kod olinmaydi -> ota-ona hech qachon ulana olmaydi,
    // shuning uchun bu bosqichni muvaffaqiyatsiz o'tkazib bo'lmaydi.
    String pairingCode;
    String? expiresAt;
    try {
      final repo = DeviceRepository();
      final deviceId = prefs.getString('child_device_id') ?? const Uuid().v4();
      final res = await repo.registerDevice(
        deviceIdentifier: deviceId,
        deviceName: 'Farzand Telefon',
      );
      await prefs.setString('child_device_id', deviceId);

      final data = res['success'] == true ? res['data'] : null;
      final code = data is Map ? data['pairing_code'] : null;
      if (code == null) {
        _failRegistration(res['error']);
        return;
      }
      pairingCode = code.toString();
      expiresAt = data is Map && data['expires_at'] != null
          ? DateTime.tryParse(data['expires_at'].toString())?.toIso8601String()
          : null;
    } catch (e) {
      _failRegistration('Serverga ulanib bo\'lmadi. Internetni tekshirib, qayta urinib ko\'ring.');
      return;
    }

    await prefs.setString('pairing_code', pairingCode);
    if (expiresAt != null) await prefs.setString('pairing_code_expires_at', expiresAt);
    await prefs.setString('child_pin', pin);
    await prefs.setBool('is_child_mode', true);

    // Xizmatni yoqayotgan paytda "Sozlamalar" ekrani darhol bloklanib
    // qolmasligi uchun sozlashga 5 daqiqalik vaqt beramiz. U keyin o'zi o'tadi.
    // (`setLong` yo'q, `setInt` Android'da `putLong` sifatida saqlanadi.)
    await prefs.setInt(
      'unlocked_until',
      DateTime.now().millisecondsSinceEpoch + (5 * 60 * 1000),
    );

    // ---- 2. Ruxsat oynalari ----
    // Eski kodda `requestDeviceAdmin` darhol `success` qaytarardi va Dart
    // 2 soniya kutib ikkinchi oynani ochardi. Bu vaqt foydalanuvchining
    // birinchi oynada qancha turishiga bog'liq edi -> oynalar chalkashardi.
    // Endi Kotlin `onActivityResult` da haqiqiy natijani qaytaradi.
    const channel = MethodChannel('com.familycontrol/accessibility');
    final adminGranted = await channel
        .invokeMethod<bool>('requestDeviceAdmin')
        .catchError((_) => false) ??
        false;

    if (!mounted) return;
    if (!adminGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device Admin berilmadi. Ilovani o\'chirish himoyasi faollashtirilmadi.'),
        ),
      );
    }

    // Faqat birinchi oyna yopilgachdan keyin ikkinchisini ochamiz.
    await channel.invokeMethod('openAccessibilitySettings').catchError((_) {});

    if (!mounted) return;
    setState(() => _setupComplete = true);
  }

  void _failRegistration(dynamic error) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    final message = error is String
        ? error
        : 'Qurilmani ro\'yxatdan o\'tkazib bo\'lmadi. Internetni tekshirib, qayta urinib ko\'ring.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_setupComplete) {
      return const ChildHomeScreen();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Farzand rejimini sozlash')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Xavfsizlik PIN kodini o\'rnating',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ushbu PIN kod sozlamalarni o\'zgartirish yoki ilovani o\'chirishdan himoyalaydi. Uni yodda saqlang!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _pinController,
              focusNode: _pinFocus,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '6 xonali PIN kod',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _savePinAndContinue,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Saqlash va Ruxsatlarni berish'),
            ),
          ],
        ),
      ),
    );
  }
}
