import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';

class FoodInitializationService {
  /// 初始化用戶的飼料庫存
  static Future<bool> initializeUserFoodInventory() async {
    try {
      final currentUser = await UserService.getCurrentUserData();
      if (currentUser == null) {
        LoggerService.warning('用戶未登入，無法初始化飼料庫存');
        return false;
      }

      final uid = currentUser['uid'] ?? 'default';
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // 檢查用戶是否已經初始化過飼料庫存
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData.containsKey('foodInventoryInitialized')) {
          LoggerService.info('用戶飼料庫存已初始化，跳過初始化步驟');
          return true;
        }
      }

      // 獲取所有飼料商品
      final foodQuerySnapshot = await FirebaseFirestore.instance
          .collection('商品')
          .where('category', isEqualTo: '飼料')
          .get();

      final Map<String, int> foodInventory = {};
      
      // 為每個飼料設置初始數量為0
      for (final doc in foodQuerySnapshot.docs) {
        foodInventory[doc.id] = 0;
        LoggerService.debug('初始化飼料: ${doc.data()['name']} (ID: ${doc.id})');
      }

      // 更新用戶資料
      await userRef.update({
        'foodInventory': foodInventory,
        'foodInventoryInitialized': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      LoggerService.info('用戶飼料庫存初始化成功，共初始化 ${foodInventory.length} 個飼料項目');
      return true;
    } catch (e) {
      LoggerService.error('初始化用戶飼料庫存失敗: $e');
      return false;
    }
  }

  /// 檢查並確保用戶飼料庫存已初始化
  static Future<bool> ensureFoodInventoryInitialized() async {
    try {
      final currentUser = await UserService.getCurrentUserData();
      if (currentUser == null) {
        LoggerService.warning('用戶未登入，無法檢查飼料庫存初始化狀態');
        return false;
      }

      final uid = currentUser['uid'] ?? 'default';
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        // 用戶文檔不存在，創建並初始化
        return await initializeUserFoodInventory();
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null || !userData.containsKey('foodInventoryInitialized')) {
        // 用戶文檔存在但未初始化飼料庫存
        return await initializeUserFoodInventory();
      }

      return true;
    } catch (e) {
      LoggerService.error('檢查飼料庫存初始化狀態失敗: $e');
      return false;
    }
  }
}
