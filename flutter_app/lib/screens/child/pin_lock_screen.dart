import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _pinController = TextEditingController();
  String _error = '';

  Future<void> _verifyPin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('child_pin');

    if (_pinController.text == savedPin) {
      // 5 daqiqaga ruxsat berish.
      //
      // DIQQAT: Dart'da `setLong` metodi YO'Q — shared_preferences faqat
      // setInt/setDouble/setBool/setString/setStringList beradi. Android
      // plagini esa `setInt` qiymatini ichkarida `putLong` bilan saqlaydi,
      // shuning uchun Kotlin tomondagi `getLong` to'g'ri ishlaydi.
      // Ikkala tomon bir xil tipda bo'lishi SHART (ClassCastException).
      final until = DateTime.now().millisecondsSinceEpoch + (5 * 60 * 1000);
      await prefs.setInt('unlocked_until', until);
      
      // Ilovani yopib orqaga (sozlamalarga) qaytaramiz
      SystemNavigator.pop();
    } else {
      setState(() {
        _error = 'Noto\'g\'ri PIN kod!';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Ruxsat etilmagan harakat!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sozlamalarga kirish uchun ota-ona PIN kodini kiriting',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.black26,
                counterText: '',
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                if (v.length == 6) _verifyPin();
              },
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber)),
            ],
          ],
        ),
      ),
    );
  }
}
