import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'register_page.dart';
import 'welcome_page.dart';
import 'user_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _login() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    _showErrorDialog('請輸入電子郵件與密碼');
    return;
  }

    if (!mounted) return;

  setState(() {
    _isLoading = true;
  });

  try {
    // 使用 Firebase Auth 進行登入
    UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // 登入成功！
    
    if (!mounted) return;

    // 檢查是否為首次登入
    final user = userCredential.user;
    if (user != null) {
      final creationTime = user.metadata.creationTime;
      final lastSignInTime = user.metadata.lastSignInTime;
      final isFirstLogin = creationTime == lastSignInTime;

      if (isFirstLogin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChatPage()),
        );
      }
    }
  } on FirebaseAuthException catch (e) {
    String message = '登入失敗，請稍後再試';
    if (e.code == 'user-not-found' || e.code == 'wrong-password') {
      message = '帳號或密碼錯誤';
      } else if (e.code == 'invalid-email') {
        message = '電子郵件格式不正確';
      } else if (e.code == 'user-disabled') {
        message = '帳號已被停用';
      } else if (e.code == 'too-many-requests') {
        message = '登入嘗試次數過多，請稍後再試';
    }
    _showErrorDialog(message);
  } catch (e) {
    _showErrorDialog('發生錯誤: $e');
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
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('請先輸入電子郵件地址');
      return;
    }

    try {
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
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.blue.shade600,
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

                  // 電子郵件輸入框
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '電子郵件',
                      hintText: '請輸入您的電子郵件',
                      prefixIcon: const Icon(Icons.email),
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
