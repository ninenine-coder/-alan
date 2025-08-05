import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'chat_message.dart';
import 'chat_service.dart';
import 'pet_page.dart';
import 'store_page.dart';
import 'challenge_page.dart';
import 'medal_page.dart';
import 'coin_display.dart';
import 'welcome_coin_animation.dart';
import 'coin_service.dart';
import 'user_service.dart';
import 'challenge_service.dart';

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

  String _aiName = '傑米'; // AI 桌寵名稱，初始值
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();
  bool _showWelcomeAnimation = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _currentUser = await UserService.getCurrentUser();
    if (_currentUser != null) {
      await _loadMessages();
      await _loadAiName();
      await _checkFirstLogin();
    }
  }

  Future<void> _checkFirstLogin() async {
    if (_currentUser == null) return;
    
    final isFirstLogin = await UserService.isUserFirstLogin(_currentUser!.username);
    if (isFirstLogin) {
      setState(() {
        _showWelcomeAnimation = true;
      });
    }
  }

  Future<void> _onWelcomeAnimationComplete() async {
    // 贈送500金幣
    await CoinService.addCoins(500);
    // 標記已登入
    await UserService.markUserAsLoggedIn(_currentUser!.username);
    // 刷新金幣顯示
    _coinDisplayKey.currentState?.refreshCoins();
    // 隱藏動畫
    setState(() {
      _showWelcomeAnimation = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 當頁面重新獲得焦點時刷新金幣顯示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _coinDisplayKey.currentState?.refreshCoins();
    });
  }

  Future<void> _loadMessages() async {
    if (_currentUser == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final messagesKey = UserService.getChatMessagesKey(_currentUser!.username);
    final savedMessages = prefs.getStringList(messagesKey) ?? [];
    for (var jsonString in savedMessages) {
      final message = ChatMessage.fromJson(jsonDecode(jsonString));
      _messages.add(message);
      _listKey.currentState?.insertItem(_messages.length - 1);
    }
    setState(() {});
  }

  Future<void> _saveMessages() async {
    if (_currentUser == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final messagesKey = UserService.getChatMessagesKey(_currentUser!.username);
    final jsonMessages = _messages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList(messagesKey, jsonMessages);
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

    // 處理每日訊息任務
    final messageReward = await ChallengeService.handleDailyMessage();
    if (messageReward) {
      // 刷新金幣顯示
      _coinDisplayKey.currentState?.refreshCoins();
    }

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

  // 選擇並上傳圖片
  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        if (await file.exists()) {
          // 添加圖片訊息
          final now = DateTime.now();
          final imageMessage = ChatMessage(
            text: '[圖片]',
            isUser: true,
            time: now,
            imagePath: image.path,
          );

          setState(() {
            _messages.add(imageMessage);
            _listKey.currentState?.insertItem(_messages.length - 1);
            _isTyping = true;
          });
          await _saveMessages();

          // 檢查是否為捷運站圖片
          final isMetroImage = await _checkMetroImage(image.path);
          if (isMetroImage) {
            // 處理捷運打卡任務
            final metroReward = await ChallengeService.handleMetroCheckin();
            if (metroReward) {
              // 刷新金幣顯示
              _coinDisplayKey.currentState?.refreshCoins();
              
              // 添加AI自動回復
              final aiResponse = ChatMessage(
                text: '完成每日挑戰，請自挑戰任務領取獎勵',
                isUser: false,
                time: DateTime.now(),
              );
              
              setState(() {
                _isTyping = false;
                _messages.add(aiResponse);
                _listKey.currentState?.insertItem(_messages.length - 1);
              });
              await _saveMessages();
            }
          } else {
            // 普通圖片，正常AI回復
            final response = await ChatService.sendMessage('我上傳了一張圖片');
            final aiMessage = ChatMessage(
              text: response,
              isUser: false,
              time: DateTime.now(),
            );
            
            setState(() {
              _isTyping = false;
              _messages.add(aiMessage);
              _listKey.currentState?.insertItem(_messages.length - 1);
            });
            await _saveMessages();
          }
          
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('選擇圖片時發生錯誤: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 檢查是否為捷運站圖片（簡單的文字檢測）
  Future<bool> _checkMetroImage(String imagePath) async {
    // 這裡應該使用真正的圖像識別API
    // 目前使用簡單的模擬檢測
    // 實際應用中應該使用 Google Vision API 或其他圖像識別服務
    
    // 模擬檢測：隨機返回true/false，實際應該分析圖片內容
    await Future.delayed(const Duration(seconds: 1)); // 模擬處理時間
    
    // 簡單的模擬邏輯：30% 機率檢測到捷運標示
    return DateTime.now().millisecondsSinceEpoch % 3 == 0;
  }

  void _clearMessages() async {
    setState(() {
      _messages.clear();
    });
    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      final messagesKey = UserService.getChatMessagesKey(_currentUser!.username);
      await prefs.remove(messagesKey);
    }
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

  Future<void> _loadAiName() async {
    if (_currentUser == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final aiNameKey = UserService.getAiNameKey(_currentUser!.username);
    final savedName = prefs.getString(aiNameKey) ?? '傑米';
    setState(() {
      _aiName = savedName;
    });
  }

  Future<void> _saveAiName(String name) async {
    if (_currentUser == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final aiNameKey = UserService.getAiNameKey(_currentUser!.username);
    await prefs.setString(aiNameKey, name);
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
                  child: message.imagePath != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(message.imagePath!),
                                width: 200,
                                height: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 200,
                                    height: 150,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.broken_image),
                                  );
                                },
                              ),
                            ),
                            if (message.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                message.text,
                                style: TextStyle(
                                  color: message.isUser ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        )
                      : Text(
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
                icon: const Icon(Icons.photo_camera),
                onPressed: _pickAndUploadImage,
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
                _saveAiName(newName); // 保存新名稱
              });
            }
            // 刷新金幣顯示
            _coinDisplayKey.currentState?.refreshCoins();
          });
        } else if (label == '商城') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StorePage()),
          ).then((_) {
            // 從商城返回時刷新金幣顯示
            _coinDisplayKey.currentState?.refreshCoins();
          });
        } else if (label == '挑戰任務') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChallengePage()),
          ).then((_) {
            // 從挑戰任務返回時刷新金幣顯示
            _coinDisplayKey.currentState?.refreshCoins();
          });
        } else if (label == '勳章') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MedalPage()),
          ).then((_) {
            // 從勳章頁面返回時刷新金幣顯示
            _coinDisplayKey.currentState?.refreshCoins();
          });
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
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_aiName),
        elevation: 0,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          CoinDisplay(key: _coinDisplayKey),
          const SizedBox(width: 16),
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
          // 首次登入歡迎動畫
          if (_showWelcomeAnimation)
            WelcomeCoinAnimation(
              onAnimationComplete: _onWelcomeAnimationComplete,
              targetPosition: const Offset(1.0, -1.0), // 右上角位置
            ),
        ],
      ),
    );
  }
}
