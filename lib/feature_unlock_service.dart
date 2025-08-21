import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';
import 'subscription_service.dart';

class FeatureUnlockService {
  static const String _unlockStatusKey = 'feature_unlock_status';
  
  /// 功能解鎖要求等級
  static const Map<String, int> _featureRequirements = {
    '桌寵': 0, // 登入即可解鎖
    '捷運知識王': 0, // 登入即可解鎖
    '商城': 6, // 需要6等才能解鎖
    '挑戰任務': 11, // 需要11等才能解鎖
    '勳章': 11, // 需要11等才能解鎖
  };

  /// 在登入時初始化功能解鎖狀態
  static Future<Map<String, bool>> initializeFeatureUnlockStatus() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) {
        LoggerService.warning('用戶數據為空，無法初始化功能解鎖狀態');
        return _getDefaultUnlockStatus();
      }

      final uid = userData['uid'] ?? 'default';
      
      // 從 Firebase 獲取用戶等級
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        LoggerService.warning('用戶文檔不存在，使用預設解鎖狀態');
        return _getDefaultUnlockStatus();
      }

      final userDocData = userDoc.data() as Map<String, dynamic>;
      final currentLevel = userDocData['level'] ?? 1;

      // 計算每個功能的解鎖狀態
      final unlockStatus = <String, bool>{};
      for (final entry in _featureRequirements.entries) {
        final feature = entry.key;
        final requiredLevel = entry.value;
        
        // 特殊處理桌寵功能：需要 Premium 狀態
        if (feature == '桌寵') {
          final isPremium = await SubscriptionService.isPremiumUser();
          unlockStatus[feature] = isPremium;
        } else {
          unlockStatus[feature] = currentLevel >= requiredLevel;
        }
      }

      // 保存到本地存儲
      await _saveUnlockStatus(unlockStatus);

      LoggerService.info('功能解鎖狀態初始化完成，當前等級: $currentLevel, 解鎖狀態: $unlockStatus');
      return unlockStatus;

    } catch (e) {
      LoggerService.error('初始化功能解鎖狀態時發生錯誤: $e');
      return _getDefaultUnlockStatus();
    }
  }

  /// 獲取預設的解鎖狀態
  static Map<String, bool> _getDefaultUnlockStatus() {
    return {
      '桌寵': false, // 需要 Premium 才能解鎖
      '捷運知識王': true, // 登入即可解鎖
      '商城': false, // 需要6等才能解鎖
      '挑戰任務': false, // 需要11等才能解鎖
      '勳章': false, // 需要11等才能解鎖
    };
  }

  /// 保存解鎖狀態到本地存儲
  static Future<void> _saveUnlockStatus(Map<String, bool> unlockStatus) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      
      // 將 Map 轉換為 JSON 字符串保存
      final unlockStatusJson = unlockStatus.map((key, value) => MapEntry(key, value.toString()));
      await prefs.setString('${_unlockStatusKey}_$username', unlockStatusJson.toString());
      
      LoggerService.debug('功能解鎖狀態已保存到本地存儲');
    } catch (e) {
      LoggerService.error('保存功能解鎖狀態時發生錯誤: $e');
    }
  }

  /// 從本地存儲獲取解鎖狀態
  static Future<Map<String, bool>> getUnlockStatus() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return _getDefaultUnlockStatus();

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      
      final unlockStatusString = prefs.getString('${_unlockStatusKey}_$username');
      if (unlockStatusString == null) {
        LoggerService.debug('本地存儲中沒有功能解鎖狀態，重新初始化');
        return await initializeFeatureUnlockStatus();
      }

      // 解析 JSON 字符串
      final unlockStatusMap = <String, bool>{};
      final entries = unlockStatusString
          .replaceAll('{', '')
          .replaceAll('}', '')
          .split(',');
      
      for (final entry in entries) {
        final parts = entry.trim().split(':');
        if (parts.length == 2) {
          final key = parts[0].trim().replaceAll('"', '');
          final value = parts[1].trim() == 'true';
          unlockStatusMap[key] = value;
        }
      }

      // 特殊處理桌寵功能：需要檢查 Premium 狀態
      if (unlockStatusMap.containsKey('桌寵')) {
        final isPremium = await SubscriptionService.isPremiumUser();
        unlockStatusMap['桌寵'] = isPremium;
      }
      
      LoggerService.debug('從本地存儲獲取功能解鎖狀態: $unlockStatusMap');
      return unlockStatusMap;

    } catch (e) {
      LoggerService.error('獲取功能解鎖狀態時發生錯誤: $e');
      return _getDefaultUnlockStatus();
    }
  }

  /// 檢查特定功能是否已解鎖
  static Future<bool> isFeatureUnlocked(String feature) async {
    try {
      final unlockStatus = await getUnlockStatus();
      return unlockStatus[feature] ?? false;
    } catch (e) {
      LoggerService.error('檢查功能解鎖狀態時發生錯誤: $e');
      return false;
    }
  }

  /// 當用戶升級時更新解鎖狀態
  static Future<void> updateUnlockStatusOnLevelUp(int newLevel) async {
    try {
      final currentUnlockStatus = await getUnlockStatus();
      final updatedUnlockStatus = <String, bool>{};
      bool hasChanges = false;

      for (final entry in _featureRequirements.entries) {
        final feature = entry.key;
        final requiredLevel = entry.value;
        
        bool shouldBeUnlocked;
        // 特殊處理桌寵功能：需要 Premium 狀態
        if (feature == '桌寵') {
          shouldBeUnlocked = await SubscriptionService.isPremiumUser();
        } else {
          shouldBeUnlocked = newLevel >= requiredLevel;
        }
        
        final wasUnlocked = currentUnlockStatus[feature] ?? false;
        updatedUnlockStatus[feature] = shouldBeUnlocked;

        // 檢查是否有新解鎖的功能
        if (shouldBeUnlocked && !wasUnlocked) {
          hasChanges = true;
          if (feature == '桌寵') {
            LoggerService.info('功能 "$feature" 已解鎖！需要 Premium 狀態');
          } else {
            LoggerService.info('功能 "$feature" 已解鎖！需要等級: $requiredLevel, 當前等級: $newLevel');
          }
        }
      }

      if (hasChanges) {
        await _saveUnlockStatus(updatedUnlockStatus);
        LoggerService.info('功能解鎖狀態已更新，新等級: $newLevel');
      }

    } catch (e) {
      LoggerService.error('升級時更新功能解鎖狀態發生錯誤: $e');
    }
  }

  /// 獲取功能需要的等級
  static int getRequiredLevel(String feature) {
    return _featureRequirements[feature] ?? 1;
  }

  /// 清除本地存儲的解鎖狀態（用於測試或重置）
  static Future<void> clearUnlockStatus() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove('${_unlockStatusKey}_$username');
      LoggerService.info('功能解鎖狀態已清除');
    } catch (e) {
      LoggerService.error('清除功能解鎖狀態時發生錯誤: $e');
    }
  }
}
