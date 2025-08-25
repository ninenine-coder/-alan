import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';

class UserPurchaseService {
  static const String _usersCollection = 'users';

  /// 獲取用戶的購買記錄
  static Future<Map<String, int>> getUserPurchaseCounts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return {};

      final userData = userDoc.data() as Map<String, dynamic>;
      final purchaseCounts = Map<String, int>.from(userData['purchaseCounts'] ?? {});
      
      return purchaseCounts;
    } catch (e) {
      LoggerService.error('獲取用戶購買記錄失敗: $e');
      return {};
    }
  }

  /// 增加商品的購買次數
  static Future<bool> incrementPurchaseCount(String itemId, String itemName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        LoggerService.error('用戶未登入，無法更新購買次數');
        return false;
      }

      LoggerService.info('開始更新購買次數: $itemName (ID: $itemId), 用戶ID: ${user.uid}');

      final userRef = FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final purchaseCounts = Map<String, int>.from(userData['purchaseCounts'] ?? {});
          
          final oldCount = purchaseCounts[itemId] ?? 0;
          // 增加購買次數
          purchaseCounts[itemId] = oldCount + 1;
          
          LoggerService.info('更新購買次數: $itemName (ID: $itemId) 從 $oldCount 增加到 ${purchaseCounts[itemId]}');
          
          transaction.update(userRef, {
            'purchaseCounts': purchaseCounts,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // 如果用戶文檔不存在，創建新的
          LoggerService.info('用戶文檔不存在，創建新的購買記錄: $itemName (ID: $itemId)');
          transaction.set(userRef, {
            'purchaseCounts': {itemId: 1},
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });

      LoggerService.info('購買次數更新成功: $itemName (ID: $itemId)');
      return true;
    } catch (e) {
      LoggerService.error('更新購買次數失敗: $e');
      return false;
    }
  }

  /// 獲取特定商品的購買次數
  static Future<int> getPurchaseCount(String itemId) async {
    try {
      final purchaseCounts = await getUserPurchaseCounts();
      return purchaseCounts[itemId] ?? 0;
    } catch (e) {
      LoggerService.error('獲取商品購買次數失敗: $e');
      return 0;
    }
  }

  /// 獲取用戶購買記錄的實時流
  static Stream<Map<String, int>> getUserPurchaseCountsStream() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        LoggerService.error('用戶未登入，無法獲取購買記錄流');
        return Stream.value({});
      }

      LoggerService.info('開始監聽用戶購買記錄流，用戶ID: ${user.uid}');

      return FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .snapshots()
          .map((doc) {
        LoggerService.info('Firebase 文檔更新事件觸發，文檔存在: ${doc.exists}');
        
        if (!doc.exists) {
          LoggerService.info('用戶文檔不存在，返回空購買記錄');
          return {};
        }
        
        final userData = doc.data() as Map<String, dynamic>;
        LoggerService.info('用戶文檔數據: $userData');
        
        final purchaseCounts = Map<String, int>.from(userData['purchaseCounts'] ?? {});
        
        LoggerService.info('收到購買記錄更新: $purchaseCounts');
        return purchaseCounts;
      });
    } catch (e) {
      LoggerService.error('獲取用戶購買記錄流失敗: $e');
      return Stream.value({});
    }
  }

  /// 初始化用戶的購買記錄
  static Future<bool> initializePurchaseCounts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userRef = FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid);

      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        // 如果用戶文檔不存在，創建新的
        await userRef.set({
          'purchaseCounts': {},
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        LoggerService.info('用戶購買記錄初始化完成');
      } else {
        // 如果用戶文檔存在但沒有購買記錄欄位，添加該欄位
        final userData = userDoc.data() as Map<String, dynamic>;
        if (!userData.containsKey('purchaseCounts')) {
          await userRef.update({
            'purchaseCounts': {},
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          LoggerService.info('用戶購買記錄欄位添加完成');
        }
      }
      
      return true;
    } catch (e) {
      LoggerService.error('初始化用戶購買記錄失敗: $e');
      return false;
    }
  }
}
