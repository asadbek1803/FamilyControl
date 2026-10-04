import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/remote_config.dart';
import '../../providers/notification_settings_provider.dart';

/// Ota-onaning Telegram bildirishnoma sozlamalari.
///
/// Bot tokeni ilovada emas — faqat serverda. Shu sababli bu ekran botning
/// o'zini ham ko'rsatadi: ota-onaga "@bot" nomi yoki ID sidan `/start`
/// yuborish kerakligi aytiladi, chunki Telegram bot faqat o'ziga yozgan
/// chat'larga xabar yubora oladi.
class TelegramSettingsScreen extends StatefulWidget {
  const TelegramSettingsScreen({super.key});

  @override
  State<TelegramSettingsScreen> createState() => _TelegramSettingsScreenState();
}

class _TelegramSettingsScreenState extends State<TelegramSettingsScreen> {
  final _chatIdController = TextEditingController();
  bool _enabled = false;
  bool _didLoadSetting = false;
  DateTime? _lastServerCheck;

  @override
  void initState() {
    super.initState();
    // GitHub dan oxirgi tekshiruv vaqti — sozlamalar ekranida ko'rsatiladi.
    RemoteConfig.lastFetchedAt().then((value) {
      if (mounted) setState(() => _lastServerCheck = value);
    });
  }

  @override
  void dispose() {
    _chatIdController.dispose();
    super.dispose();
  }

  void _applySetting(NotificationSettingsProvider provider) {
    if (_didLoadSetting) return;
    _didLoadSetting = true;
    _enabled = provider.setting.isEnabled;
    _chatIdController.text = provider.setting.chatId?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationSettingsProvider>();

    // Birinchi build'da joriy qiymatlarni maydonga ko'chirish
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && provider.errorMessage == null) {
        setState(() => _applySetting(provider));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Telegram bildirishnomalari')),
      body: provider.isLoading && provider.setting.chatId == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications_active,
                                color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Bildirishnomalar yuborilsinmi?',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Switch(
                              value: _enabled,
                              onChanged: (v) => setState(() => _enabled = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sizga yuboriladigan xabarlar: qurilma ulandi/uzildi, '
                          'SOS signali, ilova bloklandi, batareya past, '
                          'himoya o\'chirildi, zona chegarasidan chiqdi.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!provider.setting.botConfigured)
                  Card(
                    color: Colors.red.withOpacity(0.1),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Serverda TELEGRAM_BOT_TOKEN sozlanmagan. '
                              'Administrator bilan bog\'laning.',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (provider.setting.botConfigured &&
                    provider.setting.chatId == null) ...[
                  Card(
                    color: Colors.blue.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Qanday ulanadi?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.setting.botUsername != null
                                ? '1. Telegram\'da botni oching: @${provider.setting.botUsername}'
                                : '1. Telegram\'da FamilyControl botini oching',
                          ),
                          const Text('2. Botga /start yuboring'),
                          const Text('3. Chat ID ni kiriting'),
                          const SizedBox(height: 8),
                          const Text(
                            'Chat ID ni olish: @userinfobot yoki @getidsbot '
                            'botlaridan biriga yozing.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _chatIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Telegram Chat ID',
                    hintText: 'Masalan: 123456789',
                    prefixIcon: Icon(Icons.telegram),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (provider.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ElevatedButton(
                  onPressed: provider.isLoading ? null : () => _save(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: provider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Saqlash'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      provider.isLoading ? null : () => _sendTest(context),
                  icon: const Icon(Icons.send),
                  label: const Text('Test xabarini yuborish'),
                ),
                if (provider.setting.chatId != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Ulangan chat: ${provider.setting.chatTitle.isEmpty ? provider.setting.chatId : provider.setting.chatTitle}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (provider.setting.lastSentAt != null)
                    Text(
                      'Oxirgi xabar: ${provider.setting.lastSentAt!.toLocal()}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
                const SizedBox(height: 32),
                // Joriy server. Bu yerda ko'rsatish muhim: server manzili
                // GitHub'dan yangilanadi, shuning uchun foydalanuvchi qayeriga
                // ulanganini bilishi kerak (noto'g'ri server — ma'lumotni
                // yo'qotish degani).
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Server',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  ApiConstants.baseUrl,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  _serverSourceLabel,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
    );
  }

  String get _serverSourceLabel {
    final checkedAt = _lastServerCheck;
    if (checkedAt == null) {
      return 'Kodda yozilgan manzil (GitHub dan yangilanmagan)';
    }
    return 'GitHub dan olingan (${checkedAt.toLocal()})';
  }

  Future<void> _save(BuildContext context) async {
    final id = int.tryParse(_chatIdController.text.trim());
    if (id == null) {
      _showError(context, 'Chat ID raqamdan iborat bo\'lishi kerak');
      return;
    }
    final provider = context.read<NotificationSettingsProvider>();
    final ok = await provider.save(chatId: id, isEnabled: _enabled);
    if (!context.mounted) return;
    _showError(
      context,
      ok ? 'Saqlandi' : provider.errorMessage ?? 'Xatolik yuz berdi',
      isError: !ok,
    );
  }

  Future<void> _sendTest(BuildContext context) async {
    final provider = context.read<NotificationSettingsProvider>();
    final ok = await provider.sendTestMessage();
    if (!context.mounted) return;
    _showError(
      context,
      ok ? 'Test xabari yuborildi' : provider.errorMessage ?? 'Xatolik yuz berdi',
      isError: !ok,
    );
  }

  void _showError(BuildContext context, String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }
}
