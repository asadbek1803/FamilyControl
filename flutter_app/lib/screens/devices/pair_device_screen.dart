import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/connectivity_provider.dart';

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pairingCodeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _success = false;

  @override
  void dispose() {
    _pairingCodeController.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    if (!_formKey.currentState!.validate()) return;

    final isOnline = context.read<ConnectivityProvider>().isOnline;
    if (!isOnline) {
      setState(() {
        _errorMessage = 'Internet aloqasi yo\'q. Qurilmani ulash uchun internet kerak.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await context.read<DeviceProvider>().pairDevice(
          pairingCode: _pairingCodeController.text.trim(),
        );

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      setState(() => _success = true);
    } else {
      setState(() {
        _errorMessage = _parseError(result['error']);
      });
    }
  }

  String _parseError(dynamic error) {
    if (error == null) return 'Noma\'lum xato';
    if (error is Map) {
      return error.values
          .expand((v) => v is List ? v.map((e) => e.toString()) : [v.toString()])
          .join('\n');
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qurilma ulash')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _success ? _SuccessWidget() : _PairForm(),
      ),
    );
  }

  Widget _SuccessWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Qurilma muvaffaqiyatli ulandi!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Qurilmalar ro\'yxatiga qaytish'),
        ),
      ],
    );
  }

  Widget _PairForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          Card(
            color: Colors.blue.withOpacity(0.08),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Qanday ulash mumkin?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('1. Bolaning telefonida FamilyControl ilovasini oching'),
                  Text('2. Ekrandagi 6 xonali ulash kodini kiriting'),
                  Text('3. Kod 30 daqiqa ichida amal qiladi'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kod eskirgan bo\'lsa, bolaning telefonida FamilyControl → «Yangi kod olish» '
            'tugmasini bosing.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pairingCodeController,
            decoration: const InputDecoration(
              labelText: '6 xonali pairing code',
              hintText: 'Masalan: 123456',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _pair(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Majburiy maydon';
              if (v.length != 6 || !RegExp(r'^\d{6}$').hasMatch(v)) {
                return '6 ta raqam kiriting';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _pair,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ulash', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
