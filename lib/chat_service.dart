// chat_service.dart

class ChatService {
  static Future<String> sendMessage(String message) async {
    await Future.delayed(const Duration(seconds: 1));
    if (message.contains('你好')) {
      return '你好！有什麼我可以幫忙的嗎？';
    } else if (message.contains('幾號')) {
      return '今天是 ${DateTime.now().month}月${DateTime.now().day}日';
    } else {
      return '我還不太懂你的意思，能換個方式說嗎？';
    }
  }
}
