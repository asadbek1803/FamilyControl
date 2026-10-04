import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/login_screen.dart';
import 'child/child_setup_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, bool isChild) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_child_mode', isChild);
    
    if (!context.mounted) return;
    
    if (isChild) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChildSetupScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kim foydalanmoqda?')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Qurilma turini tanlang',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(24),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.admin_panel_settings, size: 32),
              label: const Text('Ota-ona qurilmasi', style: TextStyle(fontSize: 18)),
              onPressed: () => _selectRole(context, false),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(24),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.child_care, size: 32),
              label: const Text('Farzand qurilmasi', style: TextStyle(fontSize: 18)),
              onPressed: () => _selectRole(context, true),
            ),
          ],
        ),
      ),
    );
  }
}
