import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';

class ThemeBackgroundService {
  static const String _selectedThemeKey = 'selected_theme_background';
  static const String _defaultThemeUrl = '';

  /// 設置當前選中的主題背景
  static Future<bool> setSelectedTheme(
    String themeId,
    String imageUrl,
    String themeName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = await UserService.getCurrentUserData();

      if (userData != null) {
        final uid = userData['uid'] ?? 'default';

        // 儲存到本地
        await prefs.setString('${_selectedThemeKey}_$uid', imageUrl);
        await prefs.setString('${_selectedThemeKey}_name_$uid', themeName);
        await prefs.setString('${_selectedThemeKey}_id_$uid', themeId);

        // 儲存到 Firebase
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'selectedThemeBackground': imageUrl,
            'selectedThemeName': themeName,
            'selectedThemeId': themeId,
          });
          LoggerService.info('主題背景已更新到 Firebase: $themeName');
        } catch (e) {
          LoggerService.warning('更新主題背景到 Firebase 失敗: $e');
        }

        LoggerService.info('主題背景已設置: $themeName ($imageUrl)');
        return true;
      }
      return false;
    } catch (e) {
      LoggerService.error('設置主題背景失敗: $e');
      return false;
    }
  }

  /// 獲取當前選中的主題背景URL
  static Future<String> getSelectedThemeUrl() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData != null) {
        final uid = userData['uid'] ?? 'default';

        // 先嘗試從 Firebase 獲取
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            final themeUrl = data?['selectedThemeBackground'] as String?;
            if (themeUrl != null && themeUrl.isNotEmpty) {
              return themeUrl;
            }
          }
        } catch (e) {
          LoggerService.warning('從 Firebase 獲取主題背景失敗: $e');
        }

        // 如果 Firebase 失敗，從本地獲取
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('${_selectedThemeKey}_$uid') ?? _defaultThemeUrl;
      }
      return _defaultThemeUrl;
    } catch (e) {
      LoggerService.error('獲取主題背景失敗: $e');
      return _defaultThemeUrl;
    }
  }

  /// 獲取當前選中的主題名稱
  static Future<String> getSelectedThemeName() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData != null) {
        final uid = userData['uid'] ?? 'default';

        // 先嘗試從 Firebase 獲取
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            final themeName = data?['selectedThemeName'] as String?;
            if (themeName != null && themeName.isNotEmpty) {
              return themeName;
            }
          }
        } catch (e) {
          LoggerService.warning('從 Firebase 獲取主題名稱失敗: $e');
        }

        // 如果 Firebase 失敗，從本地獲取
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('${_selectedThemeKey}_name_$uid') ?? '預設主題';
      }
      return '預設主題';
    } catch (e) {
      LoggerService.error('獲取主題名稱失敗: $e');
      return '預設主題';
    }
  }

  /// 清除選中的主題（恢復預設）
  static Future<bool> clearSelectedTheme() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData != null) {
        final uid = userData['uid'] ?? 'default';

        // 清除本地存儲
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('${_selectedThemeKey}_$uid');
        await prefs.remove('${_selectedThemeKey}_name_$uid');
        await prefs.remove('${_selectedThemeKey}_id_$uid');

        // 清除 Firebase
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'selectedThemeBackground': FieldValue.delete(),
            'selectedThemeName': FieldValue.delete(),
            'selectedThemeId': FieldValue.delete(),
          });
          LoggerService.info('主題背景已從 Firebase 清除');
        } catch (e) {
          LoggerService.warning('從 Firebase 清除主題背景失敗: $e');
        }

        LoggerService.info('主題背景已清除，恢復預設');
        return true;
      }
      return false;
    } catch (e) {
      LoggerService.error('清除主題背景失敗: $e');
      return false;
    }
  }

  /// 檢查是否有自定義主題
  static Future<bool> hasCustomTheme() async {
    final themeUrl = await getSelectedThemeUrl();
    return themeUrl.isNotEmpty;
  }
}
