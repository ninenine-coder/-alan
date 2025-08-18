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
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                      '$category',
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
                  child: _buildCategoryContent(category),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryContent(String category) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserPurchasedItems(),
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

        final purchasedItems = snapshot.data ?? {};
        final categoryItems = _getCategoryItems(category, purchasedItems);

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
                    Navigator.pushNamed(context, '/store');
                  },
                  child: const Text('前往商城'),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
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
            return _buildItemCard(item);
          },
        );
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = item['name'] ?? '未命名商品';
    final imageUrl = item['圖片'] ?? item['imageUrl'] ?? '';
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 圖片區域
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.blue.shade200],
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: imageUrl.isNotEmpty && imageUrl != '""'
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
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
        final purchasedItemIds = List<String>.from(userData['purchasedItems'] ?? []);
        
        // 獲取所有購買的商品詳細信息
        final Map<String, dynamic> purchasedItems = {};
        
        for (final itemId in purchasedItemIds) {
          // 在各個類別中查找商品
          for (final category in ['造型', '特效', '頭像', '主題桌鋪', '飼料']) {
            try {
              final itemDoc = await FirebaseFirestore.instance
                  .collection(category)
                  .doc(itemId)
                  .get();
              
              if (itemDoc.exists) {
                final itemData = itemDoc.data() as Map<String, dynamic>;
                purchasedItems[itemId] = {
                  ...itemData,
                  'category': category,
                  'id': itemId,
                };
                break; // 找到商品後跳出內層循環
              }
            } catch (e) {
              LoggerService.error('Error fetching item $itemId from category $category: $e');
            }
          }
        }
        
        return purchasedItems;
      }
      
      return null;
    } catch (e) {
      LoggerService.error('Error getting user purchased items: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> _getCategoryItems(String category, Map<String, dynamic> purchasedItems) {
    final List<Map<String, dynamic>> categoryItems = [];
    
    purchasedItems.forEach((itemId, itemData) {
      if (itemData is Map<String, dynamic> && itemData['category'] == category) {
        categoryItems.add(itemData);
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

  void _navigateToCategoryPage(String category) {
    // 這裡可以根據類別導航到對應的頁面
    switch (category) {
      case '造型':
        Navigator.pushNamed(context, '/costume');
        break;
      case '特效':
        Navigator.pushNamed(context, '/effects');
        break;
      case '飼料':
        Navigator.pushNamed(context, '/feed');
        break;
      case '頭像':
        Navigator.pushNamed(context, '/avatar');
        break;
      case '主題桌布':
        Navigator.pushNamed(context, '/theme');
        break;
    }
  }




}
