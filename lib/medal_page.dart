import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'logger_service.dart';
import 'theme_background_widget.dart';
import 'user_inventory_service.dart';

class MedalPage extends StatefulWidget {
  const MedalPage({super.key});

  @override
  State<MedalPage> createState() => _MedalPageState();
}

class _MedalPageState extends State<MedalPage> with TickerProviderStateMixin {
  String? _selectedFilter;
  final List<String> _filterOptions = ['全部', '一般', '史詩', '稀有'];
  
  // 特效動畫控制器
  late AnimationController _sparkleController;
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  
  // 特效動畫
  late Animation<double> _sparkleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // 初始化閃爍特效
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );

    // 初始化發光特效
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // 初始化脈衝特效
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 初始化旋轉特效
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // 開始動畫循環
    _startAnimationLoop();
  }

  void _startAnimationLoop() {
    _sparkleController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ThemeBackgroundListener(
        overlayColor: Colors.white,
        overlayOpacity: 0.3,
        child: SafeArea(
          child: Column(
            children: [
              _buildStatusBar(),
              _buildHeaderSection(),
              Expanded(child: _buildMedalList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
              child: Icon(Icons.arrow_back_ios, size: 18, color: Colors.blue[600]),
            ),
          ),
          const SizedBox(width: 12),
          Text('10:31', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[800])),
          const Spacer(),
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



  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('收集徽章，展現成就！', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                final isSelected = _selectedFilter == option || (_selectedFilter == null && index == 0);
                return Container(
                  margin: EdgeInsets.only(right: index < _filterOptions.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue[600] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(option, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedalList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getMedals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text('載入失敗', style: TextStyle(fontSize: 18, color: Colors.red.shade600)),
                const SizedBox(height: 8),
                Text('請檢查網路連線', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        final medals = snapshot.data ?? [];

        if (medals.isEmpty) {
          return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('暫無徽章', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('完成任務來獲得徽章吧！', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: medals.length,
          itemBuilder: (context, index) => _buildMedalCard(medals[index]),
        );
      },
    );
  }

  Widget _buildMedalCard(Map<String, dynamic> medal) {
    final name = medal['name'] ?? '未命名徽章';
    final imageUrl = medal['圖片'] ?? medal['imageUrl'] ?? '';
    final rarity = medal['稀有度'] ?? medal['rarity'] ?? '普通';
    final isObtained = medal['status'] == '已獲得' || medal['isObtained'] == true;
    final isRareAndObtained = rarity == '稀有' && isObtained;
    final isEpicAndObtained = rarity == '史詩' && isObtained;
    final isLegendaryAndObtained = rarity == '傳說' && isObtained;
    
    return GestureDetector(
      onTap: () => _showMedalDetail(medal),
      child: Stack(
        children: [
          Card(
        elevation: isObtained ? 8 : 2,
        shadowColor: isObtained ? Colors.amber.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
        color: isObtained ? Colors.white : Colors.grey.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isObtained 
              ? BorderSide(color: Colors.amber.shade300, width: 2)
              : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    colors: isObtained 
                        ? [Colors.amber.shade50, Colors.amber.shade100, Colors.amber.shade200]
                        : [Colors.grey.shade200, Colors.grey.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: isObtained ? [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Stack(
                    children: [
                      // 已獲得徽章的發光效果
                      if (isObtained)
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.amber.withValues(alpha: 0.1),
                                Colors.transparent,
                              ],
                              center: Alignment.center,
                              radius: 0.8,
                            ),
                          ),
                        ),
                      imageUrl.isNotEmpty && imageUrl != '""'
                          ? Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              color: isObtained ? null : Colors.grey.shade400,
                              colorBlendMode: isObtained ? null : BlendMode.saturation,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
                              },
                              errorBuilder: (context, error, stackTrace) => _buildNoImagePlaceholder(),
                            )
                          : _buildNoImagePlaceholder(),
                      // 稀有度標籤
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getRarityColor(rarity).withValues(alpha: isObtained ? 0.9 : 0.7),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isObtained ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ] : null,
                          ),
                          child: Text(
                            rarity, 
                style: TextStyle(
                              color: Colors.white, 
                              fontSize: 8, 
                  fontWeight: FontWeight.bold,
                              shadows: isObtained ? [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  offset: const Offset(0, 1),
                                  blurRadius: 1,
                                ),
                              ] : null,
                            ),
                          ),
                        ),
                      ),
                      // 未獲得標籤
                      if (!isObtained)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                              color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                            child: const Text(
                              '未獲得', 
                              style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // 已獲得標籤
                      if (isObtained)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Text(
                              '已獲得', 
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 8, 
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(0, 1),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
            ],
          ),
        ),
              ),
            ),
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
                    color: isObtained ? Colors.black87 : Colors.grey.shade600,
                    shadows: isObtained ? [
                      Shadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ] : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                                 ),
               ),
             ),
           ],
         ),
       ),
           // 稀有徽章特效 - 藍色閃爍和發光
           if (isRareAndObtained) ...[
             // 閃爍特效
             Positioned.fill(
               child: AnimatedBuilder(
                 animation: _sparkleAnimation,
                 builder: (context, child) {
                   return CustomPaint(
                     painter: SparklePainter(
                       animation: _sparkleAnimation.value,
                       color: Colors.blue.shade400,
                     ),
                   );
                 },
               ),
             ),
             // 發光特效
             Positioned.fill(
               child: AnimatedBuilder(
                 animation: _glowAnimation,
                 builder: (context, child) {
                   return Container(
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(12),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.blue.withValues(alpha: _glowAnimation.value * 0.3),
                           blurRadius: 15,
                           spreadRadius: 2,
                         ),
                       ],
                     ),
                   );
                 },
               ),
             ),
           ],
           
           // 史詩徽章特效 - 橙色脈衝和旋轉
           if (isEpicAndObtained) ...[
             // 脈衝特效
             Positioned.fill(
               child: AnimatedBuilder(
                 animation: _pulseAnimation,
                 builder: (context, child) {
                   return Transform.scale(
                     scale: _pulseAnimation.value,
                     child: Container(
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(
                           color: Colors.orange.withValues(alpha: 0.5),
                           width: 2,
                         ),
                       ),
                     ),
                   );
                 },
               ),
             ),
             // 旋轉光環特效
             Positioned.fill(
               child: AnimatedBuilder(
                 animation: _rotateAnimation,
                 builder: (context, child) {
                   return Transform.rotate(
                     angle: _rotateAnimation.value * 2 * 3.14159,
                     child: Container(
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(12),
                         gradient: SweepGradient(
                           colors: [
                             Colors.orange.withValues(alpha: 0.0),
                             Colors.orange.withValues(alpha: 0.4),
                             Colors.orange.withValues(alpha: 0.0),
                           ],
                           stops: const [0.0, 0.5, 1.0],
                         ),
                       ),
                     ),
                   );
                 },
               ),
             ),
           ],
           
           // 傳說徽章特效 - 紫色多重特效
           if (isLegendaryAndObtained) ...[
             // 閃爍特效
             Positioned.fill(
               child: AnimatedBuilder(
                 animation: _sparkleAnimation,
                 builder: (context, child) {
                   return CustomPaint(
                     painter: SparklePainter(
                       animation: _sparkleAnimation.value,
                       color: Colors.purple.shade400,
                     ),
                   );
                 },
               ),
             ),
             // 發光特效
             Positioned.fill(
               child: AnimatedBuilder(
                 animation: _glowAnimation,
                 builder: (context, child) {
                   return Container(
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(12),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.purple.withValues(alpha: _glowAnimation.value * 0.4),
                           blurRadius: 20,
                           spreadRadius: 3,
                         ),
                       ],
                     ),
                   );
                 },
               ),
             ),
             // 脈衝特效
             Positioned.fill(
               child: AnimatedBuilder(
                 animation: _pulseAnimation,
                 builder: (context, child) {
                   return Transform.scale(
                     scale: _pulseAnimation.value,
                     child: Container(
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(
                           color: Colors.purple.withValues(alpha: 0.6),
                           width: 3,
                         ),
                       ),
                     ),
                   );
                 },
               ),
             ),
             // 旋轉光環特效
             Positioned.fill(
               child: AnimatedBuilder(
                 animation: _rotateAnimation,
                 builder: (context, child) {
                   return Transform.rotate(
                     angle: _rotateAnimation.value * 2 * 3.14159,
                     child: Container(
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(12),
                         gradient: SweepGradient(
                           colors: [
                             Colors.purple.withValues(alpha: 0.0),
                             Colors.purple.withValues(alpha: 0.5),
                             Colors.purple.withValues(alpha: 0.0),
                           ],
                           stops: const [0.0, 0.5, 1.0],
                         ),
                       ),
                     ),
                   );
                 },
               ),
             ),
           ],
         ],
       ),
     );
   }

  Widget _buildNoImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text('無圖片', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case '傳說': return Colors.purple;
      case '史詩': return Colors.orange;
      case '稀有': return Colors.blue;
      case '普通': return Colors.green;
      default: return Colors.grey;
    }
  }

  int _getRarityValue(String rarity) {
    switch (rarity) {
      case '傳說': return 4;
      case '史詩': return 3;
      case '稀有': return 2;
      case '普通': return 1;
      default: return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _getMedals() async {
    try {
      // 使用 UserInventoryService 獲取用戶的徽章數據
      final medals = await UserInventoryService.getUserCategoryItems('徽章');
      
      if (_selectedFilter != null && _selectedFilter != '全部') {
        if (_selectedFilter == '一般') {
          medals.removeWhere((medal) => medal['稀有度'] != '一般' && medal['稀有度'] != '普通');
        } else if (_selectedFilter == '史詩') {
          medals.removeWhere((medal) => medal['稀有度'] != '史詩');
        } else if (_selectedFilter == '稀有') {
          medals.removeWhere((medal) => medal['稀有度'] != '稀有');
        }
      }
      
      // 排序：已獲得的徽章在前，未獲得的在後
      // 在已獲得和未獲得的分組內，按稀有度排序
      medals.sort((a, b) {
        final aObtained = a['status'] == '已獲得';
        final bObtained = b['status'] == '已獲得';
        
        // 首先按獲得狀態排序
        if (aObtained && !bObtained) return -1;
        if (!aObtained && bObtained) return 1;
        
        // 如果獲得狀態相同，按稀有度排序
        if (aObtained == bObtained) {
          final aRarity = a['稀有度'] as String;
          final bRarity = b['稀有度'] as String;
          final aRarityValue = _getRarityValue(aRarity);
          final bRarityValue = _getRarityValue(bRarity);
          
          // 已獲得的徽章按稀有度從高到低排序
          if (aObtained) {
            return bRarityValue.compareTo(aRarityValue);
          }
          // 未獲得的徽章也按稀有度從高到低排序
          else {
            return bRarityValue.compareTo(aRarityValue);
          }
        }
        
        return 0;
      });
      
      return medals;
    } catch (e) {
      LoggerService.error('Error getting medals: $e');
      return [];
    }
  }

  void _showMedalDetail(Map<String, dynamic> medal) {
    final name = medal['name'] ?? '未命名徽章';
    final imageUrl = medal['圖片'] ?? medal['imageUrl'] ?? '';
    final rarity = medal['稀有度'] ?? medal['rarity'] ?? '普通';
    final requirement = medal['達成條件'] ?? medal['requirement'] ?? '未知條件';
    final isObtained = medal['isObtained'] as bool? ?? false;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber[600], size: 24),
                    const SizedBox(width: 8),
                    const Text('徽章詳情', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: isObtained ? [Colors.amber.shade100, Colors.amber.shade200] : [Colors.grey.shade200, Colors.grey.shade300],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          imageUrl.isNotEmpty && imageUrl != '""'
                              ? Image.network(
                                  imageUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  color: isObtained ? null : Colors.grey.shade400,
                                  colorBlendMode: isObtained ? null : BlendMode.saturation,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
                                  },
                                  errorBuilder: (context, error, stackTrace) => _buildNoImagePlaceholder(),
                                )
                              : _buildNoImagePlaceholder(),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _getRarityColor(rarity).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                              child: Text(rarity, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _getRarityColor(rarity).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text('稀有度：$rarity', style: TextStyle(color: _getRarityColor(rarity), fontSize: 14, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                                const SizedBox(width: 8),
                                const Text('達成條件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(requirement, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
                  ),
                ),
    );
      },
    );
  }
}

// 閃爍特效繪製器
class SparklePainter extends CustomPainter {
  final double animation;
  final Color color;

  SparklePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: (0.3 + 0.7 * animation).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    final sparkleCount = 8;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.3;

    for (int i = 0; i < sparkleCount; i++) {
      final angle = (i * 2 * 3.14159 / sparkleCount) + (animation * 2 * 3.14159);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      final sparkleSize = 3.0 + 2.0 * animation;
      canvas.drawCircle(Offset(x, y), sparkleSize, paint);
    }
  }

  @override
  bool shouldRepaint(SparklePainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.color != color;
  }
}
