import 'package:flutter/material.dart';
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
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final success = await UserService.loginUser(username, password);
    if (success) {
      if (mounted) {
        // 檢查是否為首次登入
        final isFirstLogin = await UserService.isUserFirstLogin(username);
        if (isFirstLogin) {
          // 首次登入跳轉到歡迎頁面
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const WelcomePage()),
          );
        } else {
          // 非首次登入直接跳轉到聊天頁面
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ChatPage()),
          );
        }
      }
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('登入失敗'),
          content: const Text('帳號或密碼錯誤'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('確定'),
            )
          ],
        ),
      );
    }
  }

  void _goToRegister() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
    if (result == true) {
      // 註冊成功自動填入帳號
      setState(() {
        _usernameController.text = '';
        _passwordController.text = '';
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登入')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: '帳號'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密碼'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('登入'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _goToRegister,
              child: const Text('沒有帳號？前往註冊'),
            ),
          ],
        ),
      ),
    );
  }
}
