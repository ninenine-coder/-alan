import 'dart:convert';

// ノ chat_history 虫癟家
class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});

  // 眖 Map (JSON) 锣传ン
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(role: json['role'], content: json['content']);
  }
  // 眖ン锣传 Map (JSON)
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// 叫―家 (Request Model)
class ChatRequest {
  final String message;
  final List<ChatMessage> chatHistory;
  final String language;

  ChatRequest({
    required this.message,
    this.chatHistory = const [],
    this.language = 'zh-Hant',
  });

  Map<String, dynamic> toJson() => {
    'message': message,
    'chat_history': chatHistory.map((m) => m.toJson()).toList(),
    'language': language,
  };
} // 莱家 (Response Model)

class ChatResponse {
  final String response;
  final List<ChatMessage> chatHistory;

  ChatResponse({required this.response, required this.chatHistory});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final historyFromJson = (json['chat_history'] as List?) ?? [];
    final historyList = historyFromJson
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();

    return ChatResponse(
      response: (json['response'] as String?) ?? '',
      chatHistory: historyList,
    );
  }
}
