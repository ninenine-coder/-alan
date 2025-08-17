import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
          // 背包項目
          _buildBackpackItem('裝備', Icons.shield),
          const SizedBox(height: 12),
          _buildBackpackItem('頭像', Icons.face),
        ],
      ),
    );
  }

  Widget _buildBackpackItem(String title, IconData icon) {
    return GestureDetector(
      onTap: () {
        // 處理背包項目點擊
        if (title == '裝備') {
          // 導航到裝備頁面
          Navigator.pushNamed(context, '/equipment');
        } else if (title == '頭像') {
          // 導航到頭像頁面
          Navigator.pushNamed(context, '/avatar');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        child: Row(
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
            const SizedBox(width: 12),
            // 標題
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            // 箭頭圖標
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }




}
