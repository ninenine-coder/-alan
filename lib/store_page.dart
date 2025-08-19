import 'package:flutter/material.dart';
import 'coin_service.dart';
import 'coin_display.dart';
import 'user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';
import 'add_item.dart';

class StorePage extends StatefulWidget {
  final String? initialCategory;

  const StorePage({super.key, this.initialCategory});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with TickerProviderStateMixin {
  // 常量定義
  static const double _cardImageHeight = 120.0;
  static const double _buttonHeight = 40.0;
  static const double _cardBorderRadius = 12.0;
  static const double _buttonBorderRadius = 8.0;
  static const double _gridChildAspectRatio = 0.75;
  
  late TabController _tabController;
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();

  final List<String> categories = ['造型', '特效', '頭像', '主題桌鋪', '飼料'];
  
  final Map<String, IconData> categoryIcons = {
    '造型': Icons.face,
    '特效': Icons.auto_awesome,
    '頭像': Icons.account_circle,
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
      await testReadFirebaseData();
    } catch (e) {
      LoggerService.error('Firebase 連接測試失敗: $e');
    }
  }

  Future<void> _loadPurchasedItems() async {
    if (_currentUser == null) return;
    
    try {
      final username = _currentUser!['username'] ?? 'default';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(username)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final purchasedItemIds = List<String>.from(userData['purchasedItems'] ?? []);
        
        purchasedItems.clear();
        for (final itemId in purchasedItemIds) {
          purchasedItems[itemId] = true;
        }
      }
    } catch (e) {
      LoggerService.error('載入已購買商品時發生錯誤: $e');
    }
  }

  /// 獲取用戶購買商品的實時流
  Stream<DocumentSnapshot?> _getUserPurchasedItemsStream() {
    if (_currentUser == null) {
      return Stream.value(null);
    }
    
    final username = _currentUser!['username'] ?? 'default';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(username)
        .snapshots();
  }

  /// 統一的確認對話框
  Future<void> _showConfirmDialog(BuildContext context, Map<String, dynamic> product) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final status = product['狀態'] ?? product['status'] ?? '購買';
    final price = product['價格'] ?? product['price'] ?? 0;
    
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
        // 更新 Firebase 中的狀態欄位為"已擁有"
        await _updateItemStatus(product['id'], '已擁有');
        
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${status == '登入領取' ? '領取' : '購買'}成功！${product['name'] ?? '商品'} 已加入收藏'),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      final price = data['價格'] ?? data['price'] ?? 0;
      final popularity = data['常見度'] ?? data['popularity'] ?? '常見';
      final imageUrl = data['圖片'] ?? data['imageUrl'] ?? '';
      final description = data['description'] ?? '';
      final status = data['狀態'] ?? data['status'] ?? '購買';
      
            // 檢查是否為經典款商品（任何類別且價格為0）
      final isClassicItem = price == 0;
      
      return StreamBuilder<DocumentSnapshot?>(
      stream: _getUserPurchasedItemsStream(),
      builder: (context, snapshot) {
        bool isPurchased = false;
        bool isOwned = status == '已擁有'; // 檢查商品狀態是否為已擁有
        
        if (snapshot.hasData && snapshot.data != null) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null) {
            final purchasedItemIds = List<String>.from(userData['purchasedItems'] ?? []);
            isPurchased = purchasedItemIds.contains(item.id);
          }
        }
        
        // 如果商品狀態為已擁有，則顯示為已購買
        isPurchased = isPurchased || isOwned;
        
        return Card(
          margin: const EdgeInsets.all(8),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardBorderRadius)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 圖片區域
              Container(
                height: _cardImageHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(_cardBorderRadius)),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade100, Colors.blue.shade200],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: imageUrl != null && imageUrl.isNotEmpty && imageUrl != '""'
                          ? GestureDetector(
                              onTap: () => _showImagePreview(context, imageUrl, name, price, description, isClassicItem, category),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(_cardBorderRadius)),
                                child: Image.network(
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
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildNoImagePlaceholder();
                                  },
                                ),
                              ),
                            )
                          : _buildNoImagePlaceholder(),
                    ),
                    // 稀有度標籤
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    if (isPurchased)
                      Positioned(
                        top: isClassicItem ? 36 : 8, // 如果是經典款，位置下移
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  ],
                ),
              ),
              // 內容區域
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(height: 4),

                      const SizedBox(height: 4),
                      Text(
                        isClassicItem ? '價格: 免費' : '價格: $price 元',
                        style: TextStyle(
                          color: isClassicItem ? Colors.green.shade700 : Colors.amber.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '常見度: $popularity',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      // 按鈕區域
                      Container(
                        width: double.infinity,
                        height: _buttonHeight,
                        margin: const EdgeInsets.only(top: 8, bottom: 4),
                        child: isPurchased
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(_buttonBorderRadius),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.grey.shade600,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '已擁有',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isOwned ? null : () => _showConfirmDialog(context, {...data, 'id': item.id}),
                                  borderRadius: BorderRadius.circular(_buttonBorderRadius),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: status == '登入領取' ? Colors.orange.shade600 : Colors.blue.shade600,
                                      borderRadius: BorderRadius.circular(_buttonBorderRadius),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
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
      return const Card(
        child: Center(
          child: Text('載入失敗'),
        ),
      );
    }
  }

  Widget buildCategoryTab(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(category)
          .snapshots(),
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
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  '此類別尚無商品',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '類別: $category',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
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

  /// 更新 Firebase 中的商品狀態
  Future<void> _updateItemStatus(String itemId, String newStatus) async {
    try {
      final currentCategory = categories[_tabController.index];
      await FirebaseFirestore.instance
          .collection(currentCategory)
          .doc(itemId)
          .update({'狀態': newStatus});
    } catch (e) {
      LoggerService.error('更新商品狀態失敗: $e');
    }
  }

  /// 領取商品（免費）
  Future<bool> _claimItem(Map<String, dynamic> product) async {
    if (_currentUser == null) return false;
    
    try {
      final username = _currentUser!['username'] ?? 'default';
      final userRef = FirebaseFirestore.instance.collection('users').doc(username);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final purchasedItems = List<String>.from(userData['purchasedItems'] ?? []);
          final purchasedItemsWithCategory = Map<String, dynamic>.from(userData['purchasedItemsWithCategory'] ?? {});
          
          if (!purchasedItems.contains(product['id'])) {
            purchasedItems.add(product['id']);
            
            // 獲取當前類別
            final currentCategory = categories[_tabController.index];
            
            // 保存商品詳細信息到 purchasedItemsWithCategory
            purchasedItemsWithCategory[product['id']] = {
              'name': product['name'],
              'category': currentCategory,
              'imageUrl': product['圖片'] ?? product['imageUrl'] ?? '',
              'purchasedAt': FieldValue.serverTimestamp(),
            };
            
            transaction.update(userRef, {
              'purchasedItems': purchasedItems,
              'purchasedItemsWithCategory': purchasedItemsWithCategory,
            });
          }
        }
      });
      
      setState(() {
        purchasedItems[product['id']] = true;
      });
      
      return true;
    } catch (e) {
      LoggerService.error('領取商品時發生錯誤: $e');
      return false;
    }
  }



  Future<bool> _buyItem(Map<String, dynamic> product) async {
    if (_currentUser == null) return false;
    
    final price = product['價格'] ?? product['price'] ?? 0;
    final hasEnoughCoins = await CoinService.hasEnoughCoins(price);
    
    if (!hasEnoughCoins) {
      return false;
    }

    try {
      final success = await CoinService.deductCoins(price);
      if (success) {
        final username = _currentUser!['username'] ?? 'default';
        final userRef = FirebaseFirestore.instance.collection('users').doc(username);
        
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final userDoc = await transaction.get(userRef);
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final purchasedItems = List<String>.from(userData['purchasedItems'] ?? []);
            final purchasedItemsWithCategory = Map<String, dynamic>.from(userData['purchasedItemsWithCategory'] ?? {});
            
            if (!purchasedItems.contains(product['id'])) {
              purchasedItems.add(product['id']);
              
              // 獲取當前類別
              final currentCategory = categories[_tabController.index];
              
              // 保存商品詳細信息到 purchasedItemsWithCategory
              purchasedItemsWithCategory[product['id']] = {
                'name': product['name'],
                'category': currentCategory,
                'imageUrl': product['圖片'] ?? product['imageUrl'] ?? '',
                'purchasedAt': FieldValue.serverTimestamp(),
              };
              
              transaction.update(userRef, {
                'purchasedItems': purchasedItems,
                'purchasedItemsWithCategory': purchasedItemsWithCategory,
              });
            }
          }
        });
        
        setState(() {
          purchasedItems[product['id']] = true;
        });
        
        _coinDisplayKey.currentState?.refreshCoins();
        
        // 購買成功，UI 更新將由 StreamBuilder 自動處理
        return true;
      }
    } catch (e) {
      LoggerService.error('購買商品時發生錯誤: $e');
      return false;
    }
    return false;
  }

  void _showImagePreview(BuildContext context, String imageUrl, String name, dynamic price, String description, bool isClassicItem, String? category) {
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
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.8),
                  ),
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
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    color: isClassicItem ? Colors.green.shade300 : Colors.amber.shade300,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                if (isClassicItem || description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    constraints: const BoxConstraints(maxWidth: 200),
                                    child: Text(
                                      isClassicItem 
                                          ? '登入即可免費領取的${_getClassicLabel(category)}，每位玩家都能獲得！'
                                          : description,
                                      style: TextStyle(
                                        color: isClassicItem ? Colors.orange.shade300 : Colors.white.withValues(alpha: 0.9),
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

  Widget _buildNoImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            '此商品尚未建立模型',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
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
       case '頭像':
         return '經典頭像';
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 10,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '商城',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      CoinDisplay(key: _coinDisplayKey),
                      const SizedBox(width: 16),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: Colors.blue.shade800,
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: categories.map((c) => Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(categoryIcons[c], size: 16),
                            const SizedBox(width: 4),
                            Text(c),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: categories.map((category) => buildCategoryTab(category)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
