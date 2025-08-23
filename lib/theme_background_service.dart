import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';

class ThemeBackgroundService {
  static const String _selectedThemeKey = 'selected_theme_background';
  // 修復：將預設主題URL改為一個有效的漸變背景
  static const String _defaultThemeUrl = 'https://i.postimg.cc/3JZQZQZQ/gradient-bg.jpg';

  /// 設置當前選中的主題背景
  static Future<bool> setSelectedTheme(
    String themeId,
    String imageUrl,
    String themeName,
  ) async {
    try {
      LoggerService.info('開始設置主題背景: $themeName ($imageUrl)');
      
      final prefs = await SharedPreferences.getInstance();
      final userData = await UserService.getCurrentUserData();

      if (userData != null) {
        final uid = userData['uid'] ?? 'default';
        LoggerService.info('用戶UID: $uid');

        // 先儲存到本地，提高響應速度
        await prefs.setString('${_selectedThemeKey}_$uid', imageUrl);
        await prefs.setString('${_selectedThemeKey}_name_$uid', themeName);
        await prefs.setString('${_selectedThemeKey}_id_$uid', themeId);

        LoggerService.info('主題背景已設置到本地: $themeName ($imageUrl)');

        // 異步儲存到 Firebase，不阻塞主流程
        _saveToFirebaseAsync(uid, imageUrl, themeName, themeId);

        return true;
      }
      LoggerService.warning('無法獲取用戶數據');
      return false;
    } catch (e) {
      LoggerService.error('設置主題背景失敗: $e');
      return false;
    }
  }

  /// 異步儲存到 Firebase
  static Future<void> _saveToFirebaseAsync(
    String uid,
    String imageUrl,
    String themeName,
    String themeId,
  ) async {
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
  }

  /// 獲取當前選中的主題背景URL
  static Future<String> getSelectedThemeUrl() async {
    try {
      LoggerService.debug('開始獲取主題背景URL');
      
      final userData = await UserService.getCurrentUserData();
      if (userData != null) {
        final uid = userData['uid'] ?? 'default';
        LoggerService.debug('用戶UID: $uid');

        // 優先從本地獲取，提高響應速度
        final prefs = await SharedPreferences.getInstance();
        final localThemeUrl = prefs.getString('${_selectedThemeKey}_$uid');
        
        LoggerService.debug('本地主題URL: $localThemeUrl');
        
        if (localThemeUrl != null && localThemeUrl.isNotEmpty) {
          LoggerService.debug('使用本地主題URL: $localThemeUrl');
          return localThemeUrl;
        }

        // 如果本地沒有，再嘗試從 Firebase 獲取
        try {
          LoggerService.debug('嘗試從 Firebase 獲取主題背景');
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            final themeUrl = data?['selectedThemeBackground'] as String?;
            LoggerService.debug('Firebase 主題URL: $themeUrl');
            
            if (themeUrl != null && themeUrl.isNotEmpty) {
              // 同步到本地存儲
              await prefs.setString('${_selectedThemeKey}_$uid', themeUrl);
              LoggerService.debug('從 Firebase 獲取並同步到本地: $themeUrl');
              return themeUrl;
            }
          }
        } catch (e) {
          LoggerService.warning('從 Firebase 獲取主題背景失敗: $e');
        }

        LoggerService.debug('使用預設主題URL: $_defaultThemeUrl');
        return _defaultThemeUrl;
      }
      LoggerService.warning('無法獲取用戶數據，使用預設主題');
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

        // 優先從本地獲取，提高響應速度
        final prefs = await SharedPreferences.getInstance();
        final localThemeName = prefs.getString('${_selectedThemeKey}_name_$uid');
        
        if (localThemeName != null && localThemeName.isNotEmpty) {
          return localThemeName;
        }

        // 如果本地沒有，再嘗試從 Firebase 獲取
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            final themeName = data?['selectedThemeName'] as String?;
            if (themeName != null && themeName.isNotEmpty) {
              // 同步到本地存儲
              await prefs.setString('${_selectedThemeKey}_name_$uid', themeName);
              return themeName;
            }
          }
        } catch (e) {
          LoggerService.warning('從 Firebase 獲取主題名稱失敗: $e');
        }

        return '預設主題';
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
    return themeUrl.isNotEmpty && themeUrl != _defaultThemeUrl;
  }
}
