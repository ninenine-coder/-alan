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
import 'avatar_service.dart';
import 'asset_video_player.dart';
import 'effect_thumbnail.dart';
import 'food_service.dart';
import 'food_feeding_service.dart';
import 'food_initialization_service.dart';
import 'purchase_count_service.dart';
import 'user_purchase_service.dart';

class PetPage extends StatefulWidget {
  final String initialPetName;

  const PetPage({super.key, required this.initialPetName});

  @override
  State<PetPage> createState() => _PetPageState();
}

class _PetPageState extends State<PetPage> with TickerProviderStateMixin, WidgetsBindingObserver {
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
  
  // 餵食動畫相關狀態變量
  bool _isFeeding = false;
  String? _feedingFoodId;
  String? _feedingFoodName;
  String? _feedingFoodImageUrl;
   
  // 頭像相關狀態變量
  String? _selectedAvatarNoBgUrl; // 選中的無背景頭像URL
  List<Map<String, dynamic>> _avatars = []; // 頭像列表
  bool _loadingAvatars = false; // 頭像載入狀態
  DocumentSnapshot? _lastAvatarDoc; // 頭像分頁游標
  bool _hasMoreAvatars = true; // 是否還有更多頭像
  
  // 頭像服務監聽器
  late AvatarService _avatarService;

