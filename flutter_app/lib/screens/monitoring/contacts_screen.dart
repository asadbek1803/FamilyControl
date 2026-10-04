import 'package:flutter/material.dart';
import '../../models/child_device.dart';

class ContactsScreen extends StatelessWidget {
  final ChildDevice device;

  const ContactsScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${device.deviceName.isNotEmpty ? device.deviceName : "Qurilma"} Kontaktlari'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5, // Demo uchun
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final isNew = index == 0;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.person, color: Colors.blue.shade900),
            ),
            title: Text(
              ['Onam', 'Dadam', 'O\'qituvchi', 'Sinfdosh Ali', 'Noma\'lum raqam'][index],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(['+998 90 123 45 67', '+998 91 234 56 78', '+998 99 345 67 89', '+998 93 456 78 90', '+998 94 567 89 01'][index]),
            trailing: isNew
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Yangi', style: TextStyle(color: Colors.red, fontSize: 12)),
                  )
                : null,
          );
        },
      ),
    );
  }
}
