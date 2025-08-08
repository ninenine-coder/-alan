import 'package:flutter/material.dart';
import 'user_service.dart';
import 'data_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (username.isEmpty || password.isEmpty || email.isEmpty || phone.isEmpty) {
      _showDialog('請完整填寫所有欄位');
      return;
    }
    setState(() { _isLoading = true; });
    final success = await UserService.registerUser(username, password, phone);
    if (success) {
      // 更新電子郵件到管理者資料庫
      final userData = {
        'username': username,
        'email': email,
        'registrationDate': DateTime.now().toIso8601String(),
        'lastLoginDate': null,
        'loginCount': 0,
        'coins': 100,
        'purchasedItems': [],
        'earnedMedals': [],
      };
      await DataService.saveUserData(username, userData);
      
      setState(() { _isLoading = false; });
      if (mounted) {
        Navigator.pop(context, true); // 返回登入頁
      }
    } else {
      setState(() { _isLoading = false; });
      _showDialog('帳號已存在，請更換帳號');
    }
  }

  void _showDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('註冊失敗'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊')),
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
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '電子郵件'),
            ),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手機號碼'),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register,
                    child: const Text('註冊'),
                  ),
          ],
        ),
      ),
    );
  }
}