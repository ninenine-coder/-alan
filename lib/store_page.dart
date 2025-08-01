import 'package:flutter/material.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> categories = ['造型', '裝飾', '語氣', '動作', '飼料'];

  // 模擬每類商品資料 (十個)
  final Map<String, List<Map<String, dynamic>>> items = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);

    for (var category in categories) {
      items[category] = List.generate(10, (index) {
        return {
          'id': '$category-$index',
          'name': '$category 項目${index + 1}',
          'price': (index + 1) * 100,
          'image': Icons.ac_unit, // 占位圖示，請換成模型圖片或資源
        };
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _buyItem(String category, String itemName, int price) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('購買 $category 的 $itemName，花費 $price 金幣'),
      duration: const Duration(seconds: 2),
    ));
    // TODO: 後續可加入扣款及購買邏輯
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商城'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: categories.map((category) {
          final categoryItems = items[category]!;
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: GridView.builder(
              itemCount: categoryItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final item = categoryItems[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item['image'], size: 64, color: Colors.blueAccent),
                      const SizedBox(height: 8),
                      Text(
                        item['name'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('價格：${item['price']}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _buyItem(category, item['name'], item['price']),
                        child: const Text('購買'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
