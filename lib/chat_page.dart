import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'chat_message.dart';
import 'chat_service.dart';
import 'pet_page.dart' as pet;
import 'store_page.dart';
import 'challenge_page.dart';
import 'medal_page.dart';
import 'coin_display.dart';
import 'welcome_coin_animation.dart';
import 'user_service.dart';
import 'challenge_service.dart';
import 'logger_service.dart';
import 'experience_service.dart';
import 'experience_display.dart';
import 'metro_quiz_page.dart';
import 'feature_unlock_service.dart';
import 'welcome_coin_service.dart';

import 'theme_background_widget.dart';
import 'api_service.dart';
import 'api_models.dart' as api;

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
  final ApiService _api = ApiService();
  bool _isTyping = false;
  bool _showMenu = false;

  String _aiName = '捷米';
  final GlobalKey<CoinDisplayState> _coinDisplayKey =
      GlobalKey<CoinDisplayState>();
  final GlobalKey<ExperienceDisplayState> _experienceDisplayKey =
      GlobalKey<ExperienceDisplayState>();
  bool _showWelcomeAnimation = false;
  Map<String, dynamic>? _currentUser;

  // 預載入的 HTML 內容
  String? _metroQuizHtml;

  // 功能解鎖狀態
  Map<String, bool> _featureUnlockStatus = {};

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

    _preloadMetroQuizHtml(); // 預載入捷運知識王 HTML

    // 註冊升級回調
    ExperienceService.addLevelUpCallback(_onLevelUp);
  }

  /// 獲取選擇的造型圖片
  Future<String?> _getSelectedStyleImage() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return null;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      final selectedImage = prefs.getString('selected_style_image_$username');

      // 如果沒有選擇的造型，返回造型1的圖片
      if (selectedImage == null || selectedImage.isEmpty) {
        return 'https://i.postimg.cc/vmzwkwzg/image.jpg'; // 造型1圖片
      }

      return selectedImage;
    } catch (e) {
      LoggerService.error('Error getting selected style image: $e');
      return 'https://i.postimg.cc/vmzwkwzg/image.jpg'; // 造型1圖片作為預設
    }
  }

  /// 獲取選擇的頭像圖片
  Future<String?> _getSelectedAvatarImage() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return null;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      final avatarImageUrl = prefs.getString('selected_avatar_image_$username');

      LoggerService.debug('獲取頭像圖片: $avatarImageUrl, 用戶: $username');
      return avatarImageUrl;
    } catch (e) {
      LoggerService.error('Error getting selected avatar image: $e');
      return null;
    }
  }

  /// 刷新頭像顯示
  void _refreshAvatarDisplay() {
    setState(() {
      // 觸發重新構建以更新頭像顯示
    });
    LoggerService.info('頭像顯示已刷新');
  }

  void _initializeAnimations() {
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _menuAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _menuAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _menuAnimationController, curve: Curves.easeOut),
    );

    _sendButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _sendButtonAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _sendButtonAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _backgroundAnimationController,
        curve: Curves.linear,
      ),
    );

    _backgroundAnimationController.repeat();
  }

  /// 處理升級事件
  void _onLevelUp(int newLevel) async {
    if (mounted) {
      LoggerService.info('聊天頁面收到升級事件: 等級 $newLevel');

      // 更新功能解鎖狀態
      await FeatureUnlockService.updateUnlockStatusOnLevelUp(newLevel);

      // 重新載入功能解鎖狀態
      final newUnlockStatus = await FeatureUnlockService.getUnlockStatus();
      setState(() {
        _featureUnlockStatus = newUnlockStatus;
      });

      // 刷新金幣顯示
      _coinDisplayKey.currentState?.refreshCoins();

      LoggerService.info('功能解鎖狀態已更新: $_featureUnlockStatus');
    }
  }

  @override
  void dispose() {
    // 移除升級回調
    ExperienceService.removeLevelUpCallback(_onLevelUp);

    _typingAnimationController.dispose();
    _menuAnimationController.dispose();
    _sendButtonAnimationController.dispose();
    _backgroundAnimationController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _preloadMetroQuizHtml() async {
    try {
      LoggerService.info('開始預載入捷運知識王 HTML');
      _metroQuizHtml = await rootBundle.loadString(
        'assets/mrt_knowledge/index.html',
      );
      LoggerService.info('捷運知識王 HTML 預載入完成');
    } catch (e) {
      LoggerService.error('預載入捷運知識王 HTML 失敗: $e');
      _metroQuizHtml = null;
    }
  }

  Future<void> _loadUserData() async {
    // 確保用戶資料已初始化
    await UserService.initializeUserData();

    final userData = await UserService.getCurrentUserData();
    if (userData != null) {
      setState(() {
        _currentUser = userData;
      });

      // 載入聊天紀錄
      await _loadMessages();

      // 檢查是否應該顯示歡迎金幣動畫
      final hasClaimedWelcomeCoin =
          await WelcomeCoinService.hasClaimedWelcomeCoin();
      LoggerService.debug(
        'User has claimed welcome coin: $hasClaimedWelcomeCoin',
      );

      if (!hasClaimedWelcomeCoin) {
        LoggerService.info('Welcome coin not claimed, showing animation');
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) {
          setState(() {
            _showWelcomeAnimation = true;
          });
        }
      }

      // 初始化功能解鎖狀態
      await _initializeFeatureUnlockStatus();
    }
  }

  /// 初始化功能解鎖狀態
  Future<void> _initializeFeatureUnlockStatus() async {
    try {
      final unlockStatus =
          await FeatureUnlockService.initializeFeatureUnlockStatus();
      setState(() {
        _featureUnlockStatus = unlockStatus;
      });
      LoggerService.info('功能解鎖狀態初始化完成: $_featureUnlockStatus');
    } catch (e) {
      LoggerService.error('初始化功能解鎖狀態時發生錯誤: $e');
    }
  }

  Future<void> _onWelcomeAnimationComplete() async {
    LoggerService.info('Animation complete callback called');

    // 使用 WelcomeCoinService 來處理金幣領取
    final success = await WelcomeCoinService.claimWelcomeCoin();

    if (success) {
      // 重新載入用戶數據以獲取最新的金幣數量
      final updatedUserData = await UserService.getCurrentUserData();

      setState(() {
        _currentUser = updatedUserData;
        _showWelcomeAnimation = false;
      });

      _coinDisplayKey.currentState?.refreshCoins();

      if (mounted) {
        final coinAmount = WelcomeCoinService.getWelcomeCoinAmount();
        _showSuccessSnackBar('成功獲得 $coinAmount 金幣！');
      }
    } else {
      LoggerService.error('Failed to claim welcome coin');
      setState(() {
        _showWelcomeAnimation = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 設置全局 context 用於升級動畫
    ExperienceService.setGlobalContext(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _coinDisplayKey.currentState?.refreshCoins();
    });
  }

  Future<void> _saveMessages() async {
    if (_currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final username = _currentUser!['username'] ?? 'default';
    final messagesKey = 'chat_messages_$username';
    final jsonMessages = _messages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList(messagesKey, jsonMessages);
  }

  Future<void> _loadMessages() async {
    if (_currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = _currentUser!['username'] ?? 'default';
      final messagesKey = 'chat_messages_$username';
      final jsonMessages = prefs.getStringList(messagesKey) ?? [];

      if (jsonMessages.isNotEmpty) {
        final loadedMessages = <ChatMessage>[];

        for (final jsonMessage in jsonMessages) {
          try {
            final messageData = jsonDecode(jsonMessage) as Map<String, dynamic>;
            final message = ChatMessage.fromJson(messageData);
            loadedMessages.add(message);
          } catch (e) {
            LoggerService.warning('Failed to parse message: $e');
          }
        }

        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(loadedMessages);
          });

          // 更新 AnimatedList 的項目數量
          for (int i = 0; i < _messages.length; i++) {
            _listKey.currentState?.insertItem(i);
          }

          // 滾動到底部
          if (_messages.isNotEmpty) {
            _scrollToBottom();
          }

          LoggerService.info('Loaded ${_messages.length} chat messages');
        }
      } else {
        LoggerService.debug('No saved messages found for user: $username');
      }
    } catch (e) {
      LoggerService.error('Failed to load messages: $e');
    }
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

      _typingAnimationController.repeat();

      try {
        // 檢查挑戰任務功能是否已解鎖
        final isChallengeUnlocked =
            await FeatureUnlockService.isFeatureUnlocked('挑戰任務');
        if (isChallengeUnlocked) {
          final messageReward = await ChallengeService.handleDailyMessage();
          if (messageReward) {
            _coinDisplayKey.currentState?.refreshCoins();
          }
        }
      } catch (e) {
        if (mounted) {
          _showWarningSnackBar('處理挑戰任務時發生錯誤: $e');
        }
      }

      // ★★★ 把目前對話轉成 API chat_history 格式
      final history = _messages
          .where((m) => m.imagePath == null && m.text.trim().isNotEmpty)
          .map(
            (m) => api.ChatMessage(
              role: m.isUser ? 'user' : 'assistant',
              content: m.text,
            ),
          )
          .toList();

      final req = api.ChatRequest(
        message: text,
        chatHistory: history,
        language: 'zh-Hant',
      );

      final apiResp = await _api.sendMessage(req);
      final aiMessage = ChatMessage(
        text: apiResp.response,
        isUser: false,
        time: DateTime.now(),
      );

      setState(() {
        _isTyping = false;
        _messages.add(aiMessage);
        _listKey.currentState?.insertItem(_messages.length - 1);
      });

      _typingAnimationController.stop();
      await _saveMessages();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
      });
      _typingAnimationController.stop();

      if (mounted) {
        _showErrorSnackBar('發送訊息時發生錯誤: $e');
      }
    }
  }

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

          try {
            final isMetroImage = await _checkMetroImage(image.path);
            if (isMetroImage) {
              try {
                final metroReward = await ChallengeService.handleMetroCheckin();
                if (metroReward) {
                  _coinDisplayKey.currentState?.refreshCoins();

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
                if (mounted) {
                  _showWarningSnackBar('處理挑戰任務時發生錯誤: $e');
                }
              }
            } else {
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
            if (mounted) {
              _showWarningSnackBar('檢查圖片時發生錯誤: $e');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('選擇圖片時發生錯誤: $e');
      }
    }
  }

  Future<bool> _checkMetroImage(String imagePath) async {
    await Future.delayed(const Duration(seconds: 1));
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

  Future<void> _saveAiName(String name) async {
    if (_currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final username = _currentUser!['username'] ?? 'default';
    final aiNameKey = 'ai_name_$username';
    await prefs.setString(aiNameKey, name);
  }

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
              transform: GradientRotation(
                _backgroundAnimation.value.clamp(0.0, 2 * math.pi),
              ),
            ),
          ),
          child: CustomPaint(
            painter: BackgroundPatternPainter(
              _backgroundAnimation.value.clamp(0.0, 2 * math.pi),
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  Widget _buildMarkdown(String md) {
    return MarkdownBody(
      data: md,
      selectable: true, // 允許長按選字/複製
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrlString(href, mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(fontSize: 16, color: Colors.black87),
        code: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
        codeblockDecoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: const Border(left: BorderSide(color: Colors.grey, width: 4)),
        ),
        a: const TextStyle(decoration: TextDecoration.underline),
      ),
      imageBuilder: (uri, title, alt) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          uri.toString(),
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final formattedTime = TimeOfDay.fromDateTime(message.time).format(context);
    final name = message.isUser ? '我' : _aiName;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
                    child: FutureBuilder<String?>(
                      future: _getSelectedStyleImage(),
                      builder: (context, snapshot) {
                        final imageUrl = snapshot.data;
                        if (imageUrl != null && imageUrl.isNotEmpty) {
                          return CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(imageUrl),
                            onBackgroundImageError: (exception, stackTrace) {
                              // 如果圖片載入失敗，使用預設圖標
                            },
                            child: null,
                          );
                        } else {
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blue.shade400,
                            child: Icon(
                              Icons.pets,
                              color: Colors.white,
                              size: 24,
                            ),
                          );
                        }
                      },
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
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: message.isUser
                        ? LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
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
                                  color: message.isUser
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ],
                        )
                      : (message.isUser
                            ? Text(
                                message.text,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              )
                            : _buildMarkdown(message.text)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
          if (message.isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8),
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
                    child: FutureBuilder<String?>(
                      future: _getSelectedAvatarImage(),
                      builder: (context, snapshot) {
                        final imageUrl = snapshot.data;
                        if (imageUrl != null && imageUrl.isNotEmpty) {
                          return ClipOval(
                            child: Container(
                              width: 40,
                              height: 40,
                              child: Image.network(
                                imageUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter, // 顯示圖片的上部分（頭部）
                                errorBuilder: (context, error, stackTrace) {
                                  return CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey.shade400,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.grey.shade300,
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                        ),
                                      );
                                    },
                              ),
                            ),
                          );
                        } else {
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey.shade400,
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '我',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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
          FutureBuilder<String?>(
            future: _getSelectedStyleImage(),
            builder: (context, snapshot) {
              final imageUrl = snapshot.data;
              if (imageUrl != null && imageUrl.isNotEmpty) {
                return CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(imageUrl),
                  onBackgroundImageError: (exception, stackTrace) {
                    // 如果圖片載入失敗，使用預設圖標
                  },
                  child: null,
                );
              } else {
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade400,
                  child: Icon(Icons.pets, color: Colors.white, size: 20),
                );
              }
            },
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
        final animationValue =
            ((_typingAnimationController.value.clamp(0.0, 1.0)) + delay) % 1.0;
        final scale = (0.5 + (0.5 * math.sin(animationValue * 2 * math.pi)))
            .clamp(0.0, 1.0);

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
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMenuItem(Icons.train, '捷運知識王', Colors.blue),
          const SizedBox(width: 16),
          _buildMenuItem(Icons.shopping_bag, '商城', Colors.green),
          const SizedBox(width: 16),
          _buildMenuItem(Icons.pets, '桌寵', Colors.orange),
          const SizedBox(width: 16),
          _buildMenuItem(Icons.star, '挑戰任務', Colors.purple),
          const SizedBox(width: 16),
          _buildMenuItem(Icons.emoji_events, '勳章', Colors.amber),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color color) {
    // 使用預先載入的功能解鎖狀態
    final isUnlocked = _featureUnlockStatus[label] ?? false;
    final requiredLevel = FeatureUnlockService.getRequiredLevel(label);

    LoggerService.debug('功能檢查: $label, 已解鎖: $isUnlocked, 需要等級: $requiredLevel');

    return GestureDetector(
      onTap: () {
        LoggerService.info('點擊菜單項: $label');
        _handleMenuItemTap(label, requiredLevel, isUnlocked);
      },
      child: Container(
        width: 60,
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isUnlocked
                  ? color.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              isUnlocked
                  ? color.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? color.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isUnlocked
                  ? color.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: isUnlocked ? color : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isUnlocked ? color : Colors.grey.shade400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isUnlocked)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.lock, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleMenuItemTap(String label, int requiredLevel, bool isUnlocked) {
    LoggerService.info('點擊菜單項: $label, 需要等級: $requiredLevel, 已解鎖: $isUnlocked');

    if (!isUnlocked) {
      LoggerService.info('功能未解鎖，顯示等級鎖定對話框');
      _showLevelLockDialog(label, requiredLevel);
      return;
    }

    LoggerService.info('功能已解鎖，準備導航到: $label');

    setState(() {
      _showMenu = false;
    });
    _menuAnimationController.reverse();

    // 使用 Future.delayed 來避免 context 問題
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        LoggerService.warning('Widget 已卸載，取消導航');
        return;
      }
      LoggerService.info('開始導航到: $label');
      _navigateToPage(label);
    });
  }

  void _navigateToPage(String label) {
    if (!mounted) {
      LoggerService.warning('Widget 已卸載，取消導航到: $label');
      return;
    }

    LoggerService.info('_navigateToPage 被調用，目標: $label');

    try {
      switch (label) {
        case '桌寵':
          LoggerService.info('導航到桌寵頁面');
          _navigateToPetPage();
          break;
        case '商城':
          LoggerService.info('導航到商城頁面');
          _navigateToStorePage();
          break;
        case '挑戰任務':
          LoggerService.info('導航到挑戰任務頁面');
          _navigateToChallengePage();
          break;
        case '勳章':
          LoggerService.info('導航到勳章頁面');
          _navigateToMedalPage();
          break;
        case '捷運知識王':
          LoggerService.info('導航到捷運知識王頁面');
          _navigateToMetroQuizPage();
          break;
        default:
          LoggerService.warning('未知的導航目標: $label');
      }
    } catch (e) {
      LoggerService.error('開啟頁面時發生錯誤: $e');
      _showErrorSnackBar('開啟頁面時發生錯誤: $e');
    }
  }

  void _navigateToPetPage() {
    if (!mounted) return;
    _safeNavigate(() => pet.PetPage(initialPetName: _aiName)).then((newName) {
      if (!mounted) return;
      if (newName is String) {
        setState(() {
          _aiName = newName;
          _saveAiName(newName);
        });
      }
      _coinDisplayKey.currentState?.refreshCoins();
      // 刷新頭像顯示
      _refreshAvatarDisplay();
    });
  }

  void _navigateToStorePage() {
    if (!mounted) return;
    LoggerService.info('嘗試導航到商城頁面');

    try {
      LoggerService.info('開始創建 MaterialPageRoute');
      final route = MaterialPageRoute(
        builder: (context) {
          LoggerService.info('創建 StorePage 實例');
          return const StorePage();
        },
      );
      LoggerService.info('MaterialPageRoute 創建成功');

      LoggerService.info('開始導航');
      Navigator.of(context)
          .push(route)
          .then((_) {
            LoggerService.info('導航完成，用戶返回');
            if (!mounted) {
              LoggerService.warning('Widget 已卸載，跳過後續處理');
              return;
            }
            LoggerService.info('從商城頁面返回');
            _coinDisplayKey.currentState?.refreshCoins();
            // 通知背景更新
            ThemeBackgroundNotifier().notifyBackgroundChanged();
            // 刷新頭像顯示
            _refreshAvatarDisplay();
          })
          .catchError((error) {
            LoggerService.error('導航過程中發生錯誤: $error');
            _showErrorSnackBar('導航過程中發生錯誤: $error');
          });

      LoggerService.info('導航請求已發送');
    } catch (e) {
      LoggerService.error('導航到商城頁面時發生錯誤: $e');
      _showErrorSnackBar('導航到商城頁面時發生錯誤: $e');
    }
  }

  void _navigateToChallengePage() {
    if (!mounted) return;
    _safeNavigate(() => const ChallengePage()).then((_) {
      if (!mounted) return;
      _coinDisplayKey.currentState?.refreshCoins();
    });
  }

  void _navigateToMedalPage() {
    if (!mounted) return;
    _safeNavigate(() => const MedalPage()).then((_) {
      if (!mounted) return;
      _coinDisplayKey.currentState?.refreshCoins();
    });
  }

  void _navigateToMetroQuizPage() {
    if (!mounted) return;
    _safeNavigate(() => MetroQuizPage(htmlString: _metroQuizHtml)).then((_) {
      if (!mounted) return;
      _coinDisplayKey.currentState?.refreshCoins();
    });
  }

  Future<T?> _safeNavigate<T>(Widget Function() pageBuilder) async {
    if (!mounted) return null;

    try {
      return await Navigator.of(context).push<T>(
        PageRouteBuilder<T>(
          pageBuilder: (_, animation, __) => pageBuilder(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (e) {
      LoggerService.error('導航時發生錯誤: $e');
      _showErrorSnackBar('導航時發生錯誤: $e');
    }
    return null;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    try {
      final messenger = ScaffoldMessenger.of(context);
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('顯示錯誤訊息時發生錯誤: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    try {
      final messenger = ScaffoldMessenger.of(context);
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber),
                const SizedBox(width: 8),
                Text(message),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('顯示成功訊息時發生錯誤: $e');
    }
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;

    try {
      final messenger = ScaffoldMessenger.of(context);
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('顯示警告訊息時發生錯誤: $e');
    }
  }

  void _showLevelLockDialog(String feature, int requiredLevel) {
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('功能未解鎖'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '您需要達到等級 $requiredLevel 才能使用 $feature 功能',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                '請繼續提升等級來解鎖更多功能！',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (e) {
      LoggerService.error('顯示等級鎖定對話框時發生錯誤: $e');
    }
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
        automaticallyImplyLeading: false,
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
              child: FutureBuilder<String?>(
                future: _getSelectedStyleImage(),
                builder: (context, snapshot) {
                  final imageUrl = snapshot.data;
                  if (imageUrl != null && imageUrl.isNotEmpty) {
                    return CircleAvatar(
                      backgroundImage: NetworkImage(imageUrl),
                      onBackgroundImageError: (exception, stackTrace) {
                        // 如果圖片載入失敗，使用預設圖標
                      },
                      child: null,
                    );
                  } else {
                    return CircleAvatar(
                      backgroundColor: Colors.blue.shade400,
                      child: Icon(Icons.pets, color: Colors.white, size: 20),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _aiName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                ExperienceDisplay(key: _experienceDisplayKey, isCompact: true),
              ],
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
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              // 跳轉回登入頁面
              Navigator.of(context).pushReplacementNamed('/login');
            },
            tooltip: '登出',
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: ThemeBackgroundListener(
        overlayColor: Colors.white,
        overlayOpacity: 0.7,
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 100),

                Expanded(
                  child: AnimatedList(
                    key: _listKey,
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                    initialItemCount: _messages.length,
                    itemBuilder: (context, index, animation) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.5),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                            ),
                        child: FadeTransition(
                          opacity: animation,
                          child: _buildMessage(_messages[index]),
                        ),
                      );
                    },
                  ),
                ),

                if (_isTyping) _buildTypingIndicator(),

                _buildInputArea(),
              ],
            ),

            if (_showWelcomeAnimation)
              WelcomeCoinAnimation(
                onAnimationComplete: _onWelcomeAnimationComplete,
                coinAmount: WelcomeCoinService.getWelcomeCoinAmount(),
              ),
          ],
        ),
      ),
    );
  }
}

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

      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
