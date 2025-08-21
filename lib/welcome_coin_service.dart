import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';

class WelcomeCoinService {
  static const String _welcomeCoinClaimedKey = 'welcome_coin_claimed';
  static const int _welcomeCoinAmount = 500;

  /// 檢查用戶是否已經領取過歡迎金幣
  static Future<bool> hasClaimedWelcomeCoin() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;

      final uid = userData['uid'] ?? 'default';
      
      // 首先從 Firebase 檢查
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final userDocData = userDoc.data() as Map<String, dynamic>;
        final hasClaimed = userDocData['welcomeCoinClaimed'] ?? false;
        
        if (hasClaimed) {
          LoggerService.debug('用戶 $uid 已經領取過歡迎金幣（Firebase）');
          return true;
        }
      }

      // 如果 Firebase 沒有記錄，檢查本地存儲
      final username = userData['username'] ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      final localHasClaimed = prefs.getBool('${_welcomeCoinClaimedKey}_$username') ?? false;
      
      if (localHasClaimed) {
        LoggerService.debug('用戶 $username 已經領取過歡迎金幣（本地存儲）');
        return true;
      }

      LoggerService.debug('用戶 $uid 尚未領取歡迎金幣');
      return false;

    } catch (e) {
      LoggerService.error('檢查歡迎金幣領取狀態時發生錯誤: $e');
      return false;
    }
  }

  /// 標記用戶已領取歡迎金幣
  static Future<void> markWelcomeCoinAsClaimed() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final uid = userData['uid'] ?? 'default';
      final username = userData['username'] ?? 'default';
      
      // 更新 Firebase
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'welcomeCoinClaimed': true,
        'welcomeCoinClaimedDate': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // 更新本地存儲
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${_welcomeCoinClaimedKey}_$username', true);
      
      LoggerService.info('用戶 $uid 已標記為已領取歡迎金幣');
    } catch (e) {
      LoggerService.error('標記歡迎金幣領取狀態時發生錯誤: $e');
    }
  }

  /// 領取歡迎金幣
  static Future<bool> claimWelcomeCoin() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;

      final uid = userData['uid'] ?? 'default';
      
      // 檢查是否已經領取過
      final hasClaimed = await hasClaimedWelcomeCoin();
      if (hasClaimed) {
        LoggerService.warning('用戶 $uid 已經領取過歡迎金幣');
        return false;
      }

      // 獲取當前金幣數量
      final currentCoins = userData['coins'] ?? 0;
      final newCoins = currentCoins + _welcomeCoinAmount;

      // 更新用戶金幣數量
      await UserService.updateUserData({'coins': newCoins});

      // 標記為已領取
      await markWelcomeCoinAsClaimed();

      LoggerService.info('用戶 $uid 成功領取歡迎金幣，新金幣數量: $newCoins');
      return true;

    } catch (e) {
      LoggerService.error('領取歡迎金幣時發生錯誤: $e');
      return false;
    }
  }

  /// 重置歡迎金幣領取狀態（用於測試）
  static Future<void> resetWelcomeCoinStatus() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final uid = userData['uid'] ?? 'default';
      final username = userData['username'] ?? 'default';
      
      // 清除 Firebase 記錄
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'welcomeCoinClaimed': false,
        'welcomeCoinClaimedDate': FieldValue.delete(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // 清除本地存儲
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_welcomeCoinClaimedKey}_$username');
      
      LoggerService.info('用戶 $uid 的歡迎金幣狀態已重置');
    } catch (e) {
      LoggerService.error('重置歡迎金幣狀態時發生錯誤: $e');
    }
  }

  /// 獲取歡迎金幣數量
  static int getWelcomeCoinAmount() {
    return _welcomeCoinAmount;
  }
}
