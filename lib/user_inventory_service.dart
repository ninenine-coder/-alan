import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';

class UserInventoryService {
  static const String _inventoryCollection = 'user_inventory';
  
  /// 同步商城數據到用戶庫存
  static Future<void> syncStoreDataToUserInventory() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) {
        LoggerService.warning('用戶未登入，無法同步商城數據');
        return;
      }
      
      final uid = userData['uid'] ?? 'default';
      LoggerService.info('開始同步商城數據到用戶庫存: $uid');
      
      // 定義所有商城類別
      final categories = ['造型', '特效', '頭像', '主題桌鋪', '飼料'];
      
      for (final category in categories) {
        await _syncCategoryToUserInventory(uid, category);
      }
      
      LoggerService.info('商城數據同步完成');
    } catch (e) {
      LoggerService.error('同步商城數據失敗: $e');
    }
  }
  
  /// 同步特定類別的商品到用戶庫存
  static Future<void> _syncCategoryToUserInventory(String uid, String category) async {
    try {
      LoggerService.debug('同步類別: $category');
      
      // 從商城獲取該類別的所有商品
      final storeSnapshot = await FirebaseFirestore.instance
          .collection(category)
          .get();
      
      // 獲取用戶現有庫存
      final userInventoryRef = FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .collection(category);
      
      final batch = FirebaseFirestore.instance.batch();
      int syncCount = 0;
      
      for (final storeDoc in storeSnapshot.docs) {
        final storeData = storeDoc.data();
        final itemId = storeDoc.id;
        
        // 檢查用戶庫存中是否已有此商品
        final userItemRef = userInventoryRef.doc(itemId);
        final userItemDoc = await userItemRef.get();
        
        if (!userItemDoc.exists) {
          // 如果用戶庫存中沒有此商品，添加為"未擁有"狀態
          final inventoryData = {
            'itemId': itemId,
            'name': storeData['name'] ?? storeData['名稱'] ?? '未命名商品',
            'price': storeData['price'] ?? storeData['價格'] ?? 0,
            'imageUrl': storeData['圖片'] ?? storeData['imageUrl'] ?? storeData['image'] ?? '',
            'description': storeData['description'] ?? storeData['描述'] ?? '',
            'category': category,
            'status': '未擁有', // 預設狀態
            'popularity': storeData['常見度'] ?? storeData['popularity'] ?? 0,
            'syncedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          
          batch.set(userItemRef, inventoryData);
          syncCount++;
        } else {
          // 如果已存在，更新商品信息（但保持狀態不變）
          final currentData = userItemDoc.data() as Map<String, dynamic>;
          final currentStatus = currentData['status'] ?? '未擁有';
          
          final updatedData = {
            'name': storeData['name'] ?? storeData['名稱'] ?? currentData['name'],
            'price': storeData['price'] ?? storeData['價格'] ?? currentData['price'],
            'imageUrl': storeData['圖片'] ?? storeData['imageUrl'] ?? storeData['image'] ?? currentData['imageUrl'],
            'description': storeData['description'] ?? storeData['描述'] ?? currentData['description'],
            'popularity': storeData['常見度'] ?? storeData['popularity'] ?? currentData['popularity'],
            'status': currentStatus, // 保持現有狀態
            'updatedAt': FieldValue.serverTimestamp(),
          };
          
          batch.update(userItemRef, updatedData);
        }
      }
      
      await batch.commit();
      LoggerService.info('類別 $category 同步完成，新增/更新 $syncCount 個商品');
      
    } catch (e) {
      LoggerService.error('同步類別 $category 失敗: $e');
    }
  }
  
  /// 購買商品 - 更新商品狀態為"已擁有"
  static Future<bool> purchaseItem(String itemId, String category) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) {
        LoggerService.warning('用戶未登入，無法購買商品');
        return false;
      }
      
      final uid = userData['uid'] ?? 'default';
      LoggerService.info('購買商品: $itemId (類別: $category)');
      
      // 更新用戶庫存中的商品狀態
      await FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .collection(category)
          .doc(itemId)
          .update({
        'status': '已擁有',
        'purchasedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // 同時更新商城中的商品狀態（可選）
      await FirebaseFirestore.instance
          .collection(category)
          .doc(itemId)
          .update({
        'lastPurchasedBy': uid,
        'lastPurchasedAt': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('商品購買成功: $itemId');
      return true;
    } catch (e) {
      LoggerService.error('購買商品失敗: $e');
      return false;
    }
  }
  
  /// 獲取用戶已擁有的商品（按類別）
  static Stream<QuerySnapshot> getUserOwnedItemsByCategory(String category) {
    return _getUserInventoryByCategory(category)
        .where('status', isEqualTo: '已擁有')
        .snapshots();
  }
  
  /// 獲取用戶所有商品（按類別）
  static Stream<QuerySnapshot> getUserAllItemsByCategory(String category) {
    return _getUserInventoryByCategory(category).snapshots();
  }
  
  /// 獲取用戶庫存引用（按類別）
  static CollectionReference _getUserInventoryByCategory(String category) {
    // 同步方法，但這裡我們需要用戶ID，所以改為異步
    throw UnsupportedError('請使用 getUserInventoryByCategoryAsync');
  }
  
  /// 獲取用戶庫存引用（按類別）- 異步版本
  static Future<CollectionReference?> getUserInventoryByCategoryAsync(String category) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return null;
      
      final uid = userData['uid'] ?? 'default';
      return FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .collection(category);
    } catch (e) {
      LoggerService.error('獲取用戶庫存引用失敗: $e');
      return null;
    }
  }
  
  /// 獲取用戶已擁有的商品數量（按類別）
  static Future<int> getUserOwnedItemsCount(String category) async {
    try {
      final inventoryRef = await getUserInventoryByCategoryAsync(category);
      if (inventoryRef == null) return 0;
      
      final snapshot = await inventoryRef
          .where('status', isEqualTo: '已擁有')
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      LoggerService.error('獲取已擁有商品數量失敗: $e');
      return 0;
    }
  }
  
  /// 檢查商品是否已擁有
  static Future<bool> isItemOwned(String itemId, String category) async {
    try {
      final inventoryRef = await getUserInventoryByCategoryAsync(category);
      if (inventoryRef == null) return false;
      
      final doc = await inventoryRef.doc(itemId).get();
      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == '已擁有';
    } catch (e) {
      LoggerService.error('檢查商品擁有狀態失敗: $e');
      return false;
    }
  }
  
  /// 獲取用戶的完整庫存統計
  static Future<Map<String, int>> getUserInventoryStats() async {
    final categories = ['造型', '特效', '頭像', '主題桌鋪', '飼料'];
    final stats = <String, int>{};
    
    for (final category in categories) {
      stats[category] = await getUserOwnedItemsCount(category);
    }
    
    return stats;
  }
}
