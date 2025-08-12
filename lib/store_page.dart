import 'package:flutter/material.dart';
import 'dart:io';
import 'coin_service.dart';
import 'coin_display.dart';
import 'user_service.dart';
import 'data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();

  final List<String> categories = ['造型', '裝飾', '語氣', '動作', '飼料'];
  
  // 為每個類別定義不同的圖示
  final Map<String, IconData> categoryIcons = {
    '造型': Icons.face,
    '裝飾': Icons.diamond,
    '語氣': Icons.chat_bubble,
    '動作': Icons.directions_run,
    '飼料': Icons.restaurant,
  };

  // 從管理員系統載入的商品資料
  final Map<String, List<StoreItem>> items = {};
  final Map<String, bool> purchasedItems = {};
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _currentUser = await UserService.getCurrentUserData();
    await _loadPurchasedItems();
    await _loadStoreItems();
    // 確保 UI 更新
    setState(() {});
  }

  Future<void> _loadStoreItems() async {
    final allItems = await DataService.getStoreItems();
    
    // 清空現有資料
    items.clear();
    
    // 按類別分組商品
    for (final item in allItems) {
      if (!items.containsKey(item.category)) {
        items[item.category] = [];
      }
      items[item.category]!.add(item);
    }
  }

  Future<void> _loadPurchasedItems() async {
    if (_currentUser == null) return;
    
    final username = _currentUser!['username'] ?? 'default';
    final purchasedItemIds = await DataService.getPurchasedItems(username);
    
    for (final itemId in purchasedItemIds) {
      purchasedItems[itemId] = true;
    }
  }

  // 新增：購買確認對話框
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
      // 執行購買邏輯
      await _buyItem(
        product['category'] ?? '',
        product['id'] ?? '',
        product['name'] ?? '',
        product['price'] ?? 0,
      );
    }
  }

  // 新增：構建 Firebase 商品卡片
  Widget _buildFirebaseProductCard(Map<String, dynamic> product) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: product['imageUrl'] != null
            ? Image.network(
                product['imageUrl'], 
                width: 60, 
                height: 60, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    categoryIcons[product['category']] ?? Icons.image_not_supported, 
                    size: 60,
                    color: Colors.grey.shade400,
                  );
                },
              )
            : Icon(
                categoryIcons[product['category']] ?? Icons.image_not_supported, 
                size: 60,
                color: Colors.grey.shade400,
              ),
        title: Text(product['name'] ?? ''),
        subtitle: Text('價格: ${product['price']}  稀有度: ${product['rarity']}'),
        trailing: ElevatedButton(
          onPressed: () => _showPurchaseDialog(context, product),
          child: const Text('購買'),
        ),
      ),
    );
  }

  // 新增：構建 Firebase 商品列表
  Widget _buildFirebaseProductList(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(category).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('載入資料錯誤'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
              ],
            ),
          );
        }

        final products = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // 添加文檔 ID 和類別信息
          data['id'] = doc.id;
          data['category'] = category;
          return data;
        }).toList();

        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) => _buildFirebaseProductCard(products[index]),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _buyItem(String category, String itemId, String itemName, int price) async {
    if (_currentUser == null) return;
    
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

    final success = await CoinService.deductCoins(price);
    if (success) {
      // 使用 DataService 添加已購買商品
      final username = _currentUser!['username'] ?? 'default';
      await DataService.addPurchasedItem(username, itemId);
      
      setState(() {
        purchasedItems[itemId] = true;
      });
      
      // 刷新金幣顯示
      _coinDisplayKey.currentState?.refreshCoins();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('購買成功！$itemName 已加入收藏'),
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
            // 自定義 AppBar
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
                  // 標籤欄
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
            // 內容區域
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: categories.map((category) {
                  final categoryItems = items[category] ?? [];

                  // 如果本地數據為空，使用 Firebase 數據
                  if (categoryItems.isEmpty) {
                    return _buildFirebaseProductList(category);
                  }

                  // 否則使用本地數據
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      itemCount: categoryItems.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemBuilder: (context, index) {
                        final item = categoryItems[index];
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      Colors.grey.shade50,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // 商品圖片區域
                                    Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(20),
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
                                            child: item.imagePath != null
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.file(
                                                      File(item.imagePath!),
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Icon(
                                                          categoryIcons[item.category] ?? Icons.shopping_bag,
                                                          size: 48,
                                                          color: Colors.blue.shade600,
                                                        );
                                                      },
                                                    ),
                                                  )
                                                : Icon(
                                                    categoryIcons[item.category] ?? Icons.shopping_bag,
                                                    size: 48,
                                                    color: Colors.blue.shade600,
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
                                                color: _getRarityColor(item.rarity),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                item.rarity,
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
                                    // 商品資訊
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.description,
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
                                                  '${item.price}',
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
                                              child: purchasedItems[item.id] == true
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
                                                      onPressed: () => _buyItem(
                                                        category,
                                                        item.id,
                                                        item.name,
                                                        item.price,
                                                      ),
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
                          },
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
