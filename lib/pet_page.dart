import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'coin_display.dart';
import 'user_service.dart';
import 'challenge_service.dart';
import 'logger_service.dart';
import 'experience_service.dart';

class PetPage extends StatefulWidget {
  final String initialPetName;

  const PetPage({super.key, required this.initialPetName});

  @override
  State<PetPage> createState() => _PetPageState();
}

class _PetPageState extends State<PetPage> with SingleTickerProviderStateMixin {
  late String petName;
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();
  bool _isInteracting = false;
  late AnimationController _backButtonController;
  late Animation<double> _backButtonAnimation;
  bool _showUnownedItems = false; // 添加狀態變數
  String? _selectedStyleItem; // 選中的造型項目
  String? _selectedAvatarItem; // 選中的頭像項目

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
      }
    } catch (e) {
      LoggerService.error('Error loading selected items: $e');
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
                  Expanded(
                    child: Text('完成每日挑戰，請自挑戰任務領取獎勵'),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: Duration(seconds: 3),
            ),
          );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 頂部狀態欄
            _buildStatusBar(),
            
            // 用戶資料區域
            _buildUserProfileSection(),
            
            // 中央寵物角色
            Expanded(
              child: _buildPetCharacter(),
            ),
            
                         // 任務清單區域
             _buildTaskListSection(),
          ],
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
              Icon(Icons.signal_cellular_4_bar, size: 16, color: Colors.grey[600]),
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
          // 左側：用戶頭像
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, color: Colors.grey[600]),
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
                    FutureBuilder<Map<String, dynamic>>(
                      future: ExperienceService.getCurrentExperience(),
                      builder: (context, snapshot) {
                        final level = snapshot.hasData ? snapshot.data!['level'] as int : 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(4),
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
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        width: 12,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.pink[200],
                                          borderRadius: BorderRadius.circular(4),
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

  Widget _buildTaskListSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的背包',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // 第一行：造型、特效、飼料
          Row(
            children: [
              Expanded(child: _buildBackpackItem('造型', Icons.face)),
              const SizedBox(width: 8),
              Expanded(child: _buildBackpackItem('特效', Icons.auto_awesome)),
              const SizedBox(width: 8),
              Expanded(child: _buildBackpackItem('飼料', Icons.restaurant)),
            ],
          ),
          const SizedBox(height: 12),
          // 第二行：頭像、主題桌布
          Row(
            children: [
              Expanded(child: _buildBackpackItem('頭像', Icons.account_circle)),
              const SizedBox(width: 8),
              Expanded(child: _buildBackpackItem('主題桌布', Icons.table_bar)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackpackItem(String title, IconData icon) {
    return GestureDetector(
      onTap: () {
        // 處理背包項目點擊 - 顯示對話框
        _showCategoryDialog(title);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 圖標
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.blue[600],
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            // 標題
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
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
      future: _showUnownedItems ? _getAllItemsByCategory(category) : _getOwnedItemsByCategory(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
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
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.red.shade600,
                  ),
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
                  '您還沒有購買任何$category',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '前往商城購買更多$category吧！',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    final storeCategory = _mapToStoreCategory(category);
                    Navigator.pushNamed(context, '/store', arguments: {
                      'category': storeCategory,
                    });
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
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
    final status = item['status'] ?? '購買';
    final isOwned = status == '已擁有';
    
    // 檢查是否為選中的項目
    bool isSelected = false;
    if (category == '造型') {
      isSelected = _selectedStyleItem == name;
    } else if (category == '頭像') {
      isSelected = _selectedAvatarItem == name;
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    colors: isOwned 
                        ? [Colors.blue.shade100, Colors.blue.shade200]
                        : [Colors.grey.shade200, Colors.grey.shade300],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Stack(
                    children: [
                      // 圖片
                      imageUrl.isNotEmpty && imageUrl != '""'
                          ? Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              color: isOwned ? null : Colors.grey.shade400,
                              colorBlendMode: isOwned ? null : BlendMode.saturation,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          Icon(Icons.image_not_supported_outlined, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text(
            '無圖片',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getUserPurchasedItems() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return null;

      final username = userData['username'] ?? 'default';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(username)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        // 直接使用 purchasedItemsWithCategory 數據
        final purchasedItemsWithCategory = Map<String, dynamic>.from(userData['purchasedItemsWithCategory'] ?? {});
        
        return purchasedItemsWithCategory;
      }
      
      return null;
    } catch (e) {
      LoggerService.error('Error getting user purchased items: $e');
      return null;
    }
  }

  /// 獲取指定類別中狀態為「已擁有」的商品
  Future<List<Map<String, dynamic>>> _getOwnedItemsByCategory(String category) async {
    try {
      // 映射類別名稱
      final storeCategory = _mapToStoreCategory(category);
      
      // 從 Firebase 讀取該類別的所有商品
      final querySnapshot = await FirebaseFirestore.instance
          .collection(storeCategory)
          .get();
      
      final List<Map<String, dynamic>> ownedItems = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['狀態'] ?? data['status'] ?? '購買';
        
        // 如果商品狀態為「已擁有」，則添加到列表中
        if (status == '已擁有') {
          ownedItems.add({
            'id': doc.id,
            'name': data['name'] ?? '未命名商品',
            '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
            'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
            'category': category,
            'status': status,
          });
        }
      }
      
      return ownedItems;
    } catch (e) {
      LoggerService.error('Error getting owned items for category $category: $e');
      return [];
    }
  }

  /// 獲取指定類別中的所有商品（已擁有 + 未擁有）
  Future<List<Map<String, dynamic>>> _getAllItemsByCategory(String category) async {
    try {
      // 映射類別名稱
      final storeCategory = _mapToStoreCategory(category);
      
      // 從 Firebase 讀取該類別的所有商品
      final querySnapshot = await FirebaseFirestore.instance
          .collection(storeCategory)
          .get();
      
      final List<Map<String, dynamic>> allItems = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['狀態'] ?? data['status'] ?? '購買';
        
        allItems.add({
          'id': doc.id,
          'name': data['name'] ?? '未命名商品',
          '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
          'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
          'category': category,
          'status': status,
        });
      }
      
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

  List<Map<String, dynamic>> _getCategoryItems(String category, Map<String, dynamic> purchasedItemsWithCategory) {
    final List<Map<String, dynamic>> categoryItems = [];
    
    purchasedItemsWithCategory.forEach((itemId, itemData) {
      if (itemData is Map<String, dynamic>) {
        final itemCategory = itemData['category'] as String?;
        // 處理類別名稱對應
        if (itemCategory == category || 
            (category == '主題桌布' && itemCategory == '主題桌鋪') ||
            (category == '主題桌鋪' && itemCategory == '主題桌布')) {
          categoryItems.add(itemData);
        }
      }
    });
    
    return categoryItems;
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
  void _showSelectionFeedback(BuildContext context, String itemName, String itemImageUrl, String category) {
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
                              category == '造型' ? Icons.face : Icons.account_circle,
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
                  '已設為您的${category == '造型' ? '捷米造型' : '頭像'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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






}
