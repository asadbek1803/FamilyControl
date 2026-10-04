import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'child_home_screen.dart';
import 'package:flutter/services.dart';

class ChildSetupScreen extends StatefulWidget {
  const ChildSetupScreen({super.key});

  @override
  State<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends State<ChildSetupScreen> {
  final _pinController = TextEditingController();
  bool _setupComplete = false;

  Future<void> _savePinAndContinue() async {
    final pin = _pinController.text;
    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN kod 6 ta raqamdan iborat bo\'lishi kerak')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('child_pin', pin);
    await prefs.setBool('is_child_mode', true);
    
    // Android Maxsus imkoniyatlarni (Accessibility) so'rash uchun native channel
    const channel = MethodChannel('com.familycontrol/accessibility');
    try {
      await channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('Error: $e');
    }

    setState(() {
      _setupComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_setupComplete) {
      return const ChildHomeScreen();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Farzand rejimini sozlash')),
      body: Padding(
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
              onPressed: _savePinAndContinue,
              child: const Text('Saqlash va Ruxsatlarni berish'),
            )
          ],
        ),
      ),
    );
  }
}
