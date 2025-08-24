import 'package:flutter/material.dart';
import 'coin_service.dart';
import 'coin_display.dart';
import 'user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';
import 'theme_background_service.dart';
import 'theme_background_widget.dart';
import 'unified_user_data_service.dart';
import 'effect_thumbnail_widget.dart';
import 'asset_video_player.dart';
import 'food_service.dart';
import 'purchase_count_service.dart';
import 'user_purchase_service.dart';

class StorePage extends StatefulWidget {
  final String? initialCategory;

  const StorePage({super.key, this.initialCategory});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with TickerProviderStateMixin {
  // 常量定義
  static const double _cardImageHeight = 110.0;
  static const double _buttonHeight = 32.0;
  static const double _cardBorderRadius = 12.0;
  static const double _buttonBorderRadius = 8.0;
  static const double _gridChildAspectRatio = 0.75;

  late TabController _tabController;
  final GlobalKey<CoinDisplayState> _coinDisplayKey =
      GlobalKey<CoinDisplayState>();

  final List<String> categories = ['造型', '特效', '主題桌鋪', '飼料'];

  final Map<String, IconData> categoryIcons = {
    '造型': Icons.face,
    '特效': Icons.auto_awesome,
    '主題桌鋪': Icons.table_bar,
    '飼料': Icons.restaurant,
  };

  Map<String, dynamic>? _currentUser;
  final Map<String, bool> purchasedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);

    // 設置初始類別
    if (widget.initialCategory != null) {
      final index = categories.indexOf(widget.initialCategory!);
      if (index >= 0) {
        _tabController.index = index;
      }
    }

