import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class TelegramFallbackService {
  static const String botToken = '8887166286:AAH47aar4N0Q_2qZtkr1MNxEyH0Ir7zApDU';
  static const String chatId = '8390479413';

  static bool _isNotified = false;

  /// API ishlashdan to'xtaganda Telegramga xabar beradi
  static Future<void> notifyApiDown() async {
    if (botToken.isEmpty || chatId.isEmpty) return;
    if (_isNotified) return;

    final currentUrl = ApiConstants.baseUrl;
    final text = '🚨 Diqqat! FamilyControl API ulanishda xatolik yuz berdi (Tarmoq yoki server ishlamayapti).\n\n'
        'Joriy URL: $currentUrl\n\n'
        'Iltimos, yangi API URL manzilini shu botga yuboring (Masalan: http://192.168.1.100:8000/api/v1).';

    final url = 'https://api.telegram.org/bot$botToken/sendMessage';
    try {
      await http.post(Uri.parse(url), body: {
        'chat_id': chatId,
        'text': text,
      }).timeout(const Duration(seconds: 5));
      _isNotified = true;
      // Spam qilmaslik uchun 5 daqiqadan so'ng yana yozishga ruxsat beradi
      Future.delayed(const Duration(seconds: 10), () {
        _isNotified = false;
      });
    } catch (e) {
      print("Telegram xatosi: $e");
    }
  }

  /// Botga oxirgi kelgan xabarni o'qib, yangi URL borligini tekshiradi
  static Future<String?> checkNewApiUrl() async {
    if (botToken.isEmpty || chatId.isEmpty) return null;

    final url = 'https://api.telegram.org/bot$botToken/getUpdates?offset=-1';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true && data['result'] != null && data['result'].isNotEmpty) {
          final lastMessage = data['result'][0]['message'];
          if (lastMessage != null && lastMessage['chat']['id'].toString() == chatId) {
            final text = lastMessage['text'].toString().trim();
            // Agar xabar http bilan boshlansa va bizdagi URL dan farq qilsa, uni yangi URL deb qabul qilamiz
            if (text.startsWith('http') && text != ApiConstants.baseUrl) {
              return text;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Yangi URL muvaffaqiyatli o'rnatilganda tasdiqlash xabarini yuboradi
  static Future<void> sendConfirmation(String newUrl) async {
    if (botToken.isEmpty || chatId.isEmpty) return;
    final text = '✅ Ilova yangi manzilni qabul qildi va muvaffaqiyatli saqladi!\n\nYangi URL: $newUrl\nEndi ilovadan xotirjam foydalanishingiz mumkin.';
    final url = 'https://api.telegram.org/bot$botToken/sendMessage';
    try {
      await http.post(Uri.parse(url), body: {
        'chat_id': chatId,
        'text': text,
      }).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
