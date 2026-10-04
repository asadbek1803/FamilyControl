import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/child_device.dart';
import '../../providers/device_provider.dart';

/// Qurilma tahrirlash — asosan **farzand nomini** qo'yish.
///
/// Nima uchun bu muhim: panelda qurilmalar farzand nomi bo'yicha
/// guruhlanadi. Nom qo'yilmagan qurilmalar alohida turadi va ota-ona
/// "bu qurilma qaysi farzandniki?" degan savolga javob topa olmaydi.
///
/// `child_name` majburiy emas: bo'sh qoldirilsa, panelda qurilma nomi
/// ko'rsatiladi (serverdagi `display_child_name`).
class EditDeviceScreen extends StatefulWidget {
  final ChildDevice device;

  const EditDeviceScreen({super.key, required this.device});

  @override
  State<EditDeviceScreen> createState() => _EditDeviceScreenState();
}

class _EditDeviceScreenState extends State<EditDeviceScreen> {
  late final TextEditingController _childNameController;
  late final TextEditingController _deviceNameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _childNameController = TextEditingController(text: widget.device.childName);
    _deviceNameController =
        TextEditingController(text: widget.device.deviceName);
  }

  @override
  void dispose() {
    _childNameController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final childName = _childNameController.text.trim();
    final deviceName = _deviceNameController.text.trim();

    if (childName.isEmpty && deviceName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamida bittasini kiriting: farzand nomi yoki qurilma nomi'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok = await context.read<DeviceProvider>().updateDeviceNames(
          widget.device.id,
          childName: childName,
          deviceName: deviceName,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saqlanmadi. Serverga ulanib, qayta urinib ko\'ring.'),
        ),
      );
      return;
    }

    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saqlandi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qurilmani tahrirlash')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farzand nomi',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bitta farzand bir nechta qurilma ishlatishi mumkin '
                    '(telefon + planshet) — ular shu nom bo\'yicha bitta '
                    'guruhda birlashadi.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _childNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Ism',
                      hintText: 'Alisher',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 120,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Qurilma nomi',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nomlanmagan farzand uchun ko\'rsatiladigan matn. '
                    'Masalan: "Alisher telefoni".',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _deviceNameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Qurilma nomi',
                      hintText: 'Xiaomi Redmi 12',
                      prefixIcon: Icon(Icons.smartphone),
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 255,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Qurilma identifikatorini o\'zgartirib bo\'lmaydi — '
                      'u qurilmaning o\'ziga bog\'liq va almashtirilsa, '
                      'qurilma boshqa oilaga o\'tib ketishi mumkin.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saqlanmoqda...' : 'Saqlash'),
          ),
        ),
      ),
    );
  }
}