    _loadUserData();
    _testFirebaseConnection();
  }

  Future<void> _loadUserData() async {
    _currentUser = await UserService.getCurrentUserData();
    await _loadPurchasedItems();
    setState(() {});
  }

  Future<void> _testFirebaseConnection() async {
    try {
      await _testThemeBackgroundData();
    } catch (e) {
      LoggerService.error('Firebase 連接測試失敗: $e');
    }
  }

  /// 測試主題桌鋪數據
  Future<void> _testThemeBackgroundData() async {
    try {
      LoggerService.info('開始測試主題桌鋪數據...');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('主題桌鋪')
          .get();

      LoggerService.info('主題桌鋪集合文檔數量: ${querySnapshot.docs.length}');

      for (int i = 0; i < querySnapshot.docs.length; i++) {
        final doc = querySnapshot.docs[i];
        final data = doc.data();
        LoggerService.info('主題桌鋪文檔 $i (ID: ${doc.id}):');
        LoggerService.info('  完整數據: $data');
        LoggerService.info('  名稱: ${data['name']}');
        LoggerService.info('  圖片欄位: ${data['圖片']}');
        LoggerService.info('  imageUrl欄位: ${data['imageUrl']}');
        LoggerService.info('  價格: ${data['price']}');
        LoggerService.info('  狀態: ${data['狀態']}');
        LoggerService.info('  ---');
      }
    } catch (e) {
      LoggerService.error('測試主題桌鋪數據失敗: $e');
    }
  }

  Future<void> _loadPurchasedItems() async {
    if (_currentUser == null) return;

    try {
      purchasedItems.clear();
      
      // 使用新的統一用戶資料服務獲取已擁有商品
      final ownedProducts = await UnifiedUserDataService.getOwnedProducts();
      for (final product in ownedProducts) {
        purchasedItems[product['id']] = true;
      }
      
      LoggerService.info('載入已擁有商品完成，共 ${purchasedItems.length} 個');
    } catch (e) {
      LoggerService.error('載入已擁有商品時發生錯誤: $e');
    }
  }

  /// 獲取用戶購買商品的實時流
  Stream<DocumentSnapshot?> _getUserPurchasedItemsStream() {
    if (_currentUser == null) {
      return Stream.value(null);
    }

    final uid = _currentUser!['uid'] ?? 'default';
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }
  
  /// 獲取用戶飼料庫存的實時流
  Stream<Map<String, int>> _getUserFoodInventoryStream() {
    if (_currentUser == null) {
      return Stream.value({});
    }

    return FoodService.getUserFoodInventoryStream();
  }

  /// 統一的確認對話框
  Future<void> _showConfirmDialog(
    BuildContext context,
    Map<String, dynamic> product,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final status = product['狀態'] ?? product['status'] ?? '購買';
    final priceRaw = product['價格'] ?? product['price'] ?? 0;
    final price = priceRaw is String ? int.tryParse(priceRaw) ?? 0 : (priceRaw is int ? priceRaw : 0);

    String title;
    String content;

    if (status == '登入領取') {
      title = '領取確認';
      content = '確定要領取「${product['name']}」嗎？';
    } else {
      title = '購買確認';
      content = '確定要購買「${product['name']}」嗎？價格：$price 元';
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      bool success;
      if (status == '登入領取') {
        success = await _claimItem(product);
      } else {
        success = await _buyItem(product);
      }

      if (success) {
        // 如果是主題桌鋪，詢問是否要應用主題
        if (categories[_tabController.index] == '主題桌鋪') {
          await _showThemeApplicationDialog(context, product);
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${status == '登入領取' ? '領取' : '購買'}成功！${product['name'] ?? '商品'} 已加入收藏',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${status == '登入領取' ? '領取' : '購買'}失敗，請稍後再試'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget buildItem(DocumentSnapshot item, {String? category}) {
    try {
      final data = item.data() as Map<String, dynamic>;
      final name = data['name'] ?? '未命名商品';
      final priceRaw = data['price'] ?? data['價格'] ?? 0;
      final price = priceRaw is String ? int.tryParse(priceRaw) ?? 0 : (priceRaw is int ? priceRaw : 0);
      final popularity = data['常見度'] ?? data['popularity'] ?? '常見';
      final imageUrl =
          data['圖片'] ??
          data['imageUrl'] ??
          data['image'] ??
          data['url'] ??
          data['img'] ??
          '';
      final description = data['description'] ?? '';
      final status = data['狀態'] ?? data['status'] ?? '購買';

      // 調試信息：打印圖片URL
      LoggerService.debug('商品: $name, 圖片URL: $imageUrl, 類別: $category');
      LoggerService.debug('完整商品數據: $data');
      LoggerService.debug('圖片欄位檢查:');
      LoggerService.debug('  data["圖片"]: ${data['圖片']}');
      LoggerService.debug('  data["imageUrl"]: ${data['imageUrl']}');
      LoggerService.debug('  data["image"]: ${data['image']}');
      LoggerService.debug('  data["url"]: ${data['url']}');
      LoggerService.debug('  data["img"]: ${data['img']}');

                // 檢查是否為經典款商品（任何類別且價格為0）
          final isClassicItem = price == 0;
          
          // 檢查是否為飼料類別（可以重複購買）
          final isFoodCategory = category == '飼料';

            return StreamBuilder<DocumentSnapshot?>(
        stream: _getUserPurchasedItemsStream(),
        builder: (context, snapshot) {
          bool isPurchased = false;
          bool isItemUnavailable = false; // 新增：檢查商品是否不可用
          int foodAmount = 0; // 飼料數量

          if (snapshot.hasData && snapshot.data != null) {
            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            if (userData != null) {
              final ownedProducts = Map<String, bool>.from(userData['ownedProducts'] ?? {});
              isPurchased = ownedProducts[item.id] ?? false;
            }
          }
          
          // 如果是飼料類別，獲取數量
          if (isFoodCategory) {
            // 暫時從用戶數據中獲取飼料庫存，稍後會改為實時流
            if (snapshot.hasData && snapshot.data != null) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              if (userData != null) {
                final foodInventory = Map<String, int>.from(userData['foodInventory'] ?? {});
                foodAmount = foodInventory[item.id] ?? 0;
              }
            }
          }

          // 檢查 Firebase 中商品的狀態欄位
          isItemUnavailable = status == '已擁有';

          return Card(
            margin: const EdgeInsets.all(8),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_cardBorderRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 圖片區域
                Container(
                  height: _cardImageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_cardBorderRadius),
                    ),
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade100, Colors.blue.shade200],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: _buildImageWidget(
                          imageUrl,
                          name,
                          price,
                          description,
                          isClassicItem,
                          category,
                        ),
                      ),
                      // 稀有度標籤
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getRarityColor(popularity),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            popularity,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // 已購買標籤
                      if ((isPurchased || isItemUnavailable) && !isFoodCategory)
                        Positioned(
                          top: isClassicItem ? 36 : 8, // 如果是經典款，位置下移
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '已擁有',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      
                      // 飼料數量標籤
                      if (isFoodCategory && foodAmount > 0)
                        Positioned(
                          top: isClassicItem ? 36 : 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'x$foodAmount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 內容區域
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isClassicItem ? '價格: 免費' : '價格: $price 元',
                          style: TextStyle(
                            color: isClassicItem
                                ? Colors.green.shade700
                                : Colors.amber.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '常見度: $popularity',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 9,
                          ),
                        ),
                        const Spacer(),
                        // 按鈕區域
                        Container(
                          width: double.infinity,
                          height: _buttonHeight,
                          child: ElevatedButton(
                            onPressed: ((isPurchased || isItemUnavailable) && !isFoodCategory)
                                ? null
                                : () => _showConfirmDialog(context, {
                                    ...data,
                                    'id': item.id,
                                  }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isClassicItem
                                  ? Colors.green.shade600
                                  : Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  _buttonBorderRadius,
                                ),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              (isFoodCategory) 
                                  ? '購買'
                                  : ((isPurchased || isItemUnavailable)
                                      ? '已擁有'
                                      : (isClassicItem ? '領取' : '購買')),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      LoggerService.error('構建商品卡片時發生錯誤: $e');
      return Card(
        margin: const EdgeInsets.all(8),
        child: Container(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400),
                const SizedBox(height: 8),
                Text('載入失敗', style: TextStyle(color: Colors.red.shade600)),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget buildCategoryTab(String category) {
    // 如果是主題桌鋪分類，直接從 Firebase 讀取
    if (category == '主題桌鋪') {
      LoggerService.info('開始載入主題桌鋪分類');
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('主題桌鋪').snapshots(),
        builder: (context, snapshot) {
          LoggerService.info('主題桌鋪 StreamBuilder 狀態: hasData=${snapshot.hasData}, hasError=${snapshot.hasError}, error=${snapshot.error}');
          
          if (snapshot.hasError) {
            LoggerService.error('載入主題桌鋪資料時發生錯誤: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '載入資料錯誤: ${snapshot.error}',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // 重新構建
                    },
                    child: const Text('重試'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            LoggerService.info('主題桌鋪資料尚未載入完成');
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('載入中...'),
                ],
              ),
            );
          }

          final items = snapshot.data!.docs;
          LoggerService.info('主題桌鋪載入完成，共 ${items.length} 個項目');

          if (items.isEmpty) {
            LoggerService.warning('主題桌鋪集合為空');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.table_bar_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '此類別尚無主題桌鋪',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '類別: $category',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      // 嘗試手動測試Firebase連接
                      try {
                        LoggerService.info('手動測試Firebase連接...');
                        final testSnapshot = await FirebaseFirestore.instance
                            .collection('主題桌鋪')
                            .get();
                        LoggerService.info('測試結果: ${testSnapshot.docs.length} 個文檔');
                        for (final doc in testSnapshot.docs) {
                          LoggerService.info('文檔ID: ${doc.id}, 數據: ${doc.data()}');
                        }
                        setState(() {}); // 重新構建
                      } catch (e) {
                        LoggerService.error('手動測試失敗: $e');
                      }
                    },
                    child: const Text('測試連接'),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: _gridChildAspectRatio,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              LoggerService.debug('構建主題桌鋪項目 $index: ${item.data()}');
              
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 50)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: buildItem(item, category: category),
                  );
                },
              );
            },
          );
        },
      );
    }

    // 其他分類的處理保持不變
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(category).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          LoggerService.error('載入商品資料時發生錯誤: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  '載入資料錯誤: ${snapshot.error}',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // 重新構建
                  },
                  child: const Text('重試'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('載入中...'),
              ],
            ),
          );
        }

        final items = snapshot.data!.docs;

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  '此類別尚無商品',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  '類別: $category',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: _gridChildAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 50)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: buildItem(items[index], category: category),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }



  /// 顯示主題應用對話框
  Future<void> _showThemeApplicationDialog(
    BuildContext context,
    Map<String, dynamic> product,
  ) async {
    final bool? applyTheme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.palette, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text('應用主題'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('是否要將「${product['name']}」設為聊天頁面的背景主題？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '這個主題將會顯示在聊天頁面的背景',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍後設置'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('立即應用'),
          ),
        ],
      ),
    );

    if (applyTheme == true && mounted) {
      await _applyTheme(product);
    }
  }

  /// 應用主題
  Future<void> _applyTheme(Map<String, dynamic> product) async {
    try {
      LoggerService.info('開始應用主題: ${product['name']}');
      
      final themeId = product['id'] ?? '';
      final imageUrl = product['圖片'] ?? product['imageUrl'] ?? '';
      final themeName = product['name'] ?? '未命名主題';

      final success = await ThemeBackgroundService.setSelectedTheme(
        themeId,
        imageUrl,
        themeName,
      );

      if (success && mounted) {
        LoggerService.info('主題設置成功，開始通知背景更新');
        
        // 通知背景更新
        ThemeBackgroundNotifier().notifyBackgroundChanged();
        
        // 延遲一點時間讓背景更新生效，然後強制重建頁面
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          setState(() {
            // 強制重建頁面以確保所有內容正確顯示
          });
          LoggerService.info('商城頁面已重建');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('主題「$themeName」已成功應用到所有頁面！')),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else if (mounted) {
        LoggerService.error('主題設置失敗');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                const Text('應用主題失敗，請稍後再試'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('應用主題失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('應用主題時發生錯誤: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  /// 領取商品（免費）
  Future<bool> _claimItem(Map<String, dynamic> product) async {
    if (_currentUser == null) return false;

    try {
      // 獲取當前類別
      final currentCategory = categories[_tabController.index];
      final itemId = product['id'] ?? '';

              // 使用新的統一用戶資料服務更新商品狀態
        LoggerService.info('嘗試購買商品: ID=$itemId, 名稱=${product['name']}, 類別=$currentCategory');
        final claimSuccess = await UnifiedUserDataService.purchaseProduct(itemId);
        
        if (claimSuccess) {
          setState(() {
            purchasedItems[product['id']] = true;
          });

          LoggerService.info('免費商品領取成功: ${product['name']} (ID: $itemId, 類別: $currentCategory)');
          return true;
      } else {
        LoggerService.error('更新用戶庫存失敗');
        return false;
      }
    } catch (e) {
      LoggerService.error('領取商品時發生錯誤: $e');
      return false;
    }
  }

  Future<bool> _buyItem(Map<String, dynamic> product) async {
    if (_currentUser == null) return false;

    final priceRaw = product['價格'] ?? product['price'] ?? 0;
    final price = priceRaw is String ? int.tryParse(priceRaw) ?? 0 : (priceRaw is int ? priceRaw : 0);
    final hasEnoughCoins = await CoinService.hasEnoughCoins(price);

    if (!hasEnoughCoins) {
      return false;
    }

    try {
      final success = await CoinService.deductCoins(price);
      if (success) {
        // 獲取當前類別
        final currentCategory = categories[_tabController.index];
        final itemId = product['id'] ?? '';

        // 統一處理所有商品的購買邏輯
        LoggerService.info('嘗試購買商品: ID=$itemId, 名稱=${product['name']}, 類別=$currentCategory');
        
        // 如果是飼料類別，增加飼料數量
        if (currentCategory == '飼料') {
          // 更新用戶文檔中的飼料庫存
          final uid = _currentUser!['uid'] ?? 'default';
          final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
          
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final userDoc = await transaction.get(userRef);
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              final foodInventory = Map<String, int>.from(userData['foodInventory'] ?? {});
              
              // 增加飼料數量
              foodInventory[itemId] = (foodInventory[itemId] ?? 0) + 1;
              
              transaction.update(userRef, {
                'foodInventory': foodInventory,
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            } else {
              // 如果用戶文檔不存在，創建新的
              transaction.set(userRef, {
                'foodInventory': {itemId: 1},
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            }
          });
        } else {
          // 其他類別使用原有的購買邏輯
          final purchaseSuccess = await UnifiedUserDataService.purchaseProduct(itemId);
          
          if (!purchaseSuccess) {
            LoggerService.error('更新用戶庫存失敗');
            return false;
          }
          
          setState(() {
            purchasedItems[product['id']] = true;
          });
        }
        
        // 為所有商品增加購買次數記錄
        await UserPurchaseService.incrementPurchaseCount(itemId, product['name']);
        
        _coinDisplayKey.currentState?.refreshCoins();
        LoggerService.info('商品購買成功: ${product['name']} (ID: $itemId, 類別: $currentCategory)');
        return true;
      }
    } catch (e) {
      LoggerService.error('購買商品時發生錯誤: $e');
      return false;
    }
    return false;
  }

  void _showImagePreview(
    BuildContext context,
    String imageUrl,
    String name,
    dynamic price,
    String description,
    bool isClassicItem,
    String? category,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              // 背景遮罩
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(color: Colors.black.withValues(alpha: 0.8)),
                ),
              ),
              // 圖片容器
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // 圖片
                        Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade800,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 64,
                                ),
                              ),
                            );
                          },
                        ),
                        // 關閉按鈕
                        Positioned(
                          top: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        // 商品資訊（右下角）
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isClassicItem ? '價格: 免費' : '價格: $price 元',
                                  style: TextStyle(
                                    color: isClassicItem
                                        ? Colors.green.shade300
                                        : Colors.amber.shade300,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                if (isClassicItem ||
                                    description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 200,
                                    ),
                                    child: Text(
                                      isClassicItem
                                          ? '登入即可免費領取的${_getClassicLabel(category)}，每位玩家都能獲得！'
                                          : description,
                                      style: TextStyle(
                                        color: isClassicItem
                                            ? Colors.orange.shade300
                                            : Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.right,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageWidget(
    String imageUrl,
    String name,
    dynamic price,
    String description,
    bool isClassicItem,
    String? category,
  ) {
    // 調試信息：詳細記錄圖片URL檢查過程
    LoggerService.debug('_buildImageWidget - 商品: $name, 原始圖片URL: "$imageUrl"');
    LoggerService.debug(
      '_buildImageWidget - URL長度: ${imageUrl.length}, 是否為空: ${imageUrl.isEmpty}',
    );
    LoggerService.debug('_buildImageWidget - URL是否為""字符串: ${imageUrl == '""'}');
    LoggerService.debug(
      '_buildImageWidget - URL是否為null字符串: ${imageUrl == 'null'}',
    );
    LoggerService.debug(
      '_buildImageWidget - URL是否以http開頭: ${imageUrl.startsWith('http://')}',
    );
    LoggerService.debug(
      '_buildImageWidget - URL是否以https開頭: ${imageUrl.startsWith('https://')}',
    );

    // 如果是特效類別，顯示影片預覽
    if (category == '特效') {
      return _buildEffectVideoPreview(name);
    }

    // 檢查圖片URL是否有效
    bool isValidUrl =
        imageUrl.isNotEmpty &&
        imageUrl != '""' &&
        imageUrl != 'null' &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    LoggerService.debug('_buildImageWidget - URL是否有效: $isValidUrl');

    if (isValidUrl) {
      return GestureDetector(
        onTap: () => _showImagePreview(
          context,
          imageUrl,
          name,
          price,
          description,
          isClassicItem,
          category,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_cardBorderRadius),
          ),
          child: Image.network(
            imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '載入中...',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              LoggerService.warning('圖片載入失敗: $imageUrl, 錯誤: $error');
              return _buildNoImagePlaceholder();
            },
          ),
        ),
      );
    } else {
      return _buildNoImagePlaceholder();
    }
  }

  Widget _buildNoImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            '此商品尚未建立模型',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 根據類別獲取經典款標籤文字
  String _getClassicLabel(String? category) {
    switch (category) {
      case '造型':
        return '經典造型';
      case '特效':
        return '經典特效';
      case '主題桌鋪':
        return '經典主題';
      case '飼料':
        return '經典飼料';
      default:
        return '經典款';
    }
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case '稀有':
        return Colors.purple.shade400;
      case '普通':
        return Colors.blue.shade400;
      case '常見':
        return Colors.green.shade400;
      case 'rare':
        return Colors.purple.shade400;
      case 'common':
        return Colors.green.shade400;
      case 'normal':
        return Colors.blue.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景圖層 - 確保在最底層
          Positioned.fill(
            child: ThemeBackgroundListener(
              overlayColor: Colors.white,
              overlayOpacity: 0.2, // 降低遮罩透明度，讓背景更明顯
              child: Container(), // 空容器，只用於顯示背景
            ),
          ),
          // 內容層 - 在背景之上
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              LoggerService.info('從商城頁面返回');
                              Navigator.pop(context);
                            },
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
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '商城',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          CoinDisplay(key: _coinDisplayKey),
                          const SizedBox(width: 12),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          indicator: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.black87,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          tabs: categories
                              .map(
                                (c) => Tab(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(categoryIcons[c], size: 16),
                                      const SizedBox(width: 4),
                                      Text(c),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: categories
                        .map((category) => buildCategoryTab(category))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        // 如果沒有對應的映射，返回預設影片
        LoggerService.warning('未找到特效 $effectName 的影片映射，使用預設影片');
        return 'assets/MRTvedio/night.mp4'; // 使用預設影片
    }
  }

  /// 構建特效影片預覽組件
  Widget _buildEffectVideoPreview(String effectName) {
    return EffectThumbnailWidget(
      effectName: effectName,
      width: double.infinity,
      height: double.infinity,
      onTap: () => _showEffectPreview(context, effectName),
    );
  }

  /// 顯示特效影片播放對話框
  void _showEffectPreview(BuildContext context, String effectName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              // 背景遮罩
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(color: Colors.black.withValues(alpha: 0.8)),
                ),
              ),
              // 影片播放器容器
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // 影片播放器
                        AssetVideoPlayer(
                          assetPath: _getEffectVideoPath(effectName),
                          autoPlay: true,
                          showControls: true,
                        ),
                        // 關閉按鈕
                        Positioned(
                          top: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        // 特效資訊（右下角）
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  effectName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '特效影片',
                                  style: TextStyle(
                                    color: Colors.blue.shade300,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
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
            ],
          ),
        );
      },
    );
  }
}
