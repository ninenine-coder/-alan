import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_message.dart';
import 'chat_service.dart';
import 'pet_page.dart';
import 'store_page.dart';
import 'challenge_page.dart';
import 'medal_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _showMenu = false;

  String _aiName = '冬冬'; // AI 桌寵名稱，初始值

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMessages = prefs.getStringList('chat_messages') ?? [];
    for (var jsonString in savedMessages) {
      final message = ChatMessage.fromJson(jsonDecode(jsonString));
      _messages.add(message);
      _listKey.currentState?.insertItem(_messages.length - 1);
    }
    setState(() {});
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonMessages = _messages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('chat_messages', jsonMessages);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final now = DateTime.now();

    final userMessage = ChatMessage(text: text, isUser: true, time: now);
    _controller.clear();

    setState(() {
      _messages.add(userMessage);
      _listKey.currentState?.insertItem(_messages.length - 1);
      _isTyping = true;
    });
    await _saveMessages();

    final response = await ChatService.sendMessage(text);

    final aiMessage = ChatMessage(text: response, isUser: false, time: DateTime.now());
    setState(() {
      _isTyping = false;
      _messages.add(aiMessage);
      _listKey.currentState?.insertItem(_messages.length - 1);
    });
    await _saveMessages();
    _scrollToBottom();
  }

  void _clearMessages() async {
    setState(() {
      _messages.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_messages');
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildMessage(ChatMessage message) {
    final formattedTime = TimeOfDay.fromDateTime(message.time).format(context);
    final name = message.isUser ? '我' : _aiName;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: AssetImage('assets/images/pet_avatar.png'),
                  ),
                  const SizedBox(height: 4),
                  Text(name, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isUser ? Colors.blueAccent : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedTime,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
              ],
            ),
          ),
          if (message.isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.grey.shade100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  setState(() {
                    _showMenu = !_showMenu;
                  });
                },
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: _sendMessage,
                  decoration: const InputDecoration(
                    hintText: '輸入訊息...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _sendMessage(_controller.text),
              ),
            ],
          ),
          if (_showMenu)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildMenuGrid(),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMenuItem(Icons.store, '桌寵'),
            _buildMenuItem(Icons.flag, '商城'),
            _buildMenuItem(Icons.star, '挑戰任務'),
            _buildMenuItem(Icons.emoji_events, '勳章'),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showMenu = false; // 點選後關閉選單
        });
        if (label == '桌寵') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PetPage(initialPetName: _aiName)),
          ).then((newName) {
            if (newName != null && newName is String) {
              setState(() {
                _aiName = newName;
              });
            }
          });
        } else if (label == '商城') {
        Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StorePage()),
      );
      }else if (label == '挑戰任務') {
        Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChallengePage()),
      );
      }else if (label == '勳章') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MedalPage()),
        );
      } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label 功能尚未實作'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.blue),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('捷米小助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearMessages,
            tooltip: '清除聊天紀錄',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: AnimatedList(
                  key: _listKey,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  initialItemCount: _messages.length,
                  itemBuilder: (context, index, animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      child: _buildMessage(_messages[index]),
                    );
                  },
                ),
              ),
              if (_isTyping)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'AI 正在輸入...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              const Divider(height: 1),
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }
}
