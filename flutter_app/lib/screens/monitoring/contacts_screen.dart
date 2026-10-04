import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../models/child_device.dart';
import '../../models/contact.dart';
import '../../providers/device_provider.dart';

/// Bolaning qurilmasidagi kontaktlar.
///
/// DIQQAT: bu ekran avval butunlay DEMO ma'lumot ko'rsatardi — 5 ta soxta
/// kontakt ("Onam", "Dadam" + qo'lda yozilgan telefon raqamlari). Ota-ona
/// uchun bu xavfli: ro'yxat haqiqiy ko'rinsa, u haqiqiy raqamlar deb
/// ishonib, noto'g'ri qaror qabul qilishi mumkin edi.
///
/// Endi ma'lumot faqat serverdan olinadi. Android ilovasi boshqa ilovalarning
/// kontaktlarini o'qiydi (`READ_CONTACTS`) — bu telefon raqamlari ro'yxati,
/// matnli xabarlar EMAS. Chegara haqida `README.md` "Chegara: yashirin
/// kuzatuv" bo'limida.
class ContactsScreen extends StatefulWidget {
  final ChildDevice device;

  const ContactsScreen({super.key, required this.device});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadContacts(widget.device.id);
    });
  }

  Future<void> _load() =>
      context.read<DeviceProvider>().loadContacts(widget.device.id);

  Future<void> _delete(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kontaktni ro\'yxatdan o\'chirish'),
        content: Text(
          '"${contact.contactName}" kontaktini ota-ona ro\'yxatidan '
          'o\'chirilsinmi?\n\n'
          'DIQQAT: bu kontakt bolaning telefonidan O\'CHIRILMAYDI — '
          'faqat sizning ro\'yxatingizdan yo\'q qilinadi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await context
        .read<DeviceProvider>()
        .deleteContact(widget.device.id, contact.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Ro\'yxatdan o\'chirildi' : 'O\'chirilmadi'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final contacts = provider.contacts;

    return Scaffold(
      appBar: AppBar(
        title: Text('Kontaktlar - ${widget.device.displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yangilash',
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(provider, contacts),
    );
  }

  Widget _buildBody(DeviceProvider provider, List<Contact> contacts) {
    if (provider.isLoading && contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (contacts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Icon(Icons.contacts_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Kontaktlar kelmagan',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Bolaning telefonida kontaktlar sinxronlanishi kerak.\n'
              'Boshqa sabab: hali hech qanday kontakt yuborilmagan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Server `is_new` bo'yicha belgilaydi. Ikkalasini aralashtirmaslik uchun
    // "yangi" (server bo'yicha haqiqiy) va "qolgan" guruhlarga ajratamiz.
    final newOnes = contacts.where((c) => c.isNew).toList();
    final others = contacts.where((c) => !c.isNew).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: contacts.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          if (newOnes.isNotEmpty && index < newOnes.length) {
            return _ContactTile(
              contact: newOnes[index],
              isNewSection: true,
              isLastInSection: index == newOnes.length - 1,
              onDelete: () => _delete(newOnes[index]),
            );
          }

          final offset = newOnes.isEmpty ? 0 : newOnes.length;
          final contact = others[index - offset];
          return _ContactTile(
            contact: contact,
            isNewSection: false,
            isLastInSection: index == contacts.length - 1,
            onDelete: () => _delete(contact),
          );
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final bool isNewSection;
  final bool isLastInSection;
  final VoidCallback onDelete;

  const _ContactTile({
    required this.contact,
    required this.isNewSection,
    required this.isLastInSection,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNewSection)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.fiber_new, size: 18, color: Colors.red),
                const SizedBox(width: 6),
                Text(
                  'Yangi qo\'shilgan kontaktlar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
              ],
            ),
          ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: contact.isNew ? Colors.red[100] : Colors.blue[100],
            child: Icon(
              Icons.person,
              color: contact.isNew ? Colors.red[800] : Colors.blue[800],
            ),
          ),
          title: Text(
            contact.contactName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            [
              contact.phoneNumber.isEmpty ? 'Raqam yo\'q' : contact.phoneNumber,
              if (contact.updatedAt != null)
                AppDateUtils.formatDate(contact.updatedAt),
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Ro\'yxatdan o\'chirish',
            color: Colors.grey,
            onPressed: onDelete,
          ),
        ),
        // "Yangi" qismidan chiqishda qo\'shimcha ajratgich — aks holda
        // yangi kontaktlar va oddiy ro\'yxat bir-biriga aralashib ketadi.
        if (!isLastInSection)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 16),
          ),
      ],
    );
  }
}
