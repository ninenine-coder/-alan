import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'experience_service.dart';
import 'logger_service.dart';

class UnifiedUserDataService {
  static const String _usersCollection = 'users';

  /// 首次登入時初始化用戶所有資料
  static Future<void> initializeUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        LoggerService.warning('用戶未登入，無法初始化資料');
        return;
      }

      final uid = user.uid;
      LoggerService.info('開始初始化用戶統一資料: $uid');

      // 檢查用戶文檔是否存在
      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        LoggerService.warning('用戶文檔不存在，跳過資料初始化');
        return;
      }

      final userData = userDoc.data()!;
      final updates = <String, dynamic>{};

      // 1. 初始化商城商品
      if (!userData.containsKey('ownedProducts')) {
        final ownedProducts = await _initializeOwnedProducts();
        updates['ownedProducts'] = ownedProducts;
        LoggerService.info('初始化商城商品: ${ownedProducts.length} 個商品');
      }

      // 2. 初始化頭像（強制重新初始化以確保正確）
      final avatars = await _initializeAvatars();
      updates['avatars'] = avatars;
      LoggerService.info('初始化頭像: ${avatars.length} 個頭像');

      // 3. 初始化徽章
      if (!userData.containsKey('medals')) {
        final medals = await _initializeMedals();
        updates['medals'] = medals;
        LoggerService.info('初始化徽章: ${medals.length} 個徽章');
      }

      // 如果有需要更新的資料，寫入 Firebase
      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection(_usersCollection)
            .doc(uid)
            .update(updates);
        
        LoggerService.info('用戶統一資料初始化完成');
      } else {
        LoggerService.info('用戶統一資料已存在，跳過初始化');
      }
    } catch (e) {
      LoggerService.error('初始化用戶統一資料失敗: $e');
    }
  }

  /// 初始化商城商品（所有商品 owned=false）
  static Future<Map<String, bool>> _initializeOwnedProducts() async {
    final ownedProducts = <String, bool>{};
    
    // 商城類別
    final categories = ['造型', '特效', '主題桌布', '飼料'];
    
    for (final category in categories) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection(category)
            .get();
        
        for (final doc in querySnapshot.docs) {
          ownedProducts[doc.id] = false; // 初始狀態為未擁有
        }
      } catch (e) {
        LoggerService.error('初始化類別 $category 失敗: $e');
      }
    }
    
    return ownedProducts;
  }

  /// 初始化頭像（依等級可解鎖的頭像 owned=true，其他 owned=false）
  static Future<Map<String, bool>> _initializeAvatars() async {
    final avatars = <String, bool>{};
    
    try {
      // 獲取當前等級
      final experienceData = await ExperienceService.getCurrentExperience();
      final currentLevel = experienceData['level'] as int;
      
      // 從 Firebase 獲取所有頭像資料
      final avatarSnapshot = await FirebaseFirestore.instance
          .collection('頭像')
          .get();
      
      // 頭像等級解鎖配置（使用 Firebase 中的實際 ID）
      final levelAvatarUnlocks = <int, String>{};
      
      // 根據 Firebase 中的頭像資料建立等級解鎖配置
      for (final doc in avatarSnapshot.docs) {
        final data = doc.data();
        final avatarId = doc.id;
        
        // 記錄頭像資訊以供調試
        LoggerService.info('Firebase 頭像資料: ID=${doc.id}, name=${data['name']}, 完整資料: $data');
        
        // 簡化的等級解鎖機制：等級1獲得第一個頭像，之後每隔10等獲得下一個頭像
        final avatarName = data['name'] ?? '';
        
        // 根據頭像名稱或ID來判斷等級解鎖
        if (avatarName == '見習旅人' || avatarName == '頭像2' || avatarId.contains('avatar_1') || doc.id == 'avatar_1') {
          levelAvatarUnlocks[1] = avatarId;
          LoggerService.info('設定等級1頭像: $avatarName (ID: $avatarId)');
        } else if (avatarName == '城市巡查員' || avatarName == '頭像3' || avatarId.contains('avatar_2') || doc.id == 'avatar_2') {
          levelAvatarUnlocks[11] = avatarId;
          LoggerService.info('設定等級11頭像: $avatarName (ID: $avatarId)');
        } else if (avatarName == '路線研究員' || avatarName == '頭像4' || avatarId.contains('avatar_3') || doc.id == 'avatar_3') {
          levelAvatarUnlocks[21] = avatarId;
          LoggerService.info('設定等級21頭像: $avatarName (ID: $avatarId)');
        } else if (avatarName == '夜行攝影' || avatarName == '頭像5' || avatarId.contains('avatar_4') || doc.id == 'avatar_4') {
          levelAvatarUnlocks[31] = avatarId;
          LoggerService.info('設定等級31頭像: $avatarName (ID: $avatarId)');
        } else if (avatarName == '終極協調員' || avatarName == '頭像6' || avatarId.contains('avatar_5') || doc.id == 'avatar_5') {
          levelAvatarUnlocks[41] = avatarId;
          LoggerService.info('設定等級41頭像: $avatarName (ID: $avatarId)');
        }
        // 可以繼續添加更多頭像...
      }
      
             // 初始化所有頭像狀態
       for (final doc in avatarSnapshot.docs) {
         final avatarId = doc.id;
         
         // 檢查是否在等級解鎖配置中
         bool isUnlocked = false;
         for (final entry in levelAvatarUnlocks.entries) {
           if (entry.value == avatarId) {
             isUnlocked = currentLevel >= entry.key;
             LoggerService.info('頭像 $avatarId 等級要求: ${entry.key}, 當前等級: $currentLevel, 是否解鎖: $isUnlocked');
             break;
           }
         }
         
         // 如果沒有找到等級配置，默認不解鎖
         if (!levelAvatarUnlocks.containsValue(avatarId)) {
           isUnlocked = false;
           LoggerService.info('頭像 $avatarId 沒有等級配置，設為未解鎖');
         }
         
         avatars[avatarId] = isUnlocked;
         LoggerService.info('設置頭像 $avatarId 狀態為: $isUnlocked');
       }
      
      LoggerService.info('初始化頭像，用戶等級: $currentLevel，頭像數量: ${avatars.length}');
    } catch (e) {
      LoggerService.error('初始化頭像失敗: $e');
      // 如果獲取失敗，返回空 map
    }
    
    return avatars;
  }

  /// 初始化徽章（所有徽章 owned=false）
  static Future<Map<String, bool>> _initializeMedals() async {
    final medals = <String, bool>{};
    
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('徽章')
          .get();
      
      for (final doc in querySnapshot.docs) {
        medals[doc.id] = false; // 初始狀態為未獲得
      }
    } catch (e) {
      LoggerService.error('初始化徽章失敗: $e');
    }
    
    return medals;
  }

  /// 購買商品（更新 ownedProducts）
  static Future<bool> purchaseProduct(String productId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .update({'ownedProducts.$productId': true});

      LoggerService.info('成功購買商品: $productId');
      return true;
    } catch (e) {
      LoggerService.error('購買商品失敗: $e');
      return false;
    }
  }

  /// 解鎖頭像（更新 avatars）
  static Future<bool> unlockAvatar(String avatarId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .update({'avatars.$avatarId': true});

      LoggerService.info('成功解鎖頭像: $avatarId');
      return true;
    } catch (e) {
      LoggerService.error('解鎖頭像失敗: $e');
      return false;
    }
  }

  /// 獲得徽章（更新 medals）
  static Future<bool> obtainMedal(String medalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .update({'medals.$medalId': true});

      LoggerService.info('成功獲得徽章: $medalId');
      return true;
    } catch (e) {
      LoggerService.error('獲得徽章失敗: $e');
      return false;
    }
  }

  /// 獲取用戶已擁有的商品（包含完整商品資料）
  static Future<List<Map<String, dynamic>>> getOwnedProducts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final ownedProducts = Map<String, bool>.from(userData['ownedProducts'] ?? {});

      final ownedList = <Map<String, dynamic>>[];
      
      // 商城類別
      final categories = ['造型', '特效', '主題桌布', '飼料'];
      
      for (final category in categories) {
        try {
          final querySnapshot = await FirebaseFirestore.instance
              .collection(category)
              .get();
          
          for (final doc in querySnapshot.docs) {
            if (ownedProducts[doc.id] == true) {
              final data = doc.data();
              ownedList.add({
                'id': doc.id,
                'name': data['name'] ?? '未命名商品',
                '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
                'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
                'category': category,
                'status': '已擁有',
                'price': data['price'] ?? data['價格'] ?? 0,
                'description': data['description'] ?? '',
                '常見度': data['常見度'] ?? data['popularity'] ?? '常見',
              });
            }
          }
        } catch (e) {
          LoggerService.error('獲取類別 $category 已擁有商品失敗: $e');
        }
      }

      LoggerService.info('獲取已擁有商品: ${ownedList.length} 個');
      return ownedList;
    } catch (e) {
      LoggerService.error('獲取已擁有商品失敗: $e');
      return [];
    }
  }

  /// 獲取用戶已解鎖的頭像（包含完整頭像資料）
  static Future<List<Map<String, dynamic>>> getUnlockedAvatars() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final avatars = Map<String, bool>.from(userData['avatars'] ?? {});

      final unlockedList = <Map<String, dynamic>>[];
      
             // 從 Firebase 獲取頭像資料
       try {
         final avatarSnapshot = await FirebaseFirestore.instance
             .collection('頭像')
             .get();
         
         LoggerService.info('從 Firebase 獲取到 ${avatarSnapshot.docs.length} 個頭像');
         LoggerService.info('用戶頭像狀態: $avatars');
         
         for (final doc in avatarSnapshot.docs) {
           final avatarId = doc.id;
           final isOwned = avatars[avatarId] ?? false;
           LoggerService.info('檢查頭像 $avatarId: 是否擁有 = $isOwned');
           
           if (isOwned) {
             final data = doc.data();
             LoggerService.info('添加已擁有的頭像: ${data['name']} (ID: $avatarId)');
             unlockedList.add({
               'id': avatarId,
               'name': data['name'] ?? '未命名頭像',
               '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
               'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
               'category': '頭像',
               'status': '已擁有',
               'description': data['description'] ?? '',
               'unlockLevel': await _getAvatarUnlockLevel(avatarId),
             });
           }
         }
       } catch (e) {
         LoggerService.error('獲取頭像資料失敗: $e');
       }

      LoggerService.info('獲取已解鎖頭像: ${unlockedList.length} 個');
      return unlockedList;
    } catch (e) {
      LoggerService.error('獲取已解鎖頭像失敗: $e');
      return [];
    }
  }

  /// 獲取用戶已獲得的徽章（包含完整徽章資料）
  static Future<List<Map<String, dynamic>>> getObtainedMedals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final medals = Map<String, bool>.from(userData['medals'] ?? {});

      final obtainedList = <Map<String, dynamic>>[];
      
      // 從 Firebase 獲取徽章資料
      try {
        final medalSnapshot = await FirebaseFirestore.instance
            .collection('徽章')
            .get();
        
        for (final doc in medalSnapshot.docs) {
          final medalId = doc.id;
          if (medals[medalId] == true) {
            final data = doc.data();
            obtainedList.add({
              'id': medalId,
              'name': data['name'] ?? '未命名徽章',
              '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
              'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
              'category': '徽章',
              'status': '已獲得',
              'description': data['description'] ?? '',
              'taskDescription': data['taskDescription'] ?? '',
            });
          }
        }
      } catch (e) {
        LoggerService.error('獲取徽章資料失敗: $e');
      }

      LoggerService.info('獲取已獲得徽章: ${obtainedList.length} 個');
      return obtainedList;
    } catch (e) {
      LoggerService.error('獲取已獲得徽章失敗: $e');
      return [];
    }
  }

  /// 檢查商品是否已擁有
  static Future<bool> isProductOwned(String productId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final ownedProducts = Map<String, bool>.from(userData['ownedProducts'] ?? {});

      return ownedProducts[productId] ?? false;
    } catch (e) {
      LoggerService.error('檢查商品擁有狀態失敗: $e');
      return false;
    }
  }

  /// 檢查頭像是否已解鎖
  static Future<bool> isAvatarUnlocked(String avatarId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final avatars = Map<String, bool>.from(userData['avatars'] ?? {});

      return avatars[avatarId] ?? false;
    } catch (e) {
      LoggerService.error('檢查頭像解鎖狀態失敗: $e');
      return false;
    }
  }

  /// 檢查徽章是否已獲得
  static Future<bool> isMedalObtained(String medalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final medals = Map<String, bool>.from(userData['medals'] ?? {});

      return medals[medalId] ?? false;
    } catch (e) {
      LoggerService.error('檢查徽章獲得狀態失敗: $e');
      return false;
    }
  }

  /// 根據等級解鎖頭像
  static Future<void> unlockAvatarsByLevel() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 獲取當前等級
      final experienceData = await ExperienceService.getCurrentExperience();
      final currentLevel = experienceData['level'] as int;

      // 從 Firebase 獲取所有頭像資料
      final avatarSnapshot = await FirebaseFirestore.instance
          .collection('頭像')
          .get();

      // 頭像等級解鎖配置（使用 Firebase 中的實際 ID）
      final levelAvatarUnlocks = <int, String>{};
      
      // 根據 Firebase 中的頭像資料建立等級解鎖配置
      for (final doc in avatarSnapshot.docs) {
        final data = doc.data();
        final avatarId = doc.id;
        
        // 記錄頭像資訊以供調試
        LoggerService.info('Firebase 頭像資料: ID=${doc.id}, name=${data['name']}, 完整資料: $data');
        
        // 簡化的等級解鎖機制：等級1獲得第一個頭像，之後每隔10等獲得下一個頭像
        final avatarName = data['name'] ?? '';
        
        // 根據頭像名稱或ID來判斷等級解鎖
        if (avatarName == '見習旅人' || avatarName == '頭像2' || avatarId.contains('avatar_1') || doc.id == 'avatar_1') {
          levelAvatarUnlocks[1] = avatarId;
          LoggerService.info('設定等級1頭像: $avatarName (ID: $avatarId)');
        } else if (avatarName == '城市巡查員' || avatarName == '頭像3' || avatarId.contains('avatar_2') || doc.id == 'avatar_2') {
          levelAvatarUnlocks[11] = avatarId;
          LoggerService.info('設定等級11頭像: $avatarName (ID: $avatarId)');
        } else if (avatarName == '路線研究員' || avatarName == '頭像4' || avatarId.contains('avatar_3') || doc.id == 'avatar_3') {
          levelAvatarUnlocks[21] = avatarId;
          LoggerService.info('設定等級21頭像: $avatarName (ID: $avatarId)');
        } else if (avatarName == '夜行攝影' || avatarName == '頭像5' || avatarId.contains('avatar_4') || doc.id == 'avatar_4') {
          levelAvatarUnlocks[31] = avatarId;
          LoggerService.info('設定等級31頭像: $avatarName (ID: $avatarId)');
        } else if (avatarName == '終極協調員' || avatarName == '頭像6' || avatarId.contains('avatar_5') || doc.id == 'avatar_5') {
          levelAvatarUnlocks[41] = avatarId;
          LoggerService.info('設定等級41頭像: $avatarName (ID: $avatarId)');
        }
        // 可以繼續添加更多頭像...
      }

      // 獲取當前頭像狀態
      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final currentAvatars = Map<String, bool>.from(userData['avatars'] ?? {});
      final updates = <String, dynamic>{};

      // 檢查需要解鎖的頭像
      for (final entry in levelAvatarUnlocks.entries) {
        final requiredLevel = entry.key;
        final avatarId = entry.value;
        
        if (currentLevel >= requiredLevel && !(currentAvatars[avatarId] ?? false)) {
          updates['avatars.$avatarId'] = true;
          
          // 獲取頭像名稱用於日誌
          final avatarDoc = avatarSnapshot.docs.firstWhere(
            (doc) => doc.id == avatarId,
            orElse: () => avatarSnapshot.docs.first,
          );
          final avatarName = avatarDoc.data()['name'] ?? avatarId;
          
          LoggerService.info('解鎖頭像: $avatarName (ID: $avatarId, 等級 $currentLevel >= $requiredLevel)');
        }
      }

      // 如果有需要解鎖的頭像，更新資料庫
      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection(_usersCollection)
            .doc(user.uid)
            .update(updates);

        LoggerService.info('根據等級解鎖頭像完成: ${updates.length} 個頭像');
      }
    } catch (e) {
      LoggerService.error('根據等級解鎖頭像失敗: $e');
    }
  }

  /// 獲取頭像解鎖等級
  static Future<int> _getAvatarUnlockLevel(String avatarId) async {
    try {
      // 從 Firebase 獲取頭像資料
      final avatarDoc = await FirebaseFirestore.instance
          .collection('頭像')
          .doc(avatarId)
          .get();

      if (!avatarDoc.exists) return 0;

      final data = avatarDoc.data()!;
      final avatarName = data['name'] ?? '';

      // 根據頭像名稱返回對應的等級（簡化機制）
      if (avatarName == '見習旅人' || avatarName == '頭像2') {
        return 1;
      } else if (avatarName == '城市巡查員' || avatarName == '頭像3') {
        return 11;
      } else if (avatarName == '路線研究員' || avatarName == '頭像4') {
        return 21;
      } else if (avatarName == '夜行攝影' || avatarName == '頭像5') {
        return 31;
      } else if (avatarName == '終極協調員' || avatarName == '頭像6') {
        return 41;
      }

      return 0;
    } catch (e) {
      LoggerService.error('獲取頭像解鎖等級失敗: $e');
      return 0;
    }
  }

  /// 獲取用戶完整資料（用於背包顯示）
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return null;

      return userDoc.data();
    } catch (e) {
      LoggerService.error('獲取用戶資料失敗: $e');
      return null;
    }
  }

  /// 獲取用戶指定類別的已擁有商品（按類別）
  static Future<List<Map<String, dynamic>>> getOwnedProductsByCategory(String category) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final ownedProducts = Map<String, bool>.from(userData['ownedProducts'] ?? {});

      final ownedList = <Map<String, dynamic>>[];
      
      try {
        LoggerService.info('正在查詢 Firebase 集合: $category');
        final querySnapshot = await FirebaseFirestore.instance
            .collection(category)
            .get();
        
        LoggerService.info('從 Firebase 獲取到 ${querySnapshot.docs.length} 個 $category 商品');
        
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final isOwned = ownedProducts[doc.id] ?? false;
          LoggerService.debug('商品 ${doc.id}: 名稱=${data['name']}, 是否擁有=$isOwned');
          
          if (isOwned) {
            ownedList.add({
              'id': doc.id,
              'name': data['name'] ?? '未命名商品',
              '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
              'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
              'category': category,
              'status': '已擁有',
              'price': data['price'] ?? data['價格'] ?? 0,
              'description': data['description'] ?? '',
              '常見度': data['常見度'] ?? data['popularity'] ?? '常見',
            });
            LoggerService.info('添加已擁有商品: ${data['name']} (ID: ${doc.id})');
          }
        }
      } catch (e) {
        LoggerService.error('獲取類別 $category 已擁有商品失敗: $e');
      }

      LoggerService.info('獲取 $category 類別已擁有商品: ${ownedList.length} 個');
      return ownedList;
    } catch (e) {
      LoggerService.error('獲取類別已擁有商品失敗: $e');
      return [];
    }
  }

  /// 獲取用戶指定類別的所有商品（包含未擁有的）
  static Future<List<Map<String, dynamic>>> getAllProductsByCategory(String category) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final ownedProducts = Map<String, bool>.from(userData['ownedProducts'] ?? {});

      final allList = <Map<String, dynamic>>[];
      
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection(category)
            .get();
        
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final isOwned = ownedProducts[doc.id] ?? false;
          
          allList.add({
            'id': doc.id,
            'name': data['name'] ?? '未命名商品',
            '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
            'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
            'category': category,
            'status': isOwned ? '已擁有' : '未擁有',
            'price': data['price'] ?? data['價格'] ?? 0,
            'description': data['description'] ?? '',
            '常見度': data['常見度'] ?? data['popularity'] ?? '常見',
          });
        }
        
        // 排序：已擁有的在前
        allList.sort((a, b) {
          final aOwned = a['status'] == '已擁有';
          final bOwned = b['status'] == '已擁有';
          if (aOwned && !bOwned) return -1;
          if (!aOwned && bOwned) return 1;
          return 0;
        });
        
      } catch (e) {
        LoggerService.error('獲取類別 $category 所有商品失敗: $e');
      }

      LoggerService.info('獲取 $category 類別所有商品: ${allList.length} 個');
      return allList;
    } catch (e) {
      LoggerService.error('獲取類別所有商品失敗: $e');
      return [];
    }
  }

  /// 獲取所有頭像（包含未解鎖的）
  static Future<List<Map<String, dynamic>>> getAllAvatars() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final avatars = Map<String, bool>.from(userData['avatars'] ?? {});

      // 獲取當前等級
      final experienceData = await ExperienceService.getCurrentExperience();
      final currentLevel = experienceData['level'] as int;

      final allList = <Map<String, dynamic>>[];
      
      // 從 Firebase 獲取頭像資料
      try {
        final avatarSnapshot = await FirebaseFirestore.instance
            .collection('頭像')
            .get();
        
        // 頭像等級解鎖配置（使用 Firebase 中的實際 ID）
        final levelAvatarUnlocks = <int, String>{};
        
                 // 根據 Firebase 中的頭像資料建立等級解鎖配置
         for (final doc in avatarSnapshot.docs) {
           final data = doc.data();
           final avatarId = doc.id;
           
           // 簡化的等級解鎖機制：等級1獲得頭像2，之後每隔10等獲得下一個頭像
           if (data['name'] == '頭像2') {
             levelAvatarUnlocks[1] = avatarId;
           } else if (data['name'] == '頭像3') {
             levelAvatarUnlocks[11] = avatarId;
           } else if (data['name'] == '頭像4') {
             levelAvatarUnlocks[21] = avatarId;
           } else if (data['name'] == '頭像5') {
             levelAvatarUnlocks[31] = avatarId;
           } else if (data['name'] == '頭像6') {
             levelAvatarUnlocks[41] = avatarId;
           } else if (data['name'] == '頭像7') {
             levelAvatarUnlocks[51] = avatarId;
           } else if (data['name'] == '頭像8') {
             levelAvatarUnlocks[61] = avatarId;
           }
           // 可以繼續添加更多頭像...
         }
        
        for (final doc in avatarSnapshot.docs) {
          final avatarId = doc.id;
          final data = doc.data();
          final isUnlocked = avatars[avatarId] ?? false;
          final requiredLevel = await _getAvatarUnlockLevel(avatarId);
          final canUnlock = currentLevel >= requiredLevel;
          
          allList.add({
            'id': avatarId,
            'name': data['name'] ?? '未命名頭像',
            '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
            'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
            'category': '頭像',
            'status': isUnlocked ? '已擁有' : (canUnlock ? '可解鎖' : '未解鎖'),
            'description': data['description'] ?? '',
            'unlockLevel': requiredLevel,
            'currentLevel': currentLevel,
            'canUnlock': canUnlock,
          });
        }
        
        // 排序：已擁有的在前，可解鎖的在中間，未解鎖的在後
        allList.sort((a, b) {
          final aOwned = a['status'] == '已擁有';
          final bOwned = b['status'] == '已擁有';
          final aCanUnlock = a['canUnlock'] ?? false;
          final bCanUnlock = b['canUnlock'] ?? false;

          if (aOwned && !bOwned) return -1;
          if (!aOwned && bOwned) return 1;
          if (aCanUnlock && !bCanUnlock) return -1;
          if (!aCanUnlock && bCanUnlock) return 1;
          return (a['unlockLevel'] as int).compareTo(b['unlockLevel'] as int);
        });
        
      } catch (e) {
        LoggerService.error('獲取頭像資料失敗: $e');
      }

      LoggerService.info('獲取所有頭像: ${allList.length} 個');
      return allList;
    } catch (e) {
      LoggerService.error('獲取所有頭像失敗: $e');
      return [];
    }
  }

  /// 獲取所有徽章（包含未獲得的）
  static Future<List<Map<String, dynamic>>> getAllMedals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final userDoc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final medals = Map<String, bool>.from(userData['medals'] ?? {});

      final allList = <Map<String, dynamic>>[];
      
      // 從 Firebase 獲取徽章資料
      try {
        final medalSnapshot = await FirebaseFirestore.instance
            .collection('徽章')
            .get();
        
        for (final doc in medalSnapshot.docs) {
          final medalId = doc.id;
          final data = doc.data();
          final isObtained = medals[medalId] ?? false;
          
          allList.add({
            'id': medalId,
            'name': data['name'] ?? '未命名徽章',
            '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
            'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
            'category': '徽章',
            'status': isObtained ? '已獲得' : '未獲得',
            'description': data['description'] ?? '',
            'taskDescription': data['taskDescription'] ?? '',
          });
        }
        
        // 排序：已獲得的在前
        allList.sort((a, b) {
          final aObtained = a['status'] == '已獲得';
          final bObtained = b['status'] == '已獲得';
          if (aObtained && !bObtained) return -1;
          if (!aObtained && bObtained) return 1;
          return 0;
        });
        
      } catch (e) {
        LoggerService.error('獲取徽章資料失敗: $e');
      }

      LoggerService.info('獲取所有徽章: ${allList.length} 個');
      return allList;
    } catch (e) {
      LoggerService.error('獲取所有徽章失敗: $e');
      return [];
    }
  }
}
