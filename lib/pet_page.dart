import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'coin_display.dart';
import 'user_service.dart';
import 'data_service.dart';
import 'challenge_service.dart';

class PetPage extends StatefulWidget {
  final String initialPetName;

  const PetPage({super.key, required this.initialPetName});

  @override
  State<PetPage> createState() => _PetPageState();
}

class _PetPageState extends State<PetPage> {
  late TextEditingController _controller;
  late String petName;
  double experience = 0.65; // 65% 經驗
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();
  Map<String, List<StoreItem>> purchasedItemsByCategory = {};
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    petName = widget.initialPetName;
    _controller = TextEditingController(text: petName);
    _loadPetName();
    _loadPurchasedItems();
  }

  Future<void> _loadPetName() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final aiNameKey = UserService.getAiNameKey(currentUser.username);
    final savedName = prefs.getString(aiNameKey) ?? widget.initialPetName;
    setState(() {
      petName = savedName;
      _controller.text = petName;
    });
  }

  Future<void> _loadPurchasedItems() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;
    
    final purchasedItems = await DataService.getPurchasedItemsByCategory(currentUser.username);
    
    setState(() {
      purchasedItemsByCategory = purchasedItems;
    });
  }

  Future<void> _savePetName(String name) async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final aiNameKey = UserService.getAiNameKey(currentUser.username);
    await prefs.setString(aiNameKey, name);
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
      // 使用 debugPrint 替代 print
      debugPrint('Error handling pet interaction: $e');
    } finally {
      setState(() {
        _isInteracting = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的桌寵'),
        centerTitle: true,
        actions: [
          CoinDisplay(key: _coinDisplayKey),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // 上半部：桌寵 + 經驗條 + 命名
          Expanded(
            flex: 1,
            child: Column(
              children: [
                const SizedBox(height: 10),
                // 模型預留區
                Expanded(
                  child: GestureDetector(
                    onTap: _handlePetInteraction,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: _isInteracting ? Colors.blue.shade100 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isInteracting ? Colors.blue.shade300 : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isInteracting ? Icons.pets : Icons.pets_outlined,
                            size: 64,
                            color: _isInteracting ? Colors.blue.shade600 : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isInteracting ? '互動中...' : '點擊與桌寵互動',
                            style: TextStyle(
                              fontSize: 16,
                              color: _isInteracting ? Colors.blue.shade600 : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isInteracting) ...[
                            const SizedBox(height: 8),
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 經驗值條
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: experience,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade300,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 6),
                      Text('經驗值：${(experience * 100).toInt()}%'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 改名輸入欄
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '輸入桌寵名稱',
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: () async {
                    final newName = _controller.text.trim();
                    final navigatorContext = context;
                    if (newName.isNotEmpty) {
                      await _savePetName(newName); // 保存新名稱
                      setState(() {
                        petName = newName;
                      });
                      if (mounted) {
                        Navigator.pop(navigatorContext, newName); // 回傳新名字
                      }
                    } else {
                      if (mounted) {
                        Navigator.pop(navigatorContext);
                      }
                    }
                  },
                  child: const Text('確定'),
                ),

                const SizedBox(height: 10),

                Text('目前名稱：$petName'),
              ],
            ),
          ),

          const Divider(thickness: 1),

          // 下半部：收藏區
          Expanded(
            flex: 1,
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildCollectionCard('造型', Icons.brush),
                _buildCollectionCard('裝飾', Icons.emoji_objects),
                _buildCollectionCard('語氣', Icons.record_voice_over),
                _buildCollectionCard('動作', Icons.directions_run),
                _buildCollectionCard('飼料', Icons.fastfood),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(String title, IconData icon) {
    final items = purchasedItemsByCategory[title] ?? [];
    
    return GestureDetector(
      onTap: () {
        if (items.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showCategoryItems(title, items);
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.shade100),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: Colors.indigo),
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    '${items.length} 個已擁有',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.indigo.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // 如果有已購買的商品，顯示第一個商品的圖片作為預覽
            if (items.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade300, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: items.first.imagePath != null
                        ? Image.file(
                            File(items.first.imagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.indigo.shade100,
                                child: Icon(
                                  icon,
                                  size: 20,
                                  color: Colors.indigo.shade600,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.indigo.shade100,
                            child: Icon(
                              icon,
                              size: 20,
                              color: Colors.indigo.shade600,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCategoryItems(String category, List<StoreItem> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('我的$category'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade200),
                  color: Colors.indigo.shade50,
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              color: Colors.white,
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: item.imagePath != null
                                  ? Image.file(
                                      File(item.imagePath!),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.indigo.shade100,
                                          child: Icon(
                                            _getCategoryIcon(item.category),
                                            size: 32,
                                            color: Colors.indigo.shade600,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.indigo.shade100,
                                      child: Icon(
                                        _getCategoryIcon(item.category),
                                        size: 32,
                                        color: Colors.indigo.shade600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRarityColor(item.rarity),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.rarity,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 已擁有標籤
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '已擁有',
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
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '造型':
        return Icons.brush;
      case '裝飾':
        return Icons.emoji_objects;
      case '語氣':
        return Icons.record_voice_over;
      case '動作':
        return Icons.directions_run;
      case '飼料':
        return Icons.fastfood;
      default:
        return Icons.shopping_bag;
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
}
