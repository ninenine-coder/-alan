import 'package:flutter/material.dart';
import 'user_service.dart';
import 'subscription_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final userData = await UserService.getCurrentUserData();
    setState(() {
      _currentUser = userData;
    });
    
    // 初始化用戶為免費版（如果還沒有訂閱狀態）
    if (userData != null) {
      try {
        await SubscriptionService.initializeAsFreeUser();
      } catch (e) {
        // 忽略錯誤，因為可能已經有訂閱狀態
      }
    }
  }

  void _upgradeToPremium() async {
    try {
      await SubscriptionService.upgradeToPremium();
      _showSuccessDialog('升級成功！', '您已成功升級為 Premium 用戶，現在可以享受桌寵功能了！');
    } catch (e) {
      _showErrorDialog('升級失敗', '升級過程中發生錯誤，請稍後再試。');
    }
  }

  void _startFreeTrial() async {
    try {
      final hasStartedTrial = await SubscriptionService.hasStartedTrial();
      if (hasStartedTrial) {
        _showErrorDialog('試用已開始', '您已經開始過免費試用，無法重複開始。');
        return;
      }

      await SubscriptionService.startFreeTrial();
      _showSuccessDialog('試用開始！', '您已成功開始 6 個月免費試用，現在可以享受桌寵功能了！');
    } catch (e) {
      _showErrorDialog('試用失敗', '開始試用過程中發生錯誤，請稍後再試。');
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/chat');
              },
              child: const Text('開始使用'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red.shade600),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 主要內容
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade400,
                  Colors.blue.shade800,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // 歡迎標題
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.psychology,
                            size: 100,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '歡迎來到捷米小助手！',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          if (_currentUser != null)
                            Text(
                              '${_currentUser!['username'] ?? 'User'}',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 功能介紹
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildFeatureCard(
                            icon: Icons.chat_bubble,
                            title: '智能對話',
                            description: '與AI助手進行自然對話，獲得幫助和建議',
                          ),
                          const SizedBox(height: 15),
                          _buildFeatureCard(
                            icon: Icons.pets,
                            title: '桌寵功能',
                            description: 'Premium專屬：與可愛的桌寵互動，享受陪伴樂趣',
                            isPremium: true,
                          ),
                          const SizedBox(height: 15),
                          _buildFeatureCard(
                            icon: Icons.school,
                            title: '學習輔助',
                            description: '學習建議和知識分享，助您持續成長',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 按鈕區域
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // 升級成 Premium 按鈕
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _upgradeToPremium,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 5,
                            ),
                            child: const Text(
                              '升級成 Premium',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        // 免費體驗六個月按鈕
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: OutlinedButton(
                            onPressed: _startFreeTrial,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              '免費體驗六個月',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    bool isPremium = false,
  }) {
          return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPremium 
              ? Colors.amber.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isPremium 
                ? Colors.amber.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.2),
            width: isPremium ? 2 : 1,
          ),
        ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              icon,
              color: isPremium ? Colors.amber.shade300 : Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPremium ? Colors.amber.shade300 : Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
