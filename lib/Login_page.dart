import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_page.dart';
import 'register_page.dart';
import 'welcome_page.dart';
import 'user_service.dart';
import 'data_service.dart';
import 'logger_service.dart';
import 'experience_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 獲取選擇的造型圖片
  Future<String?> _getSelectedStyleImage() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return null;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      final selectedImage = prefs.getString('selected_style_image_$username');
      
      // 如果沒有選擇的造型，返回經典捷米的圖片
      if (selectedImage == null || selectedImage.isEmpty) {
        return 'https://i.postimg.cc/vmzwkwzg/image.jpg'; // 經典捷米圖片
      }
      
      return selectedImage;
    } catch (e) {
      LoggerService.error('Error getting selected style image: $e');
      return 'https://i.postimg.cc/vmzwkwzg/image.jpg'; // 經典捷米圖片作為預設
    }
  }

Future<void> _login() async {
  final username = _usernameController.text.trim();
  final password = _passwordController.text.trim();

  if (username.isEmpty || password.isEmpty) {
    _showErrorDialog('請輸入用戶名與密碼');
    return;
  }

    if (!mounted) return;

  setState(() {
    _isLoading = true;
  });

  // 在異步操作前保存 Navigator
  final navigator = Navigator.of(context);

  try {
    // 使用用戶名進行登入
    final userData = await UserService.loginUserWithUsername(
      username: username,
      password: password,
    );

    if (userData == null) {
      _showErrorDialog('用戶名或密碼錯誤');
      return;
    }
    
    // 登入成功！
    
    if (!mounted) return;

    // 載入所有用戶數據
    try {
      LoggerService.info('開始載入用戶數據');
      await DataService.loadAllDataFromFirestore();
      LoggerService.info('用戶數據載入完成');
    } catch (e) {
      LoggerService.error('載入用戶數據時發生錯誤: $e');
    }

    // 記錄登入時間（用於經驗值計算）
    try {
      await ExperienceService.recordLoginTime();
      LoggerService.info('登入時間已記錄');
    } catch (e) {
      LoggerService.error('記錄登入時間時發生錯誤: $e');
    }

    // 檢查是否為首次登入
    final loginCount = userData['loginCount'] ?? 0;
    final isFirstLogin = loginCount <= 1;

    if (mounted) {
      if (isFirstLogin) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
      } else {
        navigator.pushReplacementNamed('/chat');
      }
    }
  } catch (e) {
    _showErrorDialog('登入失敗，請稍後再試');
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('登入失敗'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          )
        ],
      ),
    );
  }

  void _goToRegister() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
    if (result == true && mounted) {
      // 註冊成功，可以顯示成功訊息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('註冊成功！請使用新帳號登入'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _forgotPassword() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showErrorDialog('請先輸入用戶名');
      return;
    }

    try {
      // 根據用戶名查找電子郵件
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showErrorDialog('找不到該用戶名');
        return;
      }

      final userData = userQuery.docs.first.data();
      final email = userData['email'] as String?;

      if (email == null) {
        _showErrorDialog('找不到該用戶的電子郵件');
        return;
      }

      final success = await UserService.resetPassword(email);
      if (!mounted) return;
      
      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('重設密碼'),
            content: Text('重設密碼連結已發送到 $email'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('確定'),
              )
            ],
          ),
        );
      } else {
        _showErrorDialog('發送重設密碼郵件失敗');
      }
    } catch (e) {
      _showErrorDialog('發生錯誤: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo 或標題
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: FutureBuilder<String?>(
                      future: _getSelectedStyleImage(),
                      builder: (context, snapshot) {
                        final imageUrl = snapshot.data;
                        if (imageUrl != null && imageUrl.isNotEmpty) {
                          return ClipOval(
                            child: Image.network(
                              imageUrl,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.pets,
                                  size: 60,
                                  color: Colors.blue.shade600,
                                );
                              },
                            ),
                          );
                        } else {
                          return Icon(
                            Icons.pets,
                            size: 60,
                            color: Colors.blue.shade600,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // 標題
                  const Text(
                    '歡迎回來',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '請登入您的帳號',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 用戶名輸入框
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: '用戶名',
                      hintText: '請輸入您的用戶名',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 密碼輸入框
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密碼',
                      hintText: '請輸入您的密碼',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 忘記密碼連結
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: Text(
                        '忘記密碼？',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 登入按鈕
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '登入',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 註冊連結
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '還沒有帳號？',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      TextButton(
                        onPressed: _goToRegister,
                        child: Text(
                          '立即註冊',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
