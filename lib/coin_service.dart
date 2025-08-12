import 'user_service.dart';

class CoinService {
  // 獲取當前用戶的金幣餘額
  static Future<int> getCoins() async {
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return 0;
    
    return userData['coins'] ?? 0;
  }
  
  // 設置當前用戶的金幣餘額
  static Future<bool> setCoins(int coins) async {
    try {
      final success = await UserService.updateUserData({'coins': coins});
      return success;
    } catch (e) {
      return false;
    }
  }
  
  // 增加當前用戶的金幣
  static Future<int> addCoins(int amount) async {
    try {
      final currentCoins = await getCoins();
      final newCoins = currentCoins + amount;
      final success = await setCoins(newCoins);
      return success ? newCoins : currentCoins;
    } catch (e) {
      return await getCoins();
    }
  }
  
  // 扣除當前用戶的金幣
  static Future<bool> deductCoins(int amount) async {
    try {
      final currentCoins = await getCoins();
      if (currentCoins >= amount) {
        final newCoins = currentCoins - amount;
        final success = await setCoins(newCoins);
        return success;
      }
      return false; // 金幣不足
    } catch (e) {
      return false;
    }
  }
  
  // 檢查當前用戶是否有足夠金幣
  static Future<bool> hasEnoughCoins(int amount) async {
    try {
      final currentCoins = await getCoins();
      return currentCoins >= amount;
    } catch (e) {
      return false;
    }
  }
  
  // 重置當前用戶的金幣（用於測試）
  static Future<bool> resetCoins() async {
    try {
      return await setCoins(0);
    } catch (e) {
      return false;
    }
  }

  // 檢查當前用戶是否為首次登入
  static Future<bool> isFirstLogin() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;
      
      final loginCount = userData['loginCount'] ?? 0;
      return loginCount <= 1;
    } catch (e) {
      return false;
    }
  }

  // 獲取用戶金幣歷史記錄（可選功能）
  static Future<List<Map<String, dynamic>>> getCoinHistory() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return [];
      
      // 這裡可以從 Firestore 獲取金幣交易歷史
      // 目前返回空列表，可以根據需要擴展
      return [];
    } catch (e) {
      return [];
    }
  }

  // 獎勵金幣（用於完成任務等）
  static Future<bool> rewardCoins(int amount, String reason) async {
    try {
      final success = await addCoins(amount);
      if (success > 0) {
        // 可以在這裡記錄獎勵原因到 Firestore
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
} 