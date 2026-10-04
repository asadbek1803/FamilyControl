import 'package:http/http.dart' as http;

void main() async {
  final botToken = '8887166286:AAH47aar4N0Q_2qZtkr1MNxEyH0Ir7zApDU';
  final chatId = '8390479413';
  final url = 'https://api.telegram.org/bot$botToken/sendMessage';
  
  try {
    final response = await http.post(Uri.parse(url), body: {
      'chat_id': chatId,
      'text': 'Test from dart script',
    });
    print('Status code: ${response.statusCode}');
    print('Response body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
