import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';

class FoodService {
  static const String _foodCollection = 'userFood';
  
  /// 獲取用戶的飼料庫存
  static Future<Map<String, int>> getUserFoodInventory() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return {};
      
      final uid = userData['uid'] ?? 'default';
      final doc = await FirebaseFirestore.instance
          .collection(_foodCollection)
          .doc(uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final inventory = Map<String, int>.from(data['inventory'] ?? {});
        LoggerService.info('獲取用戶飼料庫存: $inventory');
        return inventory;
      }
      
      return {};
    } catch (e) {
      LoggerService.error('獲取用戶飼料庫存失敗: $e');
      return {};
    }
  }
  
  /// 增加飼料數量
  static Future<bool> addFood(String foodId, int amount) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;
      
      final uid = userData['uid'] ?? 'default';
      final docRef = FirebaseFirestore.instance
          .collection(_foodCollection)
          .doc(uid);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        Map<String, int> inventory = {};
        if (doc.exists) {
          final data = doc.data()!;
          inventory = Map<String, int>.from(data['inventory'] ?? {});
        }
        
        // 增加飼料數量
        inventory[foodId] = (inventory[foodId] ?? 0) + amount;
        
        transaction.set(docRef, {
          'inventory': inventory,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });
      
      LoggerService.info('成功增加飼料: $foodId, 數量: $amount');
      return true;
    } catch (e) {
      LoggerService.error('增加飼料失敗: $e');
      return false;
    }
  }
  
  /// 減少飼料數量
  static Future<bool> consumeFood(String foodId, int amount) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;
      
      final uid = userData['uid'] ?? 'default';
      final docRef = FirebaseFirestore.instance
          .collection(_foodCollection)
          .doc(uid);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          throw Exception('飼料庫存不存在');
        }
        
        final data = doc.data()!;
        final inventory = Map<String, int>.from(data['inventory'] ?? {});
        
        final currentAmount = inventory[foodId] ?? 0;
        if (currentAmount < amount) {
          throw Exception('飼料數量不足');
        }
        
        // 減少飼料數量
        inventory[foodId] = currentAmount - amount;
        if (inventory[foodId] == 0) {
          inventory.remove(foodId);
        }
        
        transaction.update(docRef, {
          'inventory': inventory,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });
      
      LoggerService.info('成功消耗飼料: $foodId, 數量: $amount');
      return true;
    } catch (e) {
      LoggerService.error('消耗飼料失敗: $e');
      return false;
    }
  }
  
  /// 獲取特定飼料的數量
  static Future<int> getFoodAmount(String foodId) async {
    try {
      final inventory = await getUserFoodInventory();
      return inventory[foodId] ?? 0;
    } catch (e) {
      LoggerService.error('獲取飼料數量失敗: $e');
      return 0;
    }
  }
  
  /// 檢查是否有足夠的飼料
  static Future<bool> hasEnoughFood(String foodId, int amount) async {
    try {
      final currentAmount = await getFoodAmount(foodId);
      return currentAmount >= amount;
    } catch (e) {
      LoggerService.error('檢查飼料數量失敗: $e');
      return false;
    }
  }
  
  /// 獲取用戶飼料庫存的實時流
  static Stream<Map<String, int>> getUserFoodInventoryStream() {
    return Stream.periodic(const Duration(seconds: 1), (_) async {
      return await getUserFoodInventory();
    }).asyncMap((future) => future);
  }
}