  @override
  void initState() {
    super.initState();
    
    // 註冊生命週期監聽器
    WidgetsBinding.instance.addObserver(this);
    
    petName = widget.initialPetName;
    _loadPetName();

    // 初始化頭像服務監聽器
    _avatarService = AvatarService();
    _avatarService.addListener(_onAvatarDataChanged);

    // 初始化動畫控制器
    _backButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _backButtonAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _backButtonController,
      curve: Curves.easeInOut,
    ));

    // 初始化背包動畫控制器
    _backpackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _backpackAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
        parent: _backpackAnimationController,
        curve: Curves.easeInOut,
    ));

    // 載入頭像列表和已選擇的頭像
    _loadAvatars();
    _loadSelectedAvatar();
    // 初始化飼料庫存
    _initializeFoodInventory();
    // 初始化購買計數
    _initializePurchaseCounts();
    
    // 初始化飼料庫存
    _initializeFoodInventory();
    
    // 載入已選擇的特效 - 確保特效在頁面載入時立即顯示
    _loadSelectedEffect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 當應用重新獲得焦點時，重新載入特效
    if (state == AppLifecycleState.resumed) {
      LoggerService.info('應用重新獲得焦點，重新載入特效');
      _loadSelectedEffect();
    }
  }

  @override
  void dispose() {
    // 移除生命週期監聽器
    WidgetsBinding.instance.removeObserver(this);
    
    // 移除頭像服務監聽器
    _avatarService.removeListener(_onAvatarDataChanged);
    
    // 釋放動畫控制器
    _backButtonController.dispose();
    _backpackAnimationController.dispose();
    
    super.dispose();
  }

  /// 載入頭像列表
  Future<void> _loadAvatars({int limit = 10}) async {
    if (!_hasMoreAvatars || _loadingAvatars) return;

    setState(() {
      _loadingAvatars = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('avatars')
          .orderBy('avatar_name')
          .limit(limit);

      if (_lastAvatarDoc != null) {
        query = query.startAfterDocument(_lastAvatarDoc!);
      }

      QuerySnapshot snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        _hasMoreAvatars = false;
      } else {
        _lastAvatarDoc = snapshot.docs.last;
        
        final newAvatars = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        
        setState(() {
          _avatars.addAll(newAvatars);
        });
      }
    } catch (e) {
      LoggerService.error('載入頭像失敗: $e');
    } finally {
      setState(() {
        _loadingAvatars = false;
      });
    }
  }

  /// 選擇頭像
  void _selectAvatar(String avatarNoBgUrl) {
    setState(() {
      _selectedAvatarNoBgUrl = avatarNoBgUrl;
    });
    
    // 保存選擇的頭像到本地存儲
    _saveSelectedAvatar(avatarNoBgUrl);
  }

  /// 選擇頭像項目（用於背包中的頭像卡片）
  void _selectAvatarItem(Map<String, dynamic> avatarItem) async {
    await _selectItem(avatarItem, '頭像');
  }

  /// 保存選擇的頭像
  Future<void> _saveSelectedAvatar(String avatarNoBgUrl) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;
      
      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_avatar_no_bg_$username', avatarNoBgUrl);
      
      LoggerService.info('頭像已保存: $avatarNoBgUrl');
    } catch (e) {
      LoggerService.error('保存頭像失敗: $e');
    }
  }

  /// 載入已選擇的頭像
  Future<void> _loadSelectedAvatar() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;
      
      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      final selectedAvatar = prefs.getString('selected_avatar_no_bg_$username');
      
      // 添加調試日誌
      LoggerService.info('載入已選擇頭像 - 用戶: $username, 選擇的頭像URL: $selectedAvatar');
      
      // 檢查用戶的頭像狀態
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userData['uid'])
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final avatars = Map<String, bool>.from(userData['avatars'] ?? {});
        LoggerService.info('用戶頭像狀態: $avatars');
        
        // 獲取當前等級
        final experienceData = await ExperienceService.getCurrentExperience();
        final currentLevel = experienceData['level'] as int;
        LoggerService.info('當前用戶等級: $currentLevel');
        
        // 檢查每個頭像的解鎖狀態
        for (final entry in avatars.entries) {
          final avatarId = entry.key;
          final isUnlocked = entry.value;
          LoggerService.info('頭像 $avatarId: 是否解鎖=$isUnlocked');
        }
      }
      
      if (selectedAvatar != null) {
        setState(() {
          _selectedAvatarNoBgUrl = selectedAvatar;
        });
      }
    } catch (e) {
      LoggerService.error('載入已選擇頭像失敗: $e');
    }
  }

  /// 載入已選擇的特效
  Future<void> _loadSelectedEffect() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) {
        LoggerService.warning('無法獲取用戶數據，跳過特效載入');
        return;
      }

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      final selectedEffect = prefs.getString('selected_effect_$username');
      
      LoggerService.info('載入特效選擇 - 用戶: $username, 已選擇特效: $selectedEffect');
      
      if (selectedEffect != null && selectedEffect.isNotEmpty) {
        setState(() {
          _selectedEffectItem = selectedEffect;
        });
        LoggerService.info('已載入選擇的特效: $selectedEffect');
      } else {
        // 初次登入時不設置預設特效，保持為空
        LoggerService.info('初次登入，不設置預設特效，特效區域保持為空');
        setState(() {
          _selectedEffectItem = null;
        });
      }
    } catch (e) {
      LoggerService.error('載入選擇的特效失敗: $e');
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ThemeBackgroundListener(
        overlayColor: Colors.white,
        overlayOpacity: 0.3,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
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
              // 頭像覆蓋層 - 與背包選單完全縫合
              if (_selectedAvatarNoBgUrl != null)
                Positioned(
                  right: 0, // 貼齊右邊
                  bottom: _showBackpack ? 200 : 0, // 根據背包選單狀態調整位置
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 120,
                    height: 200,
                    child: Image.network(
                      _selectedAvatarNoBgUrl!,
                      fit: BoxFit.contain,
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
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                    ),
                  ),
                ),
              // 餵食動畫覆蓋層
              if (_isFeeding && _feedingFoodImageUrl != null)
                Positioned(
                  right: 60, // 從頭像位置開始
                  bottom: _showBackpack ? 260 : 60, // 根據背包選單狀態調整位置
                  child: FoodFeedingAnimation(
                    foodImageUrl: _feedingFoodImageUrl!,
                    foodName: _feedingFoodName ?? '飼料',
                    onAnimationComplete: _onFeedingAnimationComplete,
                  ),
                ),
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
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          
          // 特效影片顯示區域 - 始終顯示這個區域
          _buildEffectVideoSection(),
          
          const SizedBox(height: 20),
          // 互動提示
          if (_isInteracting)
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ],
              ),
    );
  }

  /// 構建特效影片顯示區域
  Widget _buildEffectVideoSection() {
    LoggerService.info('構建特效影片區域 - 當前選擇特效: $_selectedEffectItem');
    
    // 如果沒有選擇特效，返回空容器
    if (_selectedEffectItem == null || _selectedEffectItem!.isEmpty) {
      LoggerService.warning('沒有選擇特效，返回空容器');
      return const SizedBox.shrink();
    }

    // 根據選擇的特效名稱獲取影片路徑
    final videoPath = _getEffectVideoPath(_selectedEffectItem!);
    LoggerService.info('特效影片路徑: $videoPath');
    
    return Container(
      width: double.infinity,
      height: 300, // 增加高度
      padding: const EdgeInsets.symmetric(horizontal: 10), // 減少水平邊距
      margin: const EdgeInsets.only(bottom: 10), // 減少底部邊距
      child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                              child: Container(
              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
              // 特效影片
              GestureDetector(
                onTap: _handlePetInteraction,
                child: AssetVideoPlayer(
                  key: ValueKey(videoPath), // 添加key，確保路徑改變時重建widget
                  assetPath: videoPath,
                  autoPlay: true,
                  showControls: false, // 移除控制按鈕
                ),
              ),
              
              // 飼料數量顯示 - 左下角
              Positioned(
                left: 16,
                bottom: 16,
                child: StreamBuilder<Map<String, int>>(
                  stream: FoodService.getUserFoodInventoryStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final totalFood = snapshot.data!.values.fold<int>(0, (sum, amount) => sum + amount);
                      if (totalFood > 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                          children: [
                              Icon(
                                Icons.restaurant,
                                  color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'x$totalFood',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                        );
                      }
                    }
                    return const SizedBox.shrink();
                  },
                                        ),
                                      ),
                                    ],
                                  ),
        ),
      ),
    );
  }

  /// 獲取選擇的特效影片路徑
  Future<String?> _getSelectedEffectVideoPath() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return null;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      final selectedEffectVideo = prefs.getString('selected_effect_video_$username');
      
      return selectedEffectVideo;
    } catch (e) {
      LoggerService.error('Error getting selected effect video path: $e');
      return null;
    }
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                          Expanded(
                            child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 內容區域
                      Flexible(
                      child: _buildCategoryContent(category, setDialogState),
                    ),
                  ],
                  ),
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
            // 顯示未擁有商品選項（頭像和飼料類別不顯示此選項）
            if (category != '頭像' && category != '飼料')
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
    
    // 調試：打印卡片構建信息
    LoggerService.debug('構建卡片 - 類別: $category, 商品: $name, 圖片URL: "$imageUrl"');

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

    // 對於飼料，使用StreamBuilder來動態顯示數量
    if (category == '飼料') {
      return StreamBuilder<Map<String, int>>(
        stream: FoodService.getUserFoodInventoryStream(),
        builder: (context, snapshot) {
          final foodId = item['id'] ?? '';
          final foodAmount = snapshot.hasData ? snapshot.data![foodId] ?? 0 : 0;
          
          return Card(
            elevation: 3, // 飼料卡片始終有陰影
            color: Colors.white, // 飼料卡片始終為白色
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
                    onTap: foodAmount > 0 ? () => _feedFood(item) : null, // 只有數量大於0才能餵食
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade100, Colors.blue.shade200], // 飼料卡片始終為藍色
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            // 圖片 - 飼料圖片顯示邏輯
                            Builder(
                              builder: (context) {
                                // 調試：打印飼料圖片信息
                                LoggerService.debug('飼料圖片顯示 - 商品: ${item['name']}, 圖片URL: "$imageUrl"');
                                LoggerService.debug('飼料圖片顯示 - URL長度: ${imageUrl.length}, 是否為空: ${imageUrl.isEmpty}');
                                LoggerService.debug('飼料圖片顯示 - URL是否為""字符串: ${imageUrl == '""'}');
                                LoggerService.debug('飼料圖片顯示 - URL是否為null字符串: ${imageUrl == 'null'}');
                                LoggerService.debug('飼料圖片顯示 - URL是否以http開頭: ${imageUrl.startsWith('http://')}');
                                LoggerService.debug('飼料圖片顯示 - URL是否以https開頭: ${imageUrl.startsWith('https://')}');
                                
                                // 檢查圖片URL是否有效
                                bool isValidUrl = imageUrl.isNotEmpty && 
                                    imageUrl != '""' && 
                                    imageUrl != 'null' &&
                                    (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));
                                
                                LoggerService.debug('飼料圖片顯示 - URL是否有效: $isValidUrl');
                                
                                if (isValidUrl) {
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
                                      LoggerService.error('飼料圖片載入失敗: $error, URL: $imageUrl');
                                      return _buildNoImagePlaceholder();
                                    },
                                  );
                                } else {
                                  LoggerService.warning('飼料圖片URL無效，顯示預設圖片: $imageUrl');
                                  return _buildNoImagePlaceholder();
                                }
                              },
                            ),

                            // 飼料餵食標籤 - 只有數量大於0時顯示
                            if (foodAmount > 0)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '點擊餵食',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            // 飼料數量顯示 - 始終顯示，包括0
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.restaurant,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'x$foodAmount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87, // 飼料名稱始終為黑色
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
        },
      );
    } else {
      // 非飼料類別的原有邏輯
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
                        // 圖片或影片
                      imageUrl.isNotEmpty &&
                              imageUrl != '""' &&
                                imageUrl != 'null'
                            ? category == '特效'
                                ? _buildEffectVideoWidget(item, isOwned)
                                : category == '頭像'
                                    ? Image.network(
                                        imageUrl,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.contain,
                                        color: isOwned ? null : Colors.grey.shade400,
                                        colorBlendMode: isOwned
                                            ? null
                                            : BlendMode.saturation,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
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
                                                  value: loadingProgress
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
                                        : Image.network(
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
                                                  value: loadingProgress
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
                        // 購買量顯示
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: StreamBuilder<Map<String, int>>(
                            stream: UserPurchaseService.getUserPurchaseCountsStream(),
                            builder: (context, snapshot) {
                              final itemId = item['id'] ?? '';
                              final purchaseCount = snapshot.hasData ? snapshot.data![itemId] ?? 0 : 0;
                              
                              // 添加調試日誌
                              LoggerService.info('StreamBuilder 更新 - 商品ID: $itemId, 商品名稱: ${item['name']}, 購買數量: $purchaseCount, 有數據: ${snapshot.hasData}, 錯誤: ${snapshot.hasError}');
                              if (snapshot.hasData) {
                                LoggerService.info('商品 $itemId 的購買數量: $purchaseCount, 完整數據: ${snapshot.data}');
                              }
                              
                              if (purchaseCount == 0) return const SizedBox.shrink();
                              
                              return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shopping_cart,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$purchaseCount',
                                      style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                                  ],
                                ),
                              );
                            },
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
      // 如果是主題桌布分類，使用統一用戶資料服務
      if (category == '主題桌布') {
        LoggerService.info('正在獲取主題桌布類別的已擁有商品...');
        final ownedItems = await UnifiedUserDataService.getOwnedProductsByCategory('主題桌鋪');
        
        LoggerService.info('獲取到 ${ownedItems.length} 個已擁有的主題桌布商品');
        
        // 調試：打印每個商品的詳細信息
        for (final item in ownedItems) {
          LoggerService.info('主題桌布商品: ${item['name']} (ID: ${item['id']}), 圖片: ${item['圖片']}, 狀態: ${item['status']}');
        }
        
        return ownedItems;
      }
      
      // 如果是頭像分類，使用專門的頭像獲取方法
      if (category == '頭像') {
        return await _getAllAvatars();
      }

      // 如果是飼料分類，顯示所有飼料（不管是否擁有）
      if (category == '飼料') {
        LoggerService.info('正在獲取飼料類別的所有商品...');
        final allItems = await _getAllItemsByCategory('飼料');
        LoggerService.info('獲取到 ${allItems.length} 個飼料商品');
        return allItems;
      }

      // 使用統一用戶資料服務獲取已擁有的商品
      LoggerService.info('正在獲取 $category 類別的已擁有商品...');
      final ownedItems = await UnifiedUserDataService.getOwnedProductsByCategory(category);
      
      LoggerService.info('獲取到 ${ownedItems.length} 個已擁有的 $category 商品');
      
      // 調試：打印每個商品的詳細信息
      for (final item in ownedItems) {
        LoggerService.info('商品: ${item['name']} (ID: ${item['id']}), 圖片: ${item['圖片']}, 狀態: ${item['status']}');
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
      // 如果是主題桌布分類，使用本地方法直接從 Firebase 獲取
      if (category == '主題桌布') {
        LoggerService.info('正在獲取主題桌布類別的所有商品...');
        final allItems = await _getAllThemeBackgrounds();
        LoggerService.info('獲取到 ${allItems.length} 個主題桌布商品');
        return allItems;
      }
      
      // 如果是頭像分類，使用統一用戶資料服務
      if (category == '頭像') {
        return await UnifiedUserDataService.getAllAvatars();
      }

      // 如果是飼料類別，直接從飼料集合獲取
      if (category == '飼料') {
        LoggerService.info('正在從 Firebase 獲取飼料資料...');
        
        QuerySnapshot querySnapshot;
        try {
          // 直接從飼料集合獲取資料
          LoggerService.info('正在獲取飼料集合資料...');
          querySnapshot = await FirebaseFirestore.instance
              .collection('飼料')
              .get();
          
          LoggerService.info('總共獲取到 ${querySnapshot.docs.length} 個飼料商品');
          
          // 打印所有飼料的數據信息，幫助調試
          for (final doc in querySnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              final name = data['name'] ?? data['名稱'] ?? '未命名';
              final imageUrl = data['圖片'] ?? data['imageUrl'] ?? data['image'] ?? '';
              LoggerService.info('飼料: $name, 圖片URL: $imageUrl');
              LoggerService.info('飼料完整數據: $data');
            }
          }
        } catch (e) {
          LoggerService.error('查詢飼料資料失敗: $e');
          // 創建一個空的查詢結果
          querySnapshot = await FirebaseFirestore.instance
              .collection('飼料')
              .limit(0)
              .get();
        }

        final List<Map<String, dynamic>> foodItems = [];
        for (final doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          
          // 調試：打印飼料數據信息
          final imageUrl = data['圖片'] ?? data['imageUrl'] ?? data['image'] ?? '';
          LoggerService.info('找到飼料: ${data['name'] ?? data['名稱']} (ID: ${doc.id})');
          LoggerService.info('飼料圖片URL: $imageUrl');
          LoggerService.info('飼料完整數據: $data');
          
          foodItems.add({
            'id': doc.id,
            'name': data['name'] ?? data['名稱'] ?? '未命名飼料',
            '圖片': imageUrl,
            'imageUrl': imageUrl,
            'category': '飼料',
            'status': '未擁有', // 飼料的擁有狀態由 StreamBuilder 動態判斷
            'description': data['description'] ?? data['描述'] ?? '',
            'price': data['price'] ?? data['價格'] ?? 0,
          });
        }
        
        LoggerService.info('總共找到 ${foodItems.length} 個飼料商品');
        
        // 按名稱排序
        foodItems.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        return foodItems;
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
        
        // 保存無背景頭像URL
        final avatarNoBgUrl = item['avatar_no_bg'] ?? item['無背景'] ?? '';
        if (avatarNoBgUrl.isNotEmpty) {
          await prefs.setString('selected_avatar_no_bg_$username', avatarNoBgUrl);
          LoggerService.info('保存無背景頭像URL: $avatarNoBgUrl');
        }

        // 更新選中狀態
        setState(() {
          _selectedAvatarItem = itemName;
          _selectedAvatarNoBgUrl = avatarNoBgUrl.isNotEmpty ? avatarNoBgUrl : null;
        });

        if (mounted) {
          // 顯示視覺反饋
          _showSelectionFeedback(context, itemName, itemImageUrl, category);
        }
      } else if (category == '特效') {
        // 保存選擇的特效
        await prefs.setString('selected_effect_$username', itemName);
        final videoPath = _getEffectVideoPath(itemName);
        await prefs.setString('selected_effect_video_$username', videoPath);

        // 更新選中狀態
        setState(() {
          _selectedEffectItem = itemName;
        });

        if (mounted) {
          // 顯示視覺反饋
          _showSelectionFeedback(context, itemName, videoPath, category);
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
        // 開始餵食動畫
        final foodId = item['id'] ?? '';
        final foodName = item['name'] ?? '未命名飼料';
        final foodImageUrl = item['圖片'] ?? item['imageUrl'] ?? '';
        
        // 檢查是否有足夠的飼料
        final hasEnough = await FoodService.hasEnoughFood(foodId, 1);
        if (!hasEnough) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('飼料數量不足'),
                backgroundColor: Colors.red.shade600,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
        
        // 開始餵食動畫
        setState(() {
          _isFeeding = true;
          _feedingFoodId = foodId;
          _feedingFoodName = foodName;
          _feedingFoodImageUrl = foodImageUrl;
        });
        
        // 關閉選擇對話框
        Navigator.of(context).pop();
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
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

                // 商品圖片或影片
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
                      child: category == '特效'
                          ? _buildEffectPreviewWidget(itemName)
                          : Image.network(
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
  
  /// 餵食飼料
  void _feedFood(Map<String, dynamic> item) async {
    final foodId = item['id'] ?? '';
    final foodName = item['name'] ?? '未命名飼料';
    final foodImageUrl = item['圖片'] ?? item['imageUrl'] ?? '';
    
    // 檢查是否有足夠的飼料
    final hasEnough = await FoodService.hasEnoughFood(foodId, 1);
    if (!hasEnough) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('飼料數量不足'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    // 開始餵食動畫
    setState(() {
      _isFeeding = true;
      _feedingFoodId = foodId;
      _feedingFoodName = foodName;
      _feedingFoodImageUrl = foodImageUrl;
    });
    
    // 關閉選擇對話框
    Navigator.of(context).pop();
  }

  /// 餵食動畫完成回調
  void _onFeedingAnimationComplete() async {
    if (_feedingFoodId != null && _feedingFoodName != null && _feedingFoodImageUrl != null) {
      // 執行餵食邏輯
      final success = await FoodFeedingService.feedFood(
        _feedingFoodId!,
        _feedingFoodName!,
        _feedingFoodImageUrl!,
      );
      
      if (success) {
        // 顯示餵食成功訊息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.pets, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('餵食成功！${_feedingFoodName}'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 顯示餵食失敗訊息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('餵食失敗，請稍後再試'),
              backgroundColor: Colors.red.shade600,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
    
    // 重置餵食狀態
    setState(() {
      _isFeeding = false;
      _feedingFoodId = null;
      _feedingFoodName = null;
      _feedingFoodImageUrl = null;
    });
  }
  
  /// 頭像數據變化回調
  void _onAvatarDataChanged() {
    if (mounted) {
      setState(() {
        // 強制重建UI以顯示新的頭像
        LoggerService.info('頭像數據已更新，重建UI');
      });
    }
  }

  /// 根據特效名稱獲取影片路徑
  String _getEffectVideoPath(String effectName) {
    // 根據 Firebase name 欄位映射到對應的影片檔案
    switch (effectName) {
      case '夜市生活':
        return 'assets/MRTvedio/night.mp4';
      case 'B-Boy':
        return 'assets/MRTvedio/boy.mp4';
      case '文青少年':
        return 'assets/MRTvedio/ccc.mp4';
      case '來去泡溫泉':
        return 'assets/MRTvedio/hotspring.mp4';
      case '登山客':
        return 'assets/MRTvedio/mt.mp4';
      case '淡水夕陽':
        return 'assets/MRTvedio/sun.mp4';
      case '跑酷少年':
        return 'assets/MRTvedio/run.mp4';
      case '校外教學':
        return 'assets/MRTvedio/zoo.mp4';
      case '出門踏青':
        return 'assets/MRTvedio/walk.mp4';
      case '下雨天':
        return 'assets/MRTvedio/rain.mp4';
      case '買米買菜買冬瓜':
        return 'assets/MRTvedio/abc.mp4';
      case '藍色狂想':
        return 'assets/MRTvedio/blue.mp4';
      case '文青少年':
        return 'assets/MRTvedio/ccc.mp4';
      default:
        // 如果沒有對應的映射，返回空字串或預設影片
        LoggerService.warning('未找到特效 $effectName 的影片映射，使用預設影片');
        return 'assets/MRTvedio/night.mp4'; // 使用預設影片
    }
  }

  /// 構建特效影片組件
  Widget _buildEffectVideoWidget(Map<String, dynamic> item, bool isOwned) {
    final effectName = item['name'] ?? '特效1';
    
    // 根據特效名稱構建影片路徑
    final videoPath = _getEffectVideoPath(effectName);
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isOwned ? Colors.blue.shade50 : Colors.grey.shade300,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
        ),
      ),
      child: Stack(
        children: [
          // 使用 CachedEffectThumbnail 顯示影片封面
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: CachedEffectThumbnail(
              videoPath: videoPath,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          
          // 播放按鈕覆蓋層
          if (isOwned)
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          
          // 如果未擁有，添加灰色遮罩
          if (!isOwned)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade400.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock,
                      size: 32,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '未擁有',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 構建特效預覽組件
  Widget _buildEffectPreviewWidget(String effectName) {
    return Container(
      color: Colors.blue.shade50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library,
              size: 32,
              color: Colors.blue.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              effectName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '特效影片',
              style: TextStyle(
                fontSize: 8,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 初始化飼料庫存
  Future<void> _initializeFoodInventory() async {
    try {
      await FoodInitializationService.ensureFoodInventoryInitialized();
      LoggerService.info('飼料庫存初始化完成');
    } catch (e) {
      LoggerService.error('飼料庫存初始化失敗: $e');
    }
  }

  /// 初始化購買計數
  Future<void> _initializePurchaseCounts() async {
    try {
      await PurchaseCountService.initializePurchaseCounts();
      LoggerService.info('購買計數初始化完成');
    } catch (e) {
      LoggerService.error('購買計數初始化失敗: $e');
    }
  }

  /// 獲取所有頭像
  Future<List<Map<String, dynamic>>> _getAllAvatars() async {
    try {
      // 使用統一用戶資料服務獲取已解鎖的頭像
      final unlockedAvatars = await UnifiedUserDataService.getUnlockedAvatars();
      
      final List<Map<String, dynamic>> avatarItems = [];

      for (final avatar in unlockedAvatars) {
        final avatarId = avatar['id'] ?? '';
        final avatarName = avatar['name'] ?? '未命名頭像';
        final imageUrl = avatar['imageUrl'] ?? avatar['圖片'] ?? '';
        final avatarNoBgUrl = avatar['avatar_no_bg'] ?? avatar['無背景'] ?? '';

        avatarItems.add({
          'id': avatarId,
          'name': avatarName,
          '圖片': imageUrl,
          'imageUrl': imageUrl,
          'avatar_no_bg': avatarNoBgUrl,
          'category': '頭像',
          'status': '已擁有', // 頭像都是已擁有的
          'description': avatar['description'] ?? '',
          'price': 0, // 頭像不需要價格
          'isFree': true, // 頭像都是免費的
        });

        LoggerService.debug(
          '已解鎖頭像資料 - ID: $avatarId, 名稱: $avatarName, 圖片: $imageUrl, 無背景: $avatarNoBgUrl',
        );
      }

      // 排序：按名稱排序
      avatarItems.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      LoggerService.info('獲取到 ${avatarItems.length} 個已擁有的頭像');
      return avatarItems;
    } catch (e) {
      LoggerService.error('獲取頭像失敗: $e');
      return [];
    }
  }
}

/// 頭像選擇器組件
class AvatarSelector extends StatefulWidget {
  final Function(String) onSelectNoBg;
  final List<Map<String, dynamic>> avatars;
  final bool loading;
  final VoidCallback onLoadMore;
  
  const AvatarSelector({
    required this.onSelectNoBg,
    required this.avatars,
    required this.loading,
    required this.onLoadMore,
    super.key,
  });

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      child: Column(
        children: [
          // 標題
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.account_circle, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  '選擇頭像',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          
          // 頭像列表
          Expanded(
            child: widget.avatars.isEmpty && !widget.loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暫無頭像',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.avatars.length + (widget.loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == widget.avatars.length) {
                        // 載入更多指示器
                        return Container(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                            ),
                          ),
                        );
                      }

                      final avatar = widget.avatars[index];
                      final avatarNoBgUrl = avatar['avatar_no_bg'] ?? '';
                      final avatarWithBgUrl = avatar['avatar_with_bg'] ?? '';
                      final avatarName = avatar['avatar_name'] ?? '未命名頭像';

                      return GestureDetector(
                        onTap: () {
                          if (avatarNoBgUrl.isNotEmpty) {
                            widget.onSelectNoBg(avatarNoBgUrl);
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // 頭像圖片
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: Image.network(
                                    avatarWithBgUrl.isNotEmpty 
                                        ? avatarWithBgUrl 
                                        : avatarNoBgUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          size: 30,
                                          color: Colors.grey.shade600,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // 頭像名稱
                              Expanded(
                                child: Text(
                                  avatarName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              
                              // 選擇指示器
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
