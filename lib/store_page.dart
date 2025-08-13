import 'package:flutter/material.dart';
import 'coin_service.dart';
import 'coin_display.dart';
import 'user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();

  final List<String> categories = ['造型', '裝飾', '語氣', '動作', '飼料'];
  
  final Map<String, IconData> categoryIcons = {
    '造型': Icons.face,
    '裝飾': Icons.diamond,
    '語氣': Icons.chat_bubble,
    '動作': Icons.directions_run,
    '飼料': Icons.restaurant,
  };

  // 對應 Firebase 集合名稱
  final Map<String, String> categoryCollections = {
    '造型': '造型',
    '裝飾': '裝飾',
    '語氣': '語氣',
    '動作': '動作',
    '飼料': '飼料',
  };

  Map<String, dynamic>? _currentUser;
  final Map<String, bool> purchasedItems = {};

  @override
  void initState() {
    super.initState();
    LoggerService.info('StorePage 初始化開始');
    _tabController = TabController(length: categories.length, vsync: this);
    _loadUserData();
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
        content: Text('確定要購買「${product['name']}」嗎？價格：${product['price']}'),
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

  Widget _buildFirebaseProductCard(Map<String, dynamic> product) {
    final isPurchased = purchasedItems[product['id']] == true;
    final category = product['category'] ?? '未知';
    final rarity = product['rarity'] ?? '常見';
    final price = product['price'] ?? 0;
    final name = product['name'] ?? '未命名商品';
    final description = product['description'] ?? '';
    final imageUrl = product['imageUrl'];
    final iconName = product['iconName'] ?? '';
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade100,
                    Colors.blue.shade200,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildCategoryIcon(category, iconName);
                              },
                            ),
                          )
                        : _buildCategoryIcon(category, iconName),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getRarityColor(rarity),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        rarity,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (isPurchased)
                    Positioned(
                      top: 8,
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
                        child: const Text(
                          '已購買',
                          style: TextStyle(
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
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.monetization_on,
                          size: 16,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$price',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: isPurchased
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
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
                                    '已購買',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () => _showPurchaseDialog(context, product),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                '購買',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirebaseProductList(String category) {
    final collectionName = categoryCollections[category] ?? category;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionName)
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
        
        if (snapshot.connectionState == ConnectionState.waiting) {
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
        
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
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

        final products = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        LoggerService.info('載入到 $category 類別的商品: ${products.length} 個');

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final product = products[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 50)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: _buildFirebaseProductCard(product),
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

  Future<void> _buyItem(Map<String, dynamic> product) async {
    if (_currentUser == null) return;
    
    final price = product['price'] ?? 0;
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

  Widget _buildCategoryIcon(String category, String iconName) {
    // 根據類別和圖標名稱返回適當的圖標
    IconData iconData = categoryIcons[category] ?? Icons.shopping_bag;
    Color iconColor = Colors.blue.shade600;
    
    // 根據類別調整圖標顏色
    switch (category) {
      case '造型':
        iconColor = Colors.purple.shade600;
        break;
      case '裝飾':
        iconColor = Colors.amber.shade600;
        break;
      case '語氣':
        iconColor = Colors.green.shade600;
        break;
      case '動作':
        iconColor = Colors.orange.shade600;
        break;
      case '飼料':
        iconColor = Colors.brown.shade600;
        break;
    }
    
    return Icon(
      iconData,
      size: 48,
      color: iconColor,
    );
  }



  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case '稀有':
        return Colors.purple.shade400;
      case '普通':
        return Colors.blue.shade400;
      case '常見':
        return Colors.green.shade400;
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
                children: categories.map((category) => _buildFirebaseProductList(category)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
