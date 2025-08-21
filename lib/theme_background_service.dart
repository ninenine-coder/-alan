import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';

class ThemeBackgroundService {
  // 主題背景配置
  static const Map<String, ThemeBackground> _themeBackgrounds = {
    '主題1': ThemeBackground(
      id: '主題1',
      name: '經典桌布',
      description: '簡潔優雅的經典設計',
      imageUrl: '',
      category: '經典',
      price: 0, // 免費
      isDefault: true,
    ),
    '主題2': ThemeBackground(
      id: '主題2',
      name: '貓空纜車背景',
      description: '台北貓空纜車的壯麗景色',
      imageUrl: '',
      category: '風景',
      price: 100,
      isDefault: false,
    ),
    '主題3': ThemeBackground(
      id: '主題3',
      name: '捷運車廂背景',
      description: '現代化的捷運車廂內部',
      imageUrl: '',
      category: '交通',
      price: 150,
      isDefault: false,
    ),
    '主題4': ThemeBackground(
      id: '主題4',
      name: '台北101夜景',
      description: '台北101大樓的璀璨夜景',
      imageUrl: '',
      category: '夜景',
      price: 200,
      isDefault: false,
    ),
    '主題5': ThemeBackground(
      id: '主題5',
      name: '淡水夕陽',
      description: '淡水河畔的浪漫夕陽',
      imageUrl: '',
      category: '風景',
      price: 180,
      isDefault: false,
    ),
    '主題6': ThemeBackground(
      id: '主題6',
      name: '九份老街',
      description: '懷舊的九份山城風情',
      imageUrl: '',
      category: '文化',
      price: 120,
      isDefault: false,
    ),
    '主題7': ThemeBackground(
      id: '主題7',
      name: '陽明山花季',
      description: '陽明山櫻花盛開的美景',
      imageUrl: '',
      category: '自然',
      price: 160,
      isDefault: false,
    ),
    '主題8': ThemeBackground(
      id: '主題8',
      name: '象山夜景',
      description: '從象山俯瞰台北夜景',
      imageUrl: '',
      category: '夜景',
      price: 220,
      isDefault: false,
    ),
    '主題9': ThemeBackground(
      id: '主題9',
      name: '西門町街景',
      description: '熱鬧的西門町商圈',
      imageUrl: '',
      category: '都市',
      price: 90,
      isDefault: false,
    ),
    '主題10': ThemeBackground(
      id: '主題10',
      name: '北投溫泉',
      description: '北投溫泉區的寧靜氛圍',
      imageUrl: '',
      category: '休閒',
      price: 140,
      isDefault: false,
    ),
  };

  /// 獲取所有主題背景
  static Map<String, ThemeBackground> getAllThemeBackgrounds() {
    return _themeBackgrounds;
  }

  /// 獲取指定主題背景
  static ThemeBackground? getThemeBackground(String themeId) {
    return _themeBackgrounds[themeId];
  }

  /// 獲取用戶當前使用的主題背景
  static Future<String?> getCurrentThemeBackground() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return '主題1'; // 預設主題

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      final currentTheme = prefs.getString('current_theme_background_$username');
      
