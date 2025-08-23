import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'coin_display.dart';
import 'user_service.dart';
import 'challenge_service.dart';
import 'logger_service.dart';
import 'experience_service.dart';
import 'feature_unlock_service.dart';
import 'theme_background_service.dart';
import 'theme_background_widget.dart';
import 'unified_user_data_service.dart';

class PetPage extends StatefulWidget {
  final String initialPetName;

  const PetPage({super.key, required this.initialPetName});

  @override
  State<PetPage> createState() => _PetPageState();
}

class _PetPageState extends State<PetPage> with TickerProviderStateMixin {
  late String petName;
  final GlobalKey<CoinDisplayState> _coinDisplayKey =
      GlobalKey<CoinDisplayState>();
  bool _isInteracting = false;
  late AnimationController _backButtonController;
  late Animation<double> _backButtonAnimation;
  bool _showUnownedItems = false; // 添加狀態變數
  String? _selectedStyleItem; // 選中的造型項目
  String? _selectedAvatarItem; // 選中的頭像項目
  String? _selectedEffectItem; // 選中的特效項目
  String? _selectedThemeItem; // 選中的主題桌布項目
  String? _selectedFoodItem; // 選中的飼料項目

  @override
  void initState() {
    super.initState();
    petName = widget.initialPetName;
    _loadPetName();

    // 初始化返回鍵動畫
    _backButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _backButtonAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _backButtonController, curve: Curves.easeInOut),
    );

    // 初始化背包選單動畫
    _backpackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _backpackAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _backpackAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  // 將背包彈窗中的分類名稱對應到商城的標籤名稱
  String _mapToStoreCategory(String category) {
    // 商城使用 '主題桌鋪'，背包這裡顯示 '主題桌布'，需統一
    if (category == '主題桌布') return '主題桌鋪';
    return category;
  }

  /// 載入當前選中的項目狀態
  Future<void> _loadSelectedItems(String category) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();

      if (category == '造型') {
        final selectedStyle = prefs.getString('selected_style_$username');
        setState(() {
          _selectedStyleItem = selectedStyle;
        });
      } else if (category == '頭像') {
        final selectedAvatar = prefs.getString('selected_avatar_$username');
        setState(() {
          _selectedAvatarItem = selectedAvatar;
        });
      } else if (category == '特效') {
        final selectedEffect = prefs.getString('selected_effect_$username');
        setState(() {
          _selectedEffectItem = selectedEffect;
        });
      } else if (category == '主題桌布') {
        final selectedTheme = prefs.getString('selected_theme_$username');
        setState(() {
          _selectedThemeItem = selectedTheme;
        });
      } else if (category == '飼料') {
        final selectedFood = prefs.getString('selected_food_$username');
        setState(() {
          _selectedFoodItem = selectedFood;
        });
      }
    } catch (e) {
      LoggerService.error('Error loading selected items: $e');
    }
  }

  /// 獲取選擇的造型圖片
  Future<String?> _getSelectedStyleImage() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return null;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      final selectedStyleImage = prefs.getString(
        'selected_style_image_$username',
      );

      if (selectedStyleImage != null && selectedStyleImage.isNotEmpty) {
        return selectedStyleImage;
      } else {
        return 'https://i.postimg.cc/vmzwkwzg/image.jpg'; // 造型1圖片作為預設
      }
    } catch (e) {
      LoggerService.error('Error getting selected style image: $e');
      return 'https://i.postimg.cc/vmzwkwzg/image.jpg'; // 造型1圖片作為預設
    }
  }

  Future<void> _loadPetName() async {
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return;

    final username = userData['username'] ?? 'default';
    final prefs = await SharedPreferences.getInstance();
    final aiNameKey = 'ai_name_$username';
    final savedName = prefs.getString(aiNameKey) ?? widget.initialPetName;
    setState(() {
      petName = savedName;
    });
  }

  // 處理桌寵互動
  Future<void> _handlePetInteraction() async {
    if (_isInteracting) return; // 防止重複點擊

    setState(() {
      _isInteracting = true;
    });

    try {
      // 檢查挑戰任務功能是否已解鎖
      final isChallengeUnlocked = await FeatureUnlockService.isFeatureUnlocked(
        '挑戰任務',
      );
      if (isChallengeUnlocked) {
        // 處理桌寵互動任務
        final interactionReward = await ChallengeService.handlePetInteraction();
        if (interactionReward) {
          // 刷新金幣顯示
          _coinDisplayKey.currentState?.refreshCoins();

          // 顯示成功訊息
          if (mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.pets, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('完成每日挑戰，請自挑戰任務領取獎勵')),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      LoggerService.error('Error handling pet interaction: $e');
    } finally {
      setState(() {
        _isInteracting = false;
      });
    }
  }

  @override
  void dispose() {
    _backButtonController.dispose();
    _backpackAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ThemeBackgroundListener(
        overlayColor: Colors.white,
        overlayOpacity: 0.3,
        child: SafeArea(
          child: Column(
            children: [
              // 頂部狀態欄
              _buildStatusBar(),

              // 用戶資料區域
              _buildUserProfileSection(),

              // 中央寵物角色
              Expanded(child: _buildPetCharacter()),

              // 底部背包區域
              _buildBackpackSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 返回鍵
          GestureDetector(
            onTapDown: (_) => _backButtonController.forward(),
            onTapUp: (_) => _backButtonController.reverse(),
            onTapCancel: () => _backButtonController.reverse(),
            onTap: () {
              Navigator.pushNamed(context, '/chat');
            },
            child: ScaleTransition(
              scale: _backButtonAnimation,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_ios,
                  size: 18,
                  color: Colors.blue[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 時間
          Text(
            '10:31',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          const Spacer(),
          // 右側圖標
          Row(
            children: [
              Icon(
                Icons.signal_cellular_4_bar,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Icon(Icons.wifi, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Icon(Icons.battery_full, size: 16, color: Colors.grey[600]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 左側：傑米頭像
          FutureBuilder<String?>(
            future: _getSelectedStyleImage(),
            builder: (context, snapshot) {
              final imageUrl = snapshot.data;
              if (imageUrl != null && imageUrl.isNotEmpty) {
                return ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.pets,
                            color: Colors.white,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                );
              } else {
                return CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue.shade400,
                  child: Icon(Icons.pets, color: Colors.white, size: 24),
                );
              }
            },
          ),
          const SizedBox(width: 12),

          // 中間：用戶名稱和等級
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      petName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 鉛筆編輯按鈕
                    GestureDetector(
                      onTap: () => _showEditNameDialog(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FutureBuilder<Map<String, dynamic>>(
                      future: ExperienceService.getCurrentExperience(),
                      builder: (context, snapshot) {
                        final level = snapshot.hasData
                            ? snapshot.data!['level'] as int
                            : 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Lv.$level',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 經驗條 - 簡化版本
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: ExperienceService.getCurrentExperience(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final progress = snapshot.data!['progress'] as double;
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 右側：金幣顯示
          CoinDisplay(key: _coinDisplayKey),
        ],
      ),
    );
  }

  Widget _buildPetCharacter() {
    return GestureDetector(
      onTap: _handlePetInteraction,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 寵物角色容器
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.lightBlue[50],
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 雲朵形狀背景
                  Positioned(
                    bottom: 20,
                    child: Container(
                      width: 160,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.lightBlue[200],
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  // 寵物角色
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 帽子
                      Container(
                        width: 80,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 臉部
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Stack(
                          children: [
                            // 耳朵
                            Positioned(
                              top: -5,
                              left: -5,
                              child: Container(
                                width: 25,
                                height: 35,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -5,
                              right: -5,
                              child: Container(
                                width: 25,
                                height: 35,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            // 臉部特徵
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 眼睛
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // 臉頰
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.pink[200],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        width: 12,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.pink[200],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // 嘴巴
                                  Container(
                                    width: 20,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.pink[300],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 身體
                      Container(
                        width: 70,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue[400],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Stack(
                          children: [
                            // 綠色包包
                            Positioned(
                              right: -5,
                              top: 5,
                              child: Container(
                                width: 25,
                                height: 35,
                                decoration: BoxDecoration(
                                  color: Colors.green[400],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 互動提示
            if (_isInteracting)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
          ],
        ),
      ),
    );
  }

  // 背包選單相關
  bool _showBackpack = false;
  late AnimationController _backpackAnimationController;
  late Animation<double> _backpackAnimation;

  Widget _buildBackpackSection() {
    return Column(
      children: [
        // 背包標題按鈕
        GestureDetector(
          onTap: () {
            setState(() {
              _showBackpack = !_showBackpack;
            });
            if (_showBackpack) {
              _backpackAnimationController.forward();
            } else {
              _backpackAnimationController.reverse();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.grey.shade50.withValues(alpha: 0.9),
                ],
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.backpack,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '我的背包',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _showBackpack ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 背包選單
        AnimatedBuilder(
          animation: _backpackAnimation,
          builder: (context, child) {
            return SizedBox(
              height: 200 * _backpackAnimation.value,
              child: Opacity(
                opacity: _backpackAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.grey.shade50.withValues(alpha: 0.9),
                      ],
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
                     children: [
                       // 上排三個按鈕
                       Expanded(
                         child: Row(
                           children: [
                             Expanded(
                               child: _buildBackpackCategory('造型', Icons.face, Colors.blue),
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               child: _buildBackpackCategory(
                                 '特效',
                                 Icons.auto_awesome,
                                 Colors.purple,
                               ),
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               child: _buildBackpackCategory(
                                 '飼料',
                                 Icons.restaurant,
                                 Colors.green,
                               ),
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(height: 8),
                       // 下排兩個按鈕
                       Expanded(
                         child: Row(
                           children: [
                             Expanded(
                               child: _buildBackpackCategory(
                                 '頭像',
                                 Icons.account_circle,
                                 Colors.teal,
                               ),
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               child: _buildBackpackCategory(
                                 '主題桌布',
                                 Icons.table_bar,
                                 Colors.indigo,
                               ),
                             ),
                             const SizedBox(width: 8),
                             // 空的 Expanded 來保持對齊
                             const Expanded(child: SizedBox()),
                           ],
                         ),
                       ),
                     ],
                   ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBackpackCategory(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        // 顯示該分類的詳細內容
        _showCategoryDialog(title);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.2),
            ],
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
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryDialog(String category) {
    // 重置狀態
    _showUnownedItems = false;

    // 載入當前選中的項目狀態
    _loadSelectedItems(category);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 標題
                    Row(
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          color: Colors.blue[600],
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 內容區域
                    Expanded(
                      child: _buildCategoryContent(category, setDialogState),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryContent(String category, StateSetter setDialogState) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _showUnownedItems
          ? _getAllItemsByCategory(category)
          : _getOwnedItemsByCategory(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  '載入失敗',
                  style: TextStyle(fontSize: 18, color: Colors.red.shade600),
                ),
              ],
            ),
          );
        }

        final categoryItems = snapshot.data ?? [];

        if (categoryItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getCategoryIcon(category),
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  category == '頭像' 
                      ? '您還沒有獲得任何頭像'
                      : '您還沒有購買任何$category',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  category == '頭像'
                      ? '提升等級來解鎖更多頭像吧！'
                      : '前往商城購買更多$category吧！',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                if (category != '頭像')
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      final storeCategory = _mapToStoreCategory(category);
                      Navigator.pushNamed(
                        context,
                        '/store',
                        arguments: {'category': storeCategory},
                      );
                    },
                    child: const Text('前往商城'),
                  ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // 顯示未擁有商品選項
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Checkbox(
                    value: _showUnownedItems,
                    onChanged: (value) {
                      setDialogState(() {
                        _showUnownedItems = value ?? false;
                      });
                    },
                    activeColor: Colors.blue[600],
                  ),
                  const Text(
                    '顯示未擁有商品',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            // 商品網格
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: categoryItems.length,
                itemBuilder: (context, index) {
                  final item = categoryItems[index];
                  return _buildItemCard(item, category);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, String category) {
    final name = item['name'] ?? '未命名商品';
    final imageUrl = item['圖片'] ?? item['imageUrl'] ?? '';
    final status = item['status'] ?? (category == '頭像' ? '未擁有' : '購買');
    final isOwned = status == '已擁有';
    
    // 調試：打印商品卡片信息
    LoggerService.debug('構建商品卡片: $name, 圖片URL: $imageUrl, 狀態: $status, 是否擁有: $isOwned');

    // 檢查是否為選中的項目
    bool isSelected = false;
    if (category == '造型') {
      isSelected = _selectedStyleItem == name;
    } else if (category == '頭像') {
      isSelected = _selectedAvatarItem == name;
    } else if (category == '特效') {
      isSelected = _selectedEffectItem == name;
    } else if (category == '主題桌布') {
      isSelected = _selectedThemeItem == name;
    } else if (category == '飼料') {
      isSelected = _selectedFoodItem == name;
    }

    return Card(
      elevation: isOwned ? 3 : 1,
      color: isOwned ? Colors.white : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Colors.green.shade600, width: 3)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 圖片區域
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: isOwned ? () => _selectItem(item, category) : null,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    colors: isOwned
                        ? [Colors.blue.shade100, Colors.blue.shade200]
                        : [Colors.grey.shade200, Colors.grey.shade300],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // 圖片
                      imageUrl.isNotEmpty &&
                              imageUrl != '""' &&
                              imageUrl != 'null' &&
                              category != '主題桌布'
                          ? Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              color: isOwned ? null : Colors.grey.shade400,
                              colorBlendMode: isOwned
                                  ? null
                                  : BlendMode.saturation,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
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
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return _buildNoImagePlaceholder();
                              },
                            )
                          : category == '主題桌布'
                          ? _buildThemeBackgroundPlaceholder(item)
                          : _buildNoImagePlaceholder(),
                      // 未擁有標籤
                      if (!isOwned)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '未擁有',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // 選擇標籤（僅對已擁有的造型和頭像顯示）
                      if (isOwned && (category == '造型' || category == '頭像'))
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '點擊選擇',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 名稱區域
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isOwned ? Colors.black87 : Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 4),
          Text(
            '無圖片',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeBackgroundPlaceholder(Map<String, dynamic> item) {
    final imageUrl = item['圖片'] ?? item['imageUrl'] ?? '';
    final name = item['name'] ?? '未命名主題';

    LoggerService.debug('主題桌布圖片 URL: $imageUrl, 名稱: $name');

    if (imageUrl.isNotEmpty && imageUrl != '""') {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          LoggerService.error('主題桌布圖片載入失敗: $error, URL: $imageUrl');
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.blue.shade200],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey.shade400,
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '圖片載入失敗',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade200],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, color: Colors.white, size: 32),
              const SizedBox(height: 4),
              Text('無圖片', style: TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
        ),
      );
    }
  }

  /// 獲取指定類別中狀態為「已擁有」的商品
  Future<List<Map<String, dynamic>>> _getOwnedItemsByCategory(
    String category,
  ) async {
    try {
      // 如果是主題桌布分類，使用主題背景服務
      if (category == '主題桌布') {
        return await _getOwnedThemeBackgrounds();
      }
      
      // 如果是頭像分類，使用統一用戶資料服務
      if (category == '頭像') {
        return await UnifiedUserDataService.getUnlockedAvatars();
      }

      // 使用統一用戶資料服務獲取已擁有的商品
      final ownedItems = await UnifiedUserDataService.getOwnedProductsByCategory(category);
      
      LoggerService.info('獲取到 ${ownedItems.length} 個已擁有的 $category 商品');
      
      // 調試：打印每個商品的詳細信息
      for (final item in ownedItems) {
        LoggerService.info('商品: ${item['name']}, 圖片: ${item['圖片']}, 狀態: ${item['status']}');
      }
      
      return ownedItems;
    } catch (e) {
      LoggerService.error(
        'Error getting owned items for category $category: $e',
      );
      return [];
    }
  }

  /// 獲取已擁有的主題背景
  Future<List<Map<String, dynamic>>> _getOwnedThemeBackgrounds() async {
    try {
      // 從 Firebase 獲取主題桌布數據
      final querySnapshot = await FirebaseFirestore.instance
          .collection('主題桌鋪')
          .get();

      final List<Map<String, dynamic>> ownedThemeItems = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        // 檢查 Firebase 中商品的狀態欄位
        final firebaseStatus = data['狀態'] ?? data['status'] ?? '';
        final isFirebaseOwned = firebaseStatus == '已擁有';

        // 嘗試從多個可能的欄位獲取圖片 URL
        final imageUrl =
            data['圖片'] ??
            data['imageUrl'] ??
            data['image'] ??
            data['url'] ??
            data['img'] ??
            '';

        LoggerService.debug(
          '主題桌布資料 - ID: ${doc.id}, 名稱: ${data['name']}, 狀態: $firebaseStatus, 圖片URL: $imageUrl',
        );

        // 如果 Firebase 狀態為已擁有，則顯示
        if (isFirebaseOwned) {
          ownedThemeItems.add({
            'id': doc.id,
            'name': data['name'] ?? '未命名主題',
            '圖片': imageUrl,
            'imageUrl': imageUrl,
            'category': '主題桌布',
            'status': '已擁有',
            'description': data['description'] ?? '',
            'price': data['price'] ?? data['價格'] ?? 0,
            'isFree': (data['price'] ?? data['價格'] ?? 0) == 0,
          });

          LoggerService.info('已擁有主題桌布: ${data['name']}, 圖片: $imageUrl');
        }
      }

      LoggerService.info('獲取到 ${ownedThemeItems.length} 個已擁有的主題背景');
      return ownedThemeItems;
    } catch (e) {
      LoggerService.error('Error getting owned theme backgrounds: $e');
      return [];
    }
  }

  /// 獲取指定類別中的所有商品（已擁有 + 未擁有）
  Future<List<Map<String, dynamic>>> _getAllItemsByCategory(
    String category,
  ) async {
    try {
      // 如果是主題桌布分類，使用主題背景服務
      if (category == '主題桌布') {
        return await _getAllThemeBackgrounds();
      }
      
      // 如果是頭像分類，使用統一用戶資料服務
      if (category == '頭像') {
        return await UnifiedUserDataService.getAllAvatars();
      }

      // 使用統一用戶資料服務獲取所有商品
      final allItems = await UnifiedUserDataService.getAllProductsByCategory(category);
      
      // 排序：已擁有的商品在前，未擁有的商品在後
      allItems.sort((a, b) {
        final aOwned = a['status'] == '已擁有';
        final bOwned = b['status'] == '已擁有';
        if (aOwned && !bOwned) return -1;
        if (!aOwned && bOwned) return 1;
        return 0;
      });

      return allItems;
    } catch (e) {
      LoggerService.error('Error getting all items for category $category: $e');
      return [];
    }
  }

  /// 獲取所有主題背景
  Future<List<Map<String, dynamic>>> _getAllThemeBackgrounds() async {
    try {
      // 簡化實現：直接從 Firebase 獲取主題桌布數據
      final querySnapshot = await FirebaseFirestore.instance
          .collection('主題桌鋪')
          .get();

      final List<Map<String, dynamic>> themeItems = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // 嘗試從多個可能的欄位獲取圖片 URL
        final imageUrl =
            data['圖片'] ??
            data['imageUrl'] ??
            data['image'] ??
            data['url'] ??
            data['img'] ??
            '';
        final firebaseStatus = data['狀態'] ?? data['status'] ?? '';
        final isFirebaseOwned = firebaseStatus == '已擁有';

        themeItems.add({
          'id': doc.id,
          'name': data['name'] ?? '未命名主題',
          '圖片': imageUrl,
          'imageUrl': imageUrl,
          'category': '主題桌布',
          'status': isFirebaseOwned ? '已擁有' : '未擁有',
          'description': data['description'] ?? '',
          'price': data['price'] ?? data['價格'] ?? 0,
          'isFree': (data['price'] ?? data['價格'] ?? 0) == 0,
        });

        LoggerService.debug(
          '所有主題桌布 - ID: ${doc.id}, 名稱: ${data['name']}, 狀態: $firebaseStatus, 圖片: $imageUrl',
        );
      }

      // 排序：已擁有的商品在前，未擁有的商品在後
      themeItems.sort((a, b) {
        final aOwned = a['status'] == '已擁有';
        final bOwned = b['status'] == '已擁有';
        if (aOwned && !bOwned) return -1;
        if (!aOwned && bOwned) return 1;
        return 0;
      });

      return themeItems;
    } catch (e) {
      LoggerService.error('Error getting all theme backgrounds: $e');
      return [];
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '造型':
        return Icons.face;
      case '特效':
        return Icons.auto_awesome;
      case '飼料':
        return Icons.restaurant;
      case '頭像':
        return Icons.account_circle;
      case '主題桌布':
        return Icons.table_bar;
      default:
        return Icons.category;
    }
  }

  /// 獲取類別的描述文字
  String _getCategoryDescription(String category) {
    switch (category) {
      case '造型':
        return '已設為您的捷米造型';
      case '頭像':
        return '已設為您的頭像';
      case '特效':
        return '已設為您的特效';
      case '主題桌布':
        return '已設為您的主題背景';
      case '飼料':
        return '已設為您的飼料';
      default:
        return '已設為您的$category';
    }
  }

  /// 選擇商品並保存到用戶設置
  Future<void> _selectItem(Map<String, dynamic> item, String category) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();

      final itemName = item['name'] ?? '未命名商品';
      final itemImageUrl = item['圖片'] ?? item['imageUrl'] ?? '';

      if (category == '造型') {
        // 保存選擇的造型
        await prefs.setString('selected_style_$username', itemName);
        await prefs.setString('selected_style_image_$username', itemImageUrl);

        // 更新選中狀態
        setState(() {
          _selectedStyleItem = itemName;
        });

        if (mounted) {
          // 顯示視覺反饋
          _showSelectionFeedback(context, itemName, itemImageUrl, category);
        }
      } else if (category == '頭像') {
        // 保存選擇的頭像
        await prefs.setString('selected_avatar_$username', itemName);
        await prefs.setString('selected_avatar_image_$username', itemImageUrl);

        // 更新選中狀態
        setState(() {
          _selectedAvatarItem = itemName;
        });

        if (mounted) {
          // 顯示視覺反饋
          _showSelectionFeedback(context, itemName, itemImageUrl, category);
        }
      } else if (category == '特效') {
        // 保存選擇的特效
        await prefs.setString('selected_effect_$username', itemName);
        await prefs.setString('selected_effect_image_$username', itemImageUrl);

        // 更新選中狀態
        setState(() {
          _selectedEffectItem = itemName;
        });

        if (mounted) {
          // 顯示視覺反饋
          _showSelectionFeedback(context, itemName, itemImageUrl, category);
        }
      } else if (category == '主題桌布') {
        // 保存選擇的主題背景
        await ThemeBackgroundService.setSelectedTheme(
          item['id'],
          item['圖片'] ?? item['imageUrl'] ?? '',
          item['name'] ?? '未命名主題',
        );

        // 同時保存到本地存儲以顯示選擇狀態
        await prefs.setString('selected_theme_$username', itemName);
        await prefs.setString('selected_theme_image_$username', itemImageUrl);

        // 更新選中狀態
        setState(() {
          _selectedThemeItem = itemName;
        });

        // 立即通知所有頁面更新背景
        ThemeBackgroundNotifier().notifyBackgroundChanged();

        if (mounted) {
          // 顯示視覺反饋
          _showSelectionFeedback(context, itemName, itemImageUrl, category);
        }
      } else if (category == '飼料') {
        // 保存選擇的飼料
        await prefs.setString('selected_food_$username', itemName);
        await prefs.setString('selected_food_image_$username', itemImageUrl);

        // 更新選中狀態
        setState(() {
          _selectedFoodItem = itemName;
        });

        if (mounted) {
          // 顯示視覺反饋
          _showSelectionFeedback(context, itemName, itemImageUrl, category);
        }
      }
    } catch (e) {
      LoggerService.error('Error selecting item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('選擇失敗，請稍後再試'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 顯示選擇反饋
  void _showSelectionFeedback(
    BuildContext context,
    String itemName,
    String itemImageUrl,
    String category,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 成功圖標
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.green.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // 標題
                Text(
                  '選擇成功！',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(height: 8),

                // 商品圖片
                if (itemImageUrl.isNotEmpty)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        itemImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: Icon(
                              _getCategoryIcon(category),
                              color: Colors.grey.shade400,
                              size: 32,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // 商品名稱
                Text(
                  itemName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                // 類別說明
                Text(
                  _getCategoryDescription(category),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // 確認按鈕
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('確定'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 顯示編輯名字對話框
  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(
      text: petName,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text('修改名字'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('請輸入新的名字：', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: '輸入新名字',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue.shade600,
                      width: 2,
                    ),
                  ),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  await _updatePetName(newName);
                  if (mounted) {
                    navigator.pop(newName); // 返回新名字給 chat_page
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  /// 更新寵物名字
  Future<void> _updatePetName(String newName) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();

      // 保存新名字到本地存儲
      await prefs.setString('ai_name_$username', newName);

      // 更新狀態
      setState(() {
        petName = newName;
      });

      // 顯示成功訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('名字已更新為：$newName'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      LoggerService.info('Pet name updated to: $newName');
    } catch (e) {
      LoggerService.error('Error updating pet name: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('更新名字失敗，請稍後再試'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
