import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

class CoinService {
  // 獲取當前用戶的金幣餘額
  static Future<int> getCoins() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return 0;
    
    final prefs = await SharedPreferences.getInstance();
    final coinKey = UserService.getCoinsKey(currentUser.username);
    return prefs.getInt(coinKey) ?? 0; // 預設0金幣
  }
  
  // 設置當前用戶的金幣餘額
  static Future<void> setCoins(int coins) async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final coinKey = UserService.getCoinsKey(currentUser.username);
    await prefs.setInt(coinKey, coins);
  }
  
  // 增加當前用戶的金幣
  static Future<int> addCoins(int amount) async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return 0;
    
    final currentCoins = await getCoins();
    final newCoins = currentCoins + amount;
    await setCoins(newCoins);
    return newCoins;
  }
  
  // 扣除當前用戶的金幣
  static Future<bool> deductCoins(int amount) async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return false;
    
    final currentCoins = await getCoins();
    if (currentCoins >= amount) {
      final newCoins = currentCoins - amount;
      await setCoins(newCoins);
      return true; // 扣除成功
    }
    return false; // 金幣不足
  }
  
  // 檢查當前用戶是否有足夠金幣
  static Future<bool> hasEnoughCoins(int amount) async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return false;
    
    final currentCoins = await getCoins();
    return currentCoins >= amount;
  }
  
  // 重置當前用戶的金幣（用於測試）
  static Future<void> resetCoins() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;
    
    await setCoins(0);
  }

  // 檢查當前用戶是否為首次登入
  static Future<bool> isFirstLogin() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return false;
    
    return await UserService.isUserFirstLogin(currentUser.username);
  }

  // 標記當前用戶已登入
  static Future<void> markAsLoggedIn() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;
    
    await UserService.markUserAsLoggedIn(currentUser.username);
  }
} 