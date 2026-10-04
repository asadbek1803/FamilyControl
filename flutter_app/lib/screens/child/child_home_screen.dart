import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChildHomeScreen extends StatelessWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 100, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Xavfsizlik rejimi faol',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Qurilma ota-ona nazorati ostida',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 60),
            // SOS Tugmasi
            GestureDetector(
              onLongPress: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('SOS Signali yuborildi! Ota-onangizga xabar ketdi.'),
                    backgroundColor: Colors.red,
                  ),
                );
                // TODO: API orqali SOS signalini jo'natish mantiqi qo'shiladi
              },
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
              onPressed: () {
                SystemNavigator.pop();
              },
              child: const Text('Tizimdan chiqish (Uy ekrani)'),
            )
          ],
        ),
      ),
    );
  }
}
