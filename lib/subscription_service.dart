import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';

class SubscriptionService {
  static const String _premiumStatusKey = 'premium_status';
  static const String _trialStartDateKey = 'trial_start_date';
  static const int _trialDurationDays = 180; // 6個月 = 180天

  /// 檢查用戶是否為 Premium 用戶
  static Future<bool> isPremiumUser() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;

      final uid = userData['uid'] ?? 'default';
      
      // 從 Firebase 獲取用戶訂閱狀態
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        LoggerService.warning('用戶文檔不存在，使用本地存儲檢查');
        return _checkLocalPremiumStatus();
      }

      final userDocData = userDoc.data() as Map<String, dynamic>;
      final subscriptionType = userDocData['subscriptionType'] ?? '免費版';
      
      LoggerService.debug('用戶 $uid 的訂閱類型: $subscriptionType');
      
      // 根據訂閱類型判斷
      if (subscriptionType == 'Premium版') {
        return true;
      } else if (subscriptionType == '體驗版') {
        // 檢查試用期是否過期
        final trialStartDate = userDocData['trialStartDate'];
        if (trialStartDate != null) {
          final startDate = DateTime.parse(trialStartDate);
          final currentDate = DateTime.now();
          final daysSinceStart = currentDate.difference(startDate).inDays;
          
          if (daysSinceStart < _trialDurationDays) {
            LoggerService.debug('用戶 $uid 在免費試用期內，剩餘 ${_trialDurationDays - daysSinceStart} 天');
            return true;
          } else {
            // 試用期過期，更新為免費版
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({
              'subscriptionType': '免費版',
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            LoggerService.info('用戶 $uid 試用期已過期，更新為免費版');
            return false;
          }
        }
      }
      
      // 免費版用戶
      return false;

    } catch (e) {
      LoggerService.error('檢查 Premium 狀態時發生錯誤: $e');
      return _checkLocalPremiumStatus();
    }
  }

  /// 檢查本地存儲的 Premium 狀態（備用方法）
  static Future<bool> _checkLocalPremiumStatus() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      
      // 檢查本地存儲的 Premium 狀態
      final isPremium = prefs.getBool('${_premiumStatusKey}_$username') ?? false;
      
      if (isPremium) {
        LoggerService.debug('用戶 $username 是 Premium 用戶（本地存儲）');
        return true;
      }

      // 檢查免費試用期
      final trialStartDate = prefs.getString('${_trialStartDateKey}_$username');
      if (trialStartDate != null) {
        final startDate = DateTime.parse(trialStartDate);
        final currentDate = DateTime.now();
        final daysSinceStart = currentDate.difference(startDate).inDays;
        
        if (daysSinceStart < _trialDurationDays) {
          LoggerService.debug('用戶 $username 在免費試用期內，剩餘 ${_trialDurationDays - daysSinceStart} 天（本地存儲）');
          return true;
        }
      }

      LoggerService.debug('用戶 $username 不是 Premium 用戶（本地存儲）');
      return false;

    } catch (e) {
      LoggerService.error('檢查本地 Premium 狀態時發生錯誤: $e');
      return false;
    }
  }

  /// 開始免費試用
  static Future<void> startFreeTrial() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final username = userData['username'] ?? 'default';
      final uid = userData['uid'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      
      // 設置試用開始日期
      final currentDate = DateTime.now();
      await prefs.setString('${_trialStartDateKey}_$username', currentDate.toIso8601String());
      
      // 更新 Firebase 用戶文檔
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'subscriptionType': '體驗版',
        'trialStartDate': currentDate.toIso8601String(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('用戶 $username 開始免費試用，開始日期: $currentDate');
    } catch (e) {
      LoggerService.error('開始免費試用時發生錯誤: $e');
    }
  }

  /// 升級為 Premium 用戶
  static Future<void> upgradeToPremium() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final username = userData['username'] ?? 'default';
      final uid = userData['uid'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      
      // 設置 Premium 狀態
      await prefs.setBool('${_premiumStatusKey}_$username', true);
      
      // 清除試用開始日期（因為已經是 Premium）
      await prefs.remove('${_trialStartDateKey}_$username');
      
      // 更新 Firebase 用戶文檔
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'subscriptionType': 'Premium版',
        'premiumUpgradeDate': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('用戶 $username 已升級為 Premium 用戶');
    } catch (e) {
      LoggerService.error('升級為 Premium 時發生錯誤: $e');
    }
  }

  /// 獲取免費試用剩餘天數
  static Future<int> getTrialRemainingDays() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return 0;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      
      final trialStartDate = prefs.getString('${_trialStartDateKey}_$username');
      if (trialStartDate == null) return 0;

      final startDate = DateTime.parse(trialStartDate);
      final currentDate = DateTime.now();
      final daysSinceStart = currentDate.difference(startDate).inDays;
      
      final remainingDays = _trialDurationDays - daysSinceStart;
      return remainingDays > 0 ? remainingDays : 0;

    } catch (e) {
      LoggerService.error('獲取試用剩餘天數時發生錯誤: $e');
      return 0;
    }
  }

  /// 檢查是否已經開始過免費試用
  static Future<bool> hasStartedTrial() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      
      final trialStartDate = prefs.getString('${_trialStartDateKey}_$username');
      return trialStartDate != null;

    } catch (e) {
      LoggerService.error('檢查試用狀態時發生錯誤: $e');
      return false;
    }
  }

  /// 初始化用戶訂閱狀態為免費版
  static Future<void> initializeAsFreeUser() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final uid = userData['uid'] ?? 'default';
      
      // 更新 Firebase 用戶文檔
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'subscriptionType': '免費版',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('用戶 $uid 初始化為免費版用戶');
    } catch (e) {
      LoggerService.error('初始化免費版用戶時發生錯誤: $e');
    }
  }

  /// 清除訂閱狀態（用於測試或重置）
  static Future<void> clearSubscriptionStatus() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove('${_premiumStatusKey}_$username');
      await prefs.remove('${_trialStartDateKey}_$username');
      
      LoggerService.info('用戶 $username 的訂閱狀態已清除');
    } catch (e) {
      LoggerService.error('清除訂閱狀態時發生錯誤: $e');
    }
  }
}
