import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'data_service.dart';

class User {
  final String username;
  final String password;
  final String phoneNumber;
  final DateTime createdAt;

  User({
    required this.username,
    required this.password,
    required this.phoneNumber,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      password: json['password'],
      phoneNumber: json['phoneNumber'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class UserService {
  static const String _usersKey = 'users';
  static const String _currentUserKey = 'current_user';

  // 獲取用戶特定的存儲鍵
  static String _getUserKey(String username, String key) {
    return '${username}_$key';
  }

  // 註冊新用戶
  static Future<bool> registerUser(String username, String password, String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 獲取現有用戶列表
    final usersJson = prefs.getStringList(_usersKey) ?? [];
    final users = usersJson.map((json) => User.fromJson(jsonDecode(json))).toList();
    
    // 檢查用戶名是否已存在
    if (users.any((user) => user.username == username)) {
      return false; // 用戶名已存在
    }
    
    // 創建新用戶
    final newUser = User(
      username: username,
      password: password,
      phoneNumber: phoneNumber,
      createdAt: DateTime.now(),
    );
    
    // 添加到用戶列表
    users.add(newUser);
    
    // 保存到本地存儲
    final updatedUsersJson = users.map((user) => jsonEncode(user.toJson())).toList();
    await prefs.setStringList(_usersKey, updatedUsersJson);
    
    // 同時保存到管理者資料庫
    final userData = {
      'username': username,
      'email': '$username@example.com', // 使用預設郵箱
      'registrationDate': DateTime.now().toIso8601String(),
      'lastLoginDate': null,
      'loginCount': 0,
      'coins': 100, // 新用戶預設100金幣
      'purchasedItems': [],
      'earnedMedals': [],
    };
    
    await DataService.saveUserData(username, userData);
    
    return true; // 註冊成功
  }

  // 用戶登入
  static Future<bool> loginUser(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 獲取用戶列表
    final usersJson = prefs.getStringList(_usersKey) ?? [];
    final users = usersJson.map((json) => User.fromJson(jsonDecode(json))).toList();
    
    // 查找用戶
    final user = users.firstWhere(
      (user) => user.username == username && user.password == password,
      orElse: () => User(username: '', password: '', phoneNumber: '', createdAt: DateTime.now()),
    );
    
    if (user.username.isNotEmpty) {
      // 登入成功，保存當前用戶信息
      await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
      
      // 更新管理者資料庫中的登入信息
      await DataService.updateUserLoginInfo(username);
      
      return true;
    }
    
    return false; // 登入失敗
  }

  // 獲取當前登入用戶
  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);
    
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    
    return null;
  }

  // 登出
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  // 檢查用戶名是否已存在
  static Future<bool> isUsernameExists(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getStringList(_usersKey) ?? [];
    final users = usersJson.map((json) => User.fromJson(jsonDecode(json))).toList();
    
    return users.any((user) => user.username == username);
  }

  // 獲取所有用戶（用於調試）
  static Future<List<User>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getStringList(_usersKey) ?? [];
    return usersJson.map((json) => User.fromJson(jsonDecode(json))).toList();
  }

  // 檢查用戶是否為首次登入
  static Future<bool> isUserFirstLogin(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final firstLoginKey = _getUserKey(username, 'first_login');
    return prefs.getBool(firstLoginKey) ?? true;
  }

  // 標記用戶已登入
  static Future<void> markUserAsLoggedIn(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final firstLoginKey = _getUserKey(username, 'first_login');
    await prefs.setBool(firstLoginKey, false);
  }

  // 獲取用戶特定的聊天記錄鍵
  static String getChatMessagesKey(String username) {
    return _getUserKey(username, 'chat_messages');
  }

  // 獲取用戶特定的AI名稱鍵
  static String getAiNameKey(String username) {
    return _getUserKey(username, 'ai_name');
  }

  // 獲取用戶特定的金幣鍵
  static String getCoinsKey(String username) {
    return _getUserKey(username, 'coins');
  }

  // 獲取用戶特定的已購買物品鍵
  static String getPurchasedItemsKey(String username) {
    return _getUserKey(username, 'purchased_items');
  }
} 