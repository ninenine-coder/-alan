import 'package:flutter/material.dart';
import 'coin_service.dart';
import 'coin_display.dart';
import 'user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';
import 'add_item.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with TickerProviderStateMixin {
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
    LoggerService.info('StorePage 初始化開始');
    _tabController = TabController(length: categories.length, vsync: this);
    _loadUserData();
    _testFirebaseConnection();
    LoggerService.info('StorePage 初始化完成');
  }

  Future<void> _loadUserData() async {
    LoggerService.info('開始載入用戶資料');
    _currentUser = await UserService.getCurrentUserData();
    LoggerService.info('用戶資料載入完成: ${_currentUser != null ? '成功' : '失敗'}');
    await _loadPurchasedItems();
    setState(() {});
    LoggerService.info('StorePage 狀態更新完成');
  }

  Future<void> _testFirebaseConnection() async {
    try {
      LoggerService.info('開始測試 Firebase 連接...');
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

  Future<void> _showPurchaseDialog(BuildContext context, Map<String, dynamic> product) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('購買確認'),
        content: Text('確定要購買「${product['name']}」嗎？價格：${product['價格'] ?? product['price']}'),
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

    if (confirmed == true) {
      await _buyItem(product);
    }
  }

  Widget buildItem(DocumentSnapshot item, {String? category}) {
    final data = item.data() as Map<String, dynamic>;
    final isPurchased = purchasedItems[item.id] == true;
    final name = data['name'] ?? '未命名商品';
    final price = data['價格'] ?? data['price'] ?? 0; // 支援兩種價格欄位名稱
    final popularity = data['常見度'] ?? data['popularity'] ?? '常見'; // 支援兩種常見度欄位名稱
    final imageUrl = data['圖片'] ?? data['imageUrl'] ?? ''; // 優先使用中文欄位名稱 '圖片'
    final description = data['description'] ?? '';
    
         // 檢查是否為經典款商品（任何類別且價格為0）
     final isClassicItem = price == 0;
    
    // 調試信息
    LoggerService.info('商品資料: $data');
    LoggerService.info('商品名稱: $name');
    LoggerService.info('商品價格: $price');
    LoggerService.info('商品常見度: $popularity');
    LoggerService.info('圖片URL: $imageUrl');
    
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // 圖片區域
            Container(
              height: 120,
            width: double.infinity,
              decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.blue.shade200],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                  child: imageUrl != null && imageUrl.isNotEmpty && imageUrl != '""'
                      ? GestureDetector(
                          onTap: () => _showImagePreview(context, imageUrl, name, price),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  LoggerService.info('圖片載入成功: $imageUrl');
                                  return child;
                                }
                                LoggerService.info('圖片載入中: $imageUrl, 進度: ${loadingProgress.expectedTotalBytes != null ? (loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).toStringAsFixed(1) : '未知'}%');
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                LoggerService.error('圖片載入失敗: $imageUrl, 錯誤: $error');
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
                                 // 經典款標籤
                   if (isClassicItem)
                     Positioned(
                       top: 8,
                       left: 8,
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                         decoration: BoxDecoration(
                           color: Colors.orange.shade600,
                           borderRadius: BorderRadius.circular(12),
                         ),
                         child: Text(
                           _getClassicLabel(category),
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
                          isClassicItem ? '已領取' : '已購買',
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
                                         Text(
                       isClassicItem 
                           ? '登入即可免費領取的${_getClassicLabel(category)}，每位玩家都能獲得！'
                           : description,
                       style: TextStyle(
                         color: isClassicItem ? Colors.orange.shade600 : Colors.grey.shade600,
                         fontSize: 10,
                         fontWeight: isClassicItem ? FontWeight.w500 : FontWeight.normal,
                       ),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
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
                    SizedBox(
                      width: double.infinity,
                      child: isPurchased
                          ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isClassicItem ? '已領取' : '已購買',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ElevatedButton(
                            onPressed: () => isClassicItem 
                                ? _claimClassicItem(context, {...data, 'id': item.id})
                                : _showPurchaseDialog(context, {...data, 'id': item.id}),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isClassicItem ? Colors.orange.shade600 : Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: Text(
                                isClassicItem ? '登入領取' : '購買',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
  }

  Widget buildCategoryTab(String category) {
    LoggerService.info('開始載入類別: $category');
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(category)
          .snapshots(), // 移除 orderBy 以避免欄位不存在的問題
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
          LoggerService.info('正在載入 $category 類別的資料...');
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
        LoggerService.info('$category 類別載入到 ${items.length} 個商品');

        if (items.isEmpty) {
          LoggerService.info('$category 類別沒有商品資料');
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

        LoggerService.info('載入到 $category 類別的商品: ${items.length} 個');

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
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

  /// 領取經典款商品（免費）
  Future<void> _claimClassicItem(BuildContext context, Map<String, dynamic> product) async {
    if (_currentUser == null) return;
    
    try {
      final username = _currentUser!['username'] ?? 'default';
      final userRef = FirebaseFirestore.instance.collection('users').doc(username);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final purchasedItems = List<String>.from(userData['purchasedItems'] ?? []);
          
          if (!purchasedItems.contains(product['id'])) {
            purchasedItems.add(product['id']);
            transaction.update(userRef, {'purchasedItems': purchasedItems});
          }
        }
      });
      
      setState(() {
        purchasedItems[product['id']] = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('領取成功！${product['name'] ?? '經典款商品'} 已加入收藏'),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      LoggerService.info('經典款商品領取成功: ${product['name']}');
    } catch (e) {
      LoggerService.error('領取經典款商品時發生錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('領取失敗，請稍後再試'),
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

  Future<void> _buyItem(Map<String, dynamic> product) async {
    if (_currentUser == null) return;
    
    final price = product['價格'] ?? product['price'] ?? 0;
    final hasEnoughCoins = await CoinService.hasEnoughCoins(price);
    
    if (!hasEnoughCoins) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('金幣不足！需要 $price 金幣'),
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
      return;
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
            
            if (!purchasedItems.contains(product['id'])) {
              purchasedItems.add(product['id']);
              transaction.update(userRef, {'purchasedItems': purchasedItems});
            }
          }
        });
        
        setState(() {
          purchasedItems[product['id']] = true;
        });
        
        _coinDisplayKey.currentState?.refreshCoins();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('購買成功！${product['name'] ?? '商品'} 已加入收藏'),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      LoggerService.error('購買商品時發生錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('購買失敗: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl, String name, dynamic price) {
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
                                  '價格: $price 元',
                                  style: TextStyle(
                                    color: Colors.amber.shade300,
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