      return currentTheme ?? '主題1'; // 如果沒有設置，使用預設主題
    } catch (e) {
      LoggerService.error('Error getting current theme background: $e');
      return '主題1';
    }
  }

  /// 設置用戶的主題背景
  static Future<bool> setThemeBackground(String themeId) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      
      // 保存到本地
      await prefs.setString('current_theme_background_$username', themeId);
      
      // 同步到 Firebase
      await UserService.updateUserData({
        'currentThemeBackground': themeId,
        'lastThemeUpdate': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('Theme background set to: $themeId');
      return true;
    } catch (e) {
      LoggerService.error('Error setting theme background: $e');
      return false;
    }
  }

  /// 檢查用戶是否擁有指定主題背景
  static Future<bool> hasThemeBackground(String themeId) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;

      final purchasedItems = userData['purchasedItems'] as List<dynamic>? ?? [];
      return purchasedItems.contains(themeId);
    } catch (e) {
      LoggerService.error('Error checking theme background ownership: $e');
      return false;
    }
  }

  /// 購買主題背景
  static Future<bool> purchaseThemeBackground(String themeId) async {
    try {
      final theme = _themeBackgrounds[themeId];
      if (theme == null) return false;

      // 檢查是否已經擁有
      if (await hasThemeBackground(themeId)) {
        LoggerService.warning('User already owns theme: $themeId');
        return true; // 已經擁有，視為成功
      }

      // 檢查是否為免費主題
      if (theme.price == 0) {
        return await _addThemeToUser(themeId);
      }

      // TODO: 這裡可以添加金幣扣除邏輯
      // 目前先直接添加主題
      return await _addThemeToUser(themeId);
    } catch (e) {
      LoggerService.error('Error purchasing theme background: $e');
      return false;
    }
  }

  /// 將主題添加到用戶的擁有列表
  static Future<bool> _addThemeToUser(String themeId) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;

      final uid = userData['uid'];
      if (uid == null) return false;

      // 獲取當前擁有的項目
      final currentPurchasedItems = userData['purchasedItems'] as List<dynamic>? ?? [];
      
      // 檢查是否已經擁有
      if (currentPurchasedItems.contains(themeId)) {
        return true; // 已經擁有
      }

      // 添加到擁有列表
      final updatedPurchasedItems = [...currentPurchasedItems, themeId];

      // 更新 Firebase
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'purchasedItems': updatedPurchasedItems,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      LoggerService.info('Theme background added to user: $themeId');
      return true;
    } catch (e) {
      LoggerService.error('Error adding theme to user: $e');
      return false;
    }
  }

  /// 獲取用戶擁有的主題背景列表
  static Future<List<String>> getUserOwnedThemes() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return ['主題1']; // 預設主題

      final purchasedItems = userData['purchasedItems'] as List<dynamic>? ?? [];
      final ownedThemes = <String>['主題1']; // 預設主題總是擁有

      // 檢查購買的主題
      for (final item in purchasedItems) {
        if (item is String && _themeBackgrounds.containsKey(item)) {
          ownedThemes.add(item);
        }
      }

      return ownedThemes;
    } catch (e) {
      LoggerService.error('Error getting user owned themes: $e');
      return ['主題1'];
    }
  }

  /// 獲取主題背景的預覽圖片 URL
  static String getThemePreviewUrl(String themeId) {
    final theme = _themeBackgrounds[themeId];
    return theme?.imageUrl ?? _themeBackgrounds['主題1']!.imageUrl;
  }

  /// 獲取主題背景的漸層顏色（用於載入時的背景）
  static List<Color> getThemeGradientColors(String themeId) {
    switch (themeId) {
      case '主題1': // 經典桌布
        return [Colors.blue.shade50, Colors.blue.shade100];
      case '主題2': // 貓空纜車背景
        return [Colors.green.shade100, Colors.blue.shade200];
      case '主題3': // 捷運車廂背景
        return [Colors.grey.shade100, Colors.blue.shade100];
      case '主題4': // 台北101夜景
        return [Colors.purple.shade900, Colors.blue.shade900];
      case '主題5': // 淡水夕陽
        return [Colors.orange.shade300, Colors.pink.shade200];
      case '主題6': // 九份老街
        return [Colors.brown.shade200, Colors.orange.shade100];
      case '主題7': // 陽明山花季
        return [Colors.pink.shade100, Colors.white];
      case '主題8': // 象山夜景
        return [Colors.indigo.shade900, Colors.purple.shade800];
      case '主題9': // 西門町街景
        return [Colors.blue.shade200, Colors.purple.shade100];
      case '主題10': // 北投溫泉
        return [Colors.green.shade200, Colors.blue.shade100];
      default:
        return [Colors.blue.shade50, Colors.blue.shade100];
    }
  }
}

/// 主題背景數據類
class ThemeBackground {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String category;
  final int price;
  final bool isDefault;

  const ThemeBackground({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.price,
    required this.isDefault,
  });

  /// 檢查是否為免費主題
  bool get isFree => price == 0;

  /// 獲取價格顯示文字
  String get priceText => isFree ? '免費' : '$price 金幣';
}
