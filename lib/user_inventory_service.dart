import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';

class UserInventoryService {
  static const String _inventoryCollection = 'user_inventory';
  
  /// 首次登入時初始化用戶庫存
  static Future<void> initializeUserInventory() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) {
        LoggerService.warning('用戶未登入，無法初始化庫存');
        return;
      }
      
      final uid = userData['uid'] ?? 'default';
      LoggerService.info('開始初始化用戶庫存: $uid');
      
      // 檢查是否已經初始化過
      final existingInventory = await _checkInventoryExists(uid);
      if (existingInventory) {
        LoggerService.info('用戶庫存已存在，跳過初始化');
        return;
      }
      
      // 定義所有商城類別和徽章
      final categories = ['造型', '特效', '主題桌鋪', '飼料'];
      final badgeCategory = '徽章';
      
      for (final category in categories) {
        await _initializeCategoryInventory(uid, category);
      }
      
      // 初始化徽章庫存
      await _initializeBadgeInventory(uid, badgeCategory);
      
      LoggerService.info('用戶庫存初始化完成');
    } catch (e) {
      LoggerService.error('初始化用戶庫存失敗: $e');
    }
  }
  
  /// 檢查用戶庫存是否已存在
  static Future<bool> _checkInventoryExists(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .get();
      
      return doc.exists;
    } catch (e) {
      LoggerService.error('檢查用戶庫存失敗: $e');
      return false;
    }
  }
  
  /// 初始化特定類別的庫存
  static Future<void> _initializeCategoryInventory(String uid, String category) async {
    try {
      LoggerService.info('初始化類別庫存: $category');
      
      // 從主資料庫讀取該類別的所有商品
      final querySnapshot = await FirebaseFirestore.instance
          .collection(category)
          .get();
      
      final List<Map<String, dynamic>> categoryItems = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        // 複製商品資料到用戶庫存，初始狀態為"未擁有"
        categoryItems.add({
          'id': doc.id,
          'name': data['name'] ?? '未命名商品',
          '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
          'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
          'price': data['price'] ?? data['價格'] ?? 0,
          'description': data['description'] ?? '',
          '常見度': data['常見度'] ?? data['popularity'] ?? '常見',
          'category': category,
          'status': '未擁有', // 初始狀態
          'purchasedAt': null,
          'originalDocId': doc.id, // 保存原始文檔ID的引用
        });
      }
      
      // 將該類別的商品保存到用戶庫存
      await FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .collection(category)
          .doc('items')
          .set({
            'items': categoryItems,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      
      LoggerService.info('類別 $category 庫存初始化完成，共 ${categoryItems.length} 個商品');
    } catch (e) {
      LoggerService.error('初始化類別 $category 庫存失敗: $e');
    }
  }
  
  /// 初始化徽章庫存
  static Future<void> _initializeBadgeInventory(String uid, String category) async {
    try {
      LoggerService.info('初始化徽章庫存: $category');
      
      // 從主資料庫讀取所有徽章
      final querySnapshot = await FirebaseFirestore.instance
          .collection(category)
          .get();
      
      final List<Map<String, dynamic>> badgeItems = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        // 複製徽章資料到用戶庫存，初始狀態為"未擁有"
        badgeItems.add({
          'id': doc.id,
          'name': data['name'] ?? '未命名徽章',
          '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
          'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
          '稀有度': data['稀有度'] ?? data['rarity'] ?? '普通',
          'rarity': data['稀有度'] ?? data['rarity'] ?? '普通',
          '達成條件': data['達成條件'] ?? data['requirement'] ?? '未知條件',
          'requirement': data['達成條件'] ?? data['requirement'] ?? '未知條件',
          'category': category,
          'status': '未擁有', // 初始狀態
          'obtainedAt': null,
          'originalDocId': doc.id, // 保存原始文檔ID的引用
        });
      }
      
      // 將徽章保存到用戶庫存
      await FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .collection(category)
          .doc('items')
          .set({
            'items': badgeItems,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      
      LoggerService.info('徽章庫存初始化完成，共 ${badgeItems.length} 個徽章');
      
      // 初始化完成後，立即檢查並解鎖基於等級的頭像
      await _initializeLevelBasedAvatars(uid, badgeItems);
    } catch (e) {
      LoggerService.error('初始化徽章庫存失敗: $e');
    }
  }
  
  /// 初始化基於等級的頭像解鎖
  static Future<void> _initializeLevelBasedAvatars(String uid, List<Map<String, dynamic>> badgeItems) async {
    try {
      // 獲取用戶當前等級
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;
      
      final currentLevel = userData['level'] ?? 1;
      
      // 等級解鎖頭像配置
      const Map<int, String> levelAvatarUnlocks = {
        1: '頭像3',   // 等級1時獲得頭像3
        5: '頭像2',   // 等級5時獲得頭像2
        11: '頭像4',  // 等級11時獲得頭像4
        21: '頭像5',  // 等級21時獲得頭像5
        31: '頭像6',  // 等級31時獲得頭像6
      };
      
      // 檢查需要解鎖的頭像
      final avatarsToUnlock = <String>[];
      for (final entry in levelAvatarUnlocks.entries) {
        if (currentLevel >= entry.key) {
          avatarsToUnlock.add(entry.value);
        }
      }
      
      if (avatarsToUnlock.isNotEmpty) {
        // 更新需要解鎖的頭像狀態
        final updatedBadges = List<Map<String, dynamic>>.from(badgeItems);
        
        for (final avatarName in avatarsToUnlock) {
          final badgeIndex = updatedBadges.indexWhere((badge) => badge['name'] == avatarName);
          if (badgeIndex != -1) {
            updatedBadges[badgeIndex]['status'] = '已擁有';
            updatedBadges[badgeIndex]['obtainedAt'] = FieldValue.serverTimestamp();
          }
        }
        
        // 保存更新後的徽章列表
        await FirebaseFirestore.instance
            .collection(_inventoryCollection)
            .doc(uid)
            .collection('徽章')
            .doc('items')
            .update({
              'items': updatedBadges,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
        
        LoggerService.info('初始化時解鎖了基於等級的頭像: $avatarsToUnlock');
      }
    } catch (e) {
      LoggerService.error('初始化基於等級的頭像解鎖失敗: $e');
    }
  }
  
  /// 獲取用戶指定類別的商品
  static Future<List<Map<String, dynamic>>> getUserCategoryItems(String category) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return [];
      
      final uid = userData['uid'] ?? 'default';
      
      final doc = await FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .collection(category)
          .doc('items')
          .get();
      
      if (!doc.exists) {
        LoggerService.warning('用戶庫存中不存在類別: $category');
        return [];
      }
      
      final data = doc.data();
      final items = List<Map<String, dynamic>>.from(data?['items'] ?? []);
      
      LoggerService.info('獲取用戶類別 $category 商品，共 ${items.length} 個');
      return items;
    } catch (e) {
      LoggerService.error('獲取用戶類別商品失敗: $e');
      return [];
    }
  }
  
  /// 獲取用戶已擁有的商品
  static Future<List<Map<String, dynamic>>> getUserOwnedItems(String category) async {
    try {
      final allItems = await getUserCategoryItems(category);
      final ownedItems = allItems.where((item) => item['status'] == '已擁有').toList();
      
      LoggerService.info('獲取用戶已擁有類別 $category 商品，共 ${ownedItems.length} 個');
      return ownedItems;
    } catch (e) {
      LoggerService.error('獲取用戶已擁有商品失敗: $e');
      return [];
    }
  }
  
  /// 獲取用戶已擁有的徽章
  static Future<List<Map<String, dynamic>>> getUserObtainedBadges() async {
    try {
      final allBadges = await getUserCategoryItems('徽章');
      final obtainedBadges = allBadges.where((badge) => badge['status'] == '已擁有').toList();
      
      LoggerService.info('獲取用戶已擁有徽章，共 ${obtainedBadges.length} 個');
      return obtainedBadges;
    } catch (e) {
      LoggerService.error('獲取用戶已擁有徽章失敗: $e');
      return [];
    }
  }
  
  /// 購買商品（更新用戶庫存中的狀態）
  static Future<bool> purchaseItem(String category, String itemId) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;
      
      final uid = userData['uid'] ?? 'default';
      
      // 獲取該類別的所有商品
      final allItems = await getUserCategoryItems(category);
      
      // 找到要購買的商品
      final itemIndex = allItems.indexWhere((item) => item['id'] == itemId);
      if (itemIndex == -1) {
        LoggerService.warning('找不到要購買的商品: $itemId');
        return false;
      }
      
      // 更新商品狀態
      allItems[itemIndex]['status'] = '已擁有';
      allItems[itemIndex]['purchasedAt'] = FieldValue.serverTimestamp();
      
      // 保存更新後的商品列表
      await FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .collection(category)
          .doc('items')
          .update({
            'items': allItems,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      
      LoggerService.info('成功購買商品: $itemId，類別: $category');
      return true;
    } catch (e) {
      LoggerService.error('購買商品失敗: $e');
      return false;
    }
  }
  
  /// 獲得徽章（更新用戶庫存中的狀態）
  static Future<bool> obtainBadge(String badgeId) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;
      
      final uid = userData['uid'] ?? 'default';
      
      // 獲取所有徽章
      final allBadges = await getUserCategoryItems('徽章');
      
      // 找到要獲得的徽章
      final badgeIndex = allBadges.indexWhere((badge) => badge['id'] == badgeId);
      if (badgeIndex == -1) {
        LoggerService.warning('找不到要獲得的徽章: $badgeId');
        return false;
      }
      
      // 更新徽章狀態
      allBadges[badgeIndex]['status'] = '已擁有';
      allBadges[badgeIndex]['obtainedAt'] = FieldValue.serverTimestamp();
      
      // 保存更新後的徽章列表
      await FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .collection('徽章')
          .doc('items')
          .update({
            'items': allBadges,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      
      LoggerService.info('成功獲得徽章: $badgeId');
      return true;
    } catch (e) {
      LoggerService.error('獲得徽章失敗: $e');
      return false;
    }
  }
  
  /// 檢查商品是否已擁有
  static Future<bool> isItemOwned(String category, String itemId) async {
    try {
      final allItems = await getUserCategoryItems(category);
      final item = allItems.firstWhere(
        (item) => item['id'] == itemId,
        orElse: () => <String, dynamic>{},
      );
      
      return item['status'] == '已擁有';
    } catch (e) {
      LoggerService.error('檢查商品擁有狀態失敗: $e');
      return false;
    }
  }
  
  /// 檢查徽章是否已獲得
  static Future<bool> isBadgeObtained(String badgeId) async {
    try {
      final allBadges = await getUserCategoryItems('徽章');
      final badge = allBadges.firstWhere(
        (badge) => badge['id'] == badgeId,
        orElse: () => <String, dynamic>{},
      );
      
      return badge['status'] == '已擁有';
    } catch (e) {
      LoggerService.error('檢查徽章獲得狀態失敗: $e');
      return false;
    }
  }
  
  /// 更新商品狀態（用於等級解鎖等）
  static Future<bool> updateItemStatus(String category, String itemId, String newStatus) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;
      
      final uid = userData['uid'] ?? 'default';
      
      // 獲取該類別的所有商品
      final allItems = await getUserCategoryItems(category);
      
      // 找到要更新的商品
      final itemIndex = allItems.indexWhere((item) => item['id'] == itemId);
      if (itemIndex == -1) {
        LoggerService.warning('找不到要更新的商品: $itemId');
        return false;
      }
      
      // 更新商品狀態
      allItems[itemIndex]['status'] = newStatus;
      if (newStatus == '已擁有') {
        allItems[itemIndex]['purchasedAt'] = FieldValue.serverTimestamp();
      }
      
      // 保存更新後的商品列表
      await FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .collection(category)
          .doc('items')
          .update({
            'items': allItems,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      
      LoggerService.info('成功更新商品狀態: $itemId，新狀態: $newStatus');
      return true;
    } catch (e) {
      LoggerService.error('更新商品狀態失敗: $e');
      return false;
    }
  }
  
  /// 更新徽章狀態
  static Future<bool> updateBadgeStatus(String badgeId, String newStatus) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return false;
      
      final uid = userData['uid'] ?? 'default';
      
      // 獲取所有徽章
      final allBadges = await getUserCategoryItems('徽章');
      
      // 找到要更新的徽章
      final badgeIndex = allBadges.indexWhere((badge) => badge['id'] == badgeId);
      if (badgeIndex == -1) {
        LoggerService.warning('找不到要更新的徽章: $badgeId');
        return false;
      }
      
      // 更新徽章狀態
      allBadges[badgeIndex]['status'] = newStatus;
      if (newStatus == '已擁有') {
        allBadges[badgeIndex]['obtainedAt'] = FieldValue.serverTimestamp();
      }
      
      // 保存更新後的徽章列表
      await FirebaseFirestore.instance
          .collection(_inventoryCollection)
          .doc(uid)
          .collection('徽章')
          .doc('items')
          .update({
            'items': allBadges,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      
      LoggerService.info('成功更新徽章狀態: $badgeId，新狀態: $newStatus');
      return true;
    } catch (e) {
      LoggerService.error('更新徽章狀態失敗: $e');
      return false;
    }
  }
  
  /// 同步主資料庫的新商品到用戶庫存
  static Future<void> syncNewItemsFromMainDatabase() async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;
      
      final uid = userData['uid'] ?? 'default';
      LoggerService.info('開始同步主資料庫新商品到用戶庫存');
      
      // 檢查用戶庫存是否存在，如果不存在則初始化
      final inventoryExists = await _checkInventoryExists(uid);
      if (!inventoryExists) {
        LoggerService.info('用戶庫存不存在，開始初始化');
        // 直接調用初始化方法的核心邏輯，避免重複檢查
        final categories = ['造型', '特效', '頭像', '主題桌鋪', '飼料'];
        final badgeCategory = '徽章';
        
        for (final category in categories) {
          await _initializeCategoryInventory(uid, category);
        }
        
        // 初始化徽章庫存
        await _initializeBadgeInventory(uid, badgeCategory);
        
        LoggerService.info('用戶庫存初始化完成');
        return;
      }
      
      final categories = ['造型', '特效', '頭像', '主題桌鋪', '飼料'];
      
      for (final category in categories) {
        await _syncNewItemsForCategory(uid, category);
      }
      
      // 同步新徽章
      await _syncNewBadgesFromMainDatabase(uid);
      
      LoggerService.info('同步主資料庫新商品完成');
    } catch (e) {
      LoggerService.error('同步主資料庫新商品失敗: $e');
    }
  }
  
  /// 同步特定類別的新商品
  static Future<void> _syncNewItemsForCategory(String uid, String category) async {
    try {
      // 獲取用戶現有庫存
      final userItems = await getUserCategoryItems(category);
      final userItemIds = userItems.map((item) => item['originalDocId']).toSet();
      
      // 獲取主資料庫的所有商品
      final querySnapshot = await FirebaseFirestore.instance
          .collection(category)
          .get();
      
      final List<Map<String, dynamic>> newItems = [];
      
      for (final doc in querySnapshot.docs) {
        // 檢查是否為新商品
        if (!userItemIds.contains(doc.id)) {
          final data = doc.data();
          
          newItems.add({
            'id': doc.id,
            'name': data['name'] ?? '未命名商品',
            '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
            'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
            'price': data['price'] ?? data['價格'] ?? 0,
            'description': data['description'] ?? '',
            '常見度': data['常見度'] ?? data['popularity'] ?? '常見',
            'category': category,
            'status': '未擁有',
            'purchasedAt': null,
            'originalDocId': doc.id,
          });
        }
      }
      
      // 如果有新商品，添加到用戶庫存
      if (newItems.isNotEmpty) {
        final updatedItems = [...userItems, ...newItems];
        
        await FirebaseFirestore.instance
            .collection(_inventoryCollection)
            .doc(uid)
            .collection(category)
            .doc('items')
            .update({
              'items': updatedItems,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
        
        LoggerService.info('類別 $category 同步了 ${newItems.length} 個新商品');
      }
    } catch (e) {
      LoggerService.error('同步類別 $category 新商品失敗: $e');
    }
  }
  
  /// 同步主資料庫的新徽章到用戶庫存
  static Future<void> _syncNewBadgesFromMainDatabase(String uid) async {
    try {
      // 獲取用戶現有徽章
      final userBadges = await getUserCategoryItems('徽章');
      final userBadgeIds = userBadges.map((badge) => badge['originalDocId']).toSet();
      
      // 獲取主資料庫的所有徽章
      final querySnapshot = await FirebaseFirestore.instance
          .collection('徽章')
          .get();
      
      final List<Map<String, dynamic>> newBadges = [];
      
      for (final doc in querySnapshot.docs) {
        // 檢查是否為新徽章
        if (!userBadgeIds.contains(doc.id)) {
          final data = doc.data();
          
          newBadges.add({
            'id': doc.id,
            'name': data['name'] ?? '未命名徽章',
            '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
            'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
            '稀有度': data['稀有度'] ?? data['rarity'] ?? '普通',
            'rarity': data['稀有度'] ?? data['rarity'] ?? '普通',
            '達成條件': data['達成條件'] ?? data['requirement'] ?? '未知條件',
            'requirement': data['達成條件'] ?? data['requirement'] ?? '未知條件',
            'category': '徽章',
            'status': '未擁有',
            'obtainedAt': null,
            'originalDocId': doc.id,
          });
        }
      }
      
      // 如果有新徽章，添加到用戶庫存
      if (newBadges.isNotEmpty) {
        final updatedBadges = [...userBadges, ...newBadges];
        
        await FirebaseFirestore.instance
            .collection(_inventoryCollection)
            .doc(uid)
            .collection('徽章')
            .doc('items')
            .update({
              'items': updatedBadges,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
        
        LoggerService.info('同步了 ${newBadges.length} 個新徽章');
      }
    } catch (e) {
      LoggerService.error('同步新徽章失敗: $e');
    }
  }
}
