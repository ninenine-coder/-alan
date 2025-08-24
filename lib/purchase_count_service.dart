import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';

class PurchaseCountService {
  /// 獲取用戶的商品購買計數
  static Future<Map<String, int>> getUserPurchaseCounts() async {
    try {
      final currentUser = await UserService.getCurrentUserData();
      if (currentUser == null) {
        LoggerService.warning('用戶未登入，無法獲取購買計數');
        return {};
      }

      final uid = currentUser['uid'] ?? 'default';
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData.containsKey('purchaseCounts')) {
          final purchaseCounts = Map<String, int>.from(userData['purchaseCounts'] ?? {});
          LoggerService.debug('獲取購買計數: $purchaseCounts');
          return purchaseCounts;
        }
      }

      return {};
    } catch (e) {
      LoggerService.error('獲取購買計數失敗: $e');
      return {};
    }
  }

  /// 增加商品的購買計數
  static Future<bool> incrementPurchaseCount(String itemId, String itemName) async {
    try {
      final currentUser = await UserService.getCurrentUserData();
      if (currentUser == null) {
        LoggerService.warning('用戶未登入，無法增加購買計數');
        return false;
      }

      final uid = currentUser['uid'] ?? 'default';
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final purchaseCounts = Map<String, int>.from(userData['purchaseCounts'] ?? {});
          
          // 增加購買計數
          purchaseCounts[itemId] = (purchaseCounts[itemId] ?? 0) + 1;
          
          transaction.update(userRef, {
            'purchaseCounts': purchaseCounts,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          
          LoggerService.info('增加購買計數成功: $itemName (ID: $itemId), 新計數: ${purchaseCounts[itemId]}');
        } else {
          // 如果用戶文檔不存在，創建新的購買計數
          transaction.set(userRef, {
            'purchaseCounts': {itemId: 1},
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          
          LoggerService.info('創建購買計數: $itemName (ID: $itemId), 計數: 1');
        }
      });

      return true;
    } catch (e) {
      LoggerService.error('增加購買計數失敗: $e');
      return false;
    }
  }

  /// 獲取特定商品的購買計數
  static Future<int> getPurchaseCount(String itemId) async {
    try {
      final purchaseCounts = await getUserPurchaseCounts();
      return purchaseCounts[itemId] ?? 0;
    } catch (e) {
      LoggerService.error('獲取商品購買計數失敗: $e');
      return 0;
    }
  }

  /// 獲取用戶商品購買計數的實時流
  static Stream<Map<String, int>> getUserPurchaseCountsStream() async* {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) {
        LoggerService.warning('用戶未登入，無法獲取購買計數流');
        yield {};
        return;
      }

      final uid = userData['uid'] ?? 'default';
      await for (final doc in FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()) {
        if (doc.exists) {
          final userData = doc.data() as Map<String, dynamic>?;
          if (userData != null && userData.containsKey('purchaseCounts')) {
            yield Map<String, int>.from(userData['purchaseCounts'] ?? {});
          } else {
            yield <String, int>{};
          }
        } else {
          yield <String, int>{};
        }
      }
    } catch (e) {
      LoggerService.error('創建購買計數流失敗: $e');
      yield {};
    }
  }

  /// 初始化用戶的購買計數
  static Future<bool> initializePurchaseCounts() async {
    try {
      final currentUser = await UserService.getCurrentUserData();
      if (currentUser == null) {
        LoggerService.warning('用戶未登入，無法初始化購買計數');
        return false;
      }

      final uid = currentUser['uid'] ?? 'default';
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      final userDoc = await userRef.get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData.containsKey('purchaseCountsInitialized')) {
          LoggerService.info('用戶購買計數已初始化，跳過初始化步驟');
          return true;
        }
      }

      // 初始化購買計數
      await userRef.update({
        'purchaseCounts': {},
        'purchaseCountsInitialized': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      LoggerService.info('用戶購買計數初始化成功');
      return true;
    } catch (e) {
      LoggerService.error('初始化購買計數失敗: $e');
      return false;
    }
  }
}
