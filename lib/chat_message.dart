class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;  // 新增時間欄位
  final String? imagePath;  // 新增圖片路徑欄位

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.imagePath,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'],
      isUser: json['isUser'],
      time: DateTime.parse(json['time']),  // 將字串轉回 DateTime
      imagePath: json['imagePath'],  // 圖片路徑可能為 null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'time': time.toIso8601String(),  // 儲存為字串
      'imagePath': imagePath,  // 圖片路徑可能為 null
    };
  }
}
