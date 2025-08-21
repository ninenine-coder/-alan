import 'package:flutter/material.dart';
import 'theme_background_service.dart';
import 'coin_display.dart';
import 'logger_service.dart';

class ThemeBackgroundPage extends StatefulWidget {
  const ThemeBackgroundPage({super.key});

  @override
  State<ThemeBackgroundPage> createState() => _ThemeBackgroundPageState();
}

class _ThemeBackgroundPageState extends State<ThemeBackgroundPage> {
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();
  String? _currentTheme;
  List<String> _ownedThemes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentTheme = await ThemeBackgroundService.getCurrentThemeBackground();
      final ownedThemes = await ThemeBackgroundService.getUserOwnedThemes();

      setState(() {
        _currentTheme = currentTheme;
        _ownedThemes = ownedThemes;
        _isLoading = false;
      });
    } catch (e) {
      LoggerService.error('Error loading theme data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectTheme(String themeId) async {
    try {
      final success = await ThemeBackgroundService.setThemeBackground(themeId);
      if (success) {
        setState(() {
          _currentTheme = themeId;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('主題背景已更新'),
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('更新主題背景失敗'),
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
    } catch (e) {
      LoggerService.error('Error selecting theme: $e');
    }
  }

  Future<void> _purchaseTheme(String themeId) async {
    try {
      final success = await ThemeBackgroundService.purchaseThemeBackground(themeId);
      if (success) {
        // 重新載入數據
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.shopping_cart, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('主題背景購買成功！'),
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

        // 刷新金幣顯示
        _coinDisplayKey.currentState?.refreshCoins();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('購買失敗，請稍後再試'),
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
    } catch (e) {
      LoggerService.error('Error purchasing theme: $e');
    }
  }

  Widget _buildThemeCard(String themeId) {
    final theme = ThemeBackgroundService.getThemeBackground(themeId);
    if (theme == null) return const SizedBox.shrink();

    final isOwned = _ownedThemes.contains(themeId);
    final isSelected = _currentTheme == themeId;
    final isFree = theme.isFree;

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: isSelected ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Colors.blue.shade400 : Colors.transparent,
          width: isSelected ? 3 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主題預覽圖片
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Image.network(
                    theme.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: ThemeBackgroundService.getThemeGradientColors(themeId),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: ThemeBackgroundService.getThemeGradientColors(themeId),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.error, size: 50, color: Colors.white),
                    ),
                  ),
                  // 選中標記
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  // 擁有標記
                  if (isOwned && !isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 主題信息
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        theme.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFree ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        theme.priceText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isFree ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  theme.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // 操作按鈕
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isOwned
                        ? () => _selectTheme(themeId)
                        : () => _purchaseTheme(themeId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOwned
                          ? (isSelected ? Colors.blue.shade600 : Colors.green.shade600)
                          : Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isOwned
                          ? (isSelected ? '使用中' : '使用')
                          : '購買',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allThemes = ThemeBackgroundService.getAllThemeBackgrounds();

    return Scaffold(
      appBar: AppBar(
        title: const Text('主題背景'),
        centerTitle: true,
        actions: [
          CoinDisplay(key: _coinDisplayKey),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: allThemes.length,
                itemBuilder: (context, index) {
                  final themeId = allThemes.keys.elementAt(index);
                  return _buildThemeCard(themeId);
                },
              ),
            ),
    );
  }
}
