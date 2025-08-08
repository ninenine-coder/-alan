import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
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

  // 動畫控制器
  late AnimationController _typingAnimationController;
  late AnimationController _menuAnimationController;
  late AnimationController _sendButtonAnimationController;
  late Animation<double> _menuAnimation;
  late Animation<double> _sendButtonAnimation;

  // 背景動畫
  late AnimationController _backgroundAnimationController;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
    // 打字動畫
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // 選單動畫
    _menuAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _menuAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _menuAnimationController, curve: Curves.easeOut),
    );

    // 發送按鈕動畫
    _sendButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _sendButtonAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _sendButtonAnimationController, curve: Curves.easeInOut),
    );

    // 背景動畫
    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _backgroundAnimationController, curve: Curves.linear),
    );

    // 開始背景動畫
    _backgroundAnimationController.repeat();
  }

  @override
  void dispose() {
    _typingAnimationController.dispose();
    _menuAnimationController.dispose();
    _sendButtonAnimationController.dispose();
    _backgroundAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      _currentUser = await UserService.getCurrentUser();
      if (_currentUser != null) {
        await _loadMessages();
        await _loadAiName();
        await _checkFirstLogin();
      }
    } catch (e) {
      // 處理用戶數據載入錯誤
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入用戶數據時發生錯誤: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

    try {
      final now = DateTime.now();

      final userMessage = ChatMessage(text: text, isUser: true, time: now);
      _controller.clear();

      setState(() {
        _messages.add(userMessage);
        _listKey.currentState?.insertItem(_messages.length - 1);
        _isTyping = true;
      });
      await _saveMessages();

      // 啟動打字動畫
      _typingAnimationController.repeat();

      // 處理每日訊息任務
      try {
        final messageReward = await ChallengeService.handleDailyMessage();
        if (messageReward) {
          // 刷新金幣顯示
          _coinDisplayKey.currentState?.refreshCoins();
        }
      } catch (e) {
        // 處理挑戰服務錯誤
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('處理挑戰任務時發生錯誤: $e'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      final response = await ChatService.sendMessage(text);

      final aiMessage = ChatMessage(text: response, isUser: false, time: DateTime.now());
      setState(() {
        _isTyping = false;
        _messages.add(aiMessage);
        _listKey.currentState?.insertItem(_messages.length - 1);
      });
      
      // 停止打字動畫
      _typingAnimationController.stop();
      
      await _saveMessages();
      _scrollToBottom();
    } catch (e) {
      // 處理發送訊息錯誤
      setState(() {
        _isTyping = false;
      });
      _typingAnimationController.stop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('發送訊息時發生錯誤: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
          try {
            final isMetroImage = await _checkMetroImage(image.path);
            if (isMetroImage) {
              // 處理捷運打卡任務
              try {
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
              } catch (e) {
                // 處理挑戰服務錯誤
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('處理挑戰任務時發生錯誤: $e'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
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
          } catch (e) {
            // 處理圖片檢查錯誤
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('檢查圖片時發生錯誤: $e'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      // 錯誤處理
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('選擇圖片時發生錯誤: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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

  // 美化的背景組件
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.purple.shade50,
                Colors.pink.shade50,
                Colors.blue.shade50,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
              transform: GradientRotation(_backgroundAnimation.value.clamp(0.0, 2 * math.pi)),
            ),
          ),
          child: CustomPaint(
            painter: BackgroundPatternPainter(_backgroundAnimation.value.clamp(0.0, 2 * math.pi)),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final formattedTime = TimeOfDay.fromDateTime(message.time).format(context);
    final name = message.isUser ? '我' : _aiName;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: const AssetImage('assets/images/pet_avatar.png'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: message.isUser
                        ? LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [Colors.white, Colors.grey.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(message.isUser ? 20 : 8),
                      bottomRight: Radius.circular(message.isUser ? 8 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: message.imagePath != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(message.imagePath!),
                                width: 200,
                                height: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 200,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ],
                        )
                      : Text(
                          message.text,
                          style: TextStyle(
                            color: message.isUser ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formattedTime,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }

  // 美化的打字指示器
  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: const AssetImage('assets/images/pet_avatar.png'),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _aiName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildTypingDot(0),
                  const SizedBox(width: 4),
                  _buildTypingDot(1),
                  const SizedBox(width: 4),
                  _buildTypingDot(2),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final delay = index * 0.2;
        final animationValue = ((_typingAnimationController.value.clamp(0.0, 1.0)) + delay) % 1.0;
        final scale = (0.5 + (0.5 * math.sin(animationValue * 2 * math.pi))).clamp(0.0, 1.0);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 選單按鈕
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _showMenu = !_showMenu;
                      });
                      if (_showMenu) {
                        _menuAnimationController.forward();
                      } else {
                        _menuAnimationController.reverse();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                
                // 輸入框
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: '輸入訊息...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.photo_camera,
                                color: Colors.blue.shade600,
                              ),
                              onPressed: _pickAndUploadImage,
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // 發送按鈕
                GestureDetector(
                  onTapDown: (_) => _sendButtonAnimationController.forward(),
                  onTapUp: (_) => _sendButtonAnimationController.reverse(),
                  onTapCancel: () => _sendButtonAnimationController.reverse(),
                  onTap: () => _sendMessage(_controller.text),
                  child: AnimatedBuilder(
                    animation: _sendButtonAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _sendButtonAnimation.value.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade400, Colors.blue.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const IconButton(
                            icon: Icon(Icons.send, color: Colors.white),
                            onPressed: null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // 選單區域
          if (_showMenu)
            AnimatedBuilder(
              animation: _menuAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _menuAnimation.value.clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: _menuAnimation.value.clamp(0.0, 1.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showMenu = false;
                        });
                        _menuAnimationController.reverse();
                      },
                      child: _buildMenuGrid(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMenuItem(Icons.pets, '桌寵', Colors.orange),
              _buildMenuItem(Icons.shopping_bag, '商城', Colors.green),
              _buildMenuItem(Icons.star, '挑戰任務', Colors.purple),
              _buildMenuItem(Icons.emoji_events, '勳章', Colors.amber),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _showMenu = false;
        });
        _menuAnimationController.reverse();
        
        // 添加延遲以避免動畫衝突
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!mounted) return;
        
        try {
          if (label == '桌寵') {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PetPage(initialPetName: _aiName)),
            ).then((newName) {
              if (newName != null && newName is String) {
                setState(() {
                  _aiName = newName;
                  _saveAiName(newName);
                });
              }
              _coinDisplayKey.currentState?.refreshCoins();
            });
          } else if (label == '商城') {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StorePage()),
            ).then((_) {
              _coinDisplayKey.currentState?.refreshCoins();
            });
          } else if (label == '挑戰任務') {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChallengePage()),
            ).then((_) {
              _coinDisplayKey.currentState?.refreshCoins();
            });
          } else if (label == '勳章') {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MedalPage()),
            ).then((_) {
              _coinDisplayKey.currentState?.refreshCoins();
            });
          }
        } catch (e) {
          // 處理任何錯誤
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('開啟頁面時發生錯誤: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
              ),
              child: const CircleAvatar(
                backgroundImage: AssetImage('assets/images/pet_avatar.png'),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _aiName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.purple.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          CoinDisplay(key: _coinDisplayKey),
          const SizedBox(width: 16),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 動畫背景
          _buildAnimatedBackground(),
          
          Column(
            children: [
              const SizedBox(height: 100), // AppBar 高度
              Expanded(
                child: AnimatedList(
                  key: _listKey,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  initialItemCount: _messages.length,
                  itemBuilder: (context, index, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      )),
                      child: FadeTransition(
                        opacity: animation,
                        child: _buildMessage(_messages[index]),
                      ),
                    );
                  },
                ),
              ),
              
              // 打字指示器
              if (_isTyping) _buildTypingIndicator(),
              
              _buildInputArea(),
            ],
          ),
          
          // 首次登入歡迎動畫
          if (_showWelcomeAnimation)
            WelcomeCoinAnimation(
              onAnimationComplete: _onWelcomeAnimationComplete,
              targetPosition: const Offset(1.0, -1.0),
            ),
        ],
      ),
    );
  }
}

// 背景圖案繪製器
class BackgroundPatternPainter extends CustomPainter {
  final double animationValue;

  BackgroundPatternPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      final clampedValue = animationValue.clamp(0.0, 2 * math.pi);
      final x = (size.width * i / 20) + (clampedValue * 50);
      final y = size.height * 0.2 + (math.sin(clampedValue + i * 0.5) * 20);
      
      canvas.drawCircle(
        Offset(x, y),
        3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

