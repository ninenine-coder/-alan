import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';

class DataService {
  static const String _purchasedItemsKey = 'purchased_items';
  static const String _chatMessagesKey = 'chat_messages';
  static const String _aiNameKey = 'ai_name';
  static const String _experienceKey = 'user_experience';
  static const String _levelKey = 'user_level';
  static const String _unlockedFeaturesKey = 'unlocked_features';

  /// 同步所有用戶數據到 Firestore
  static Future<void> syncAllDataToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      LoggerService.info('開始同步所有數據到 Firestore');

      // 同步購買的商品
      await _syncPurchasedItems(user.uid);
      
      // 同步聊天紀錄
      await _syncChatMessages(user.uid);
      
      // 同步桌寵名稱
      await _syncAiName(user.uid);
      
      // 同步經驗值和等級
      await _syncExperienceAndLevel(user.uid);
      
      // 同步解鎖功能
      await _syncUnlockedFeatures(user.uid);

      LoggerService.info('所有數據同步完成');
    } catch (e) {
      LoggerService.error('同步數據時發生錯誤: $e');
    }
  }

  /// 從 Firestore 載入所有數據到本地
  static Future<void> loadAllDataFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      LoggerService.info('開始從 Firestore 載入所有數據');

      // 載入購買的商品
      await _loadPurchasedItems(user.uid);
      
      // 載入聊天紀錄
      await _loadChatMessages(user.uid);
      
      // 載入桌寵名稱
      await _loadAiName(user.uid);
      
      // 載入經驗值和等級
      await _loadExperienceAndLevel(user.uid);
      
      // 載入解鎖功能
      await _loadUnlockedFeatures(user.uid);

      LoggerService.info('所有數據載入完成');
    } catch (e) {
      LoggerService.error('載入數據時發生錯誤: $e');
    }
  }

  /// 同步購買的商品
  static Future<void> _syncPurchasedItems(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final purchasedItemsJson = prefs.getString('${_purchasedItemsKey}_$userId');
      
      if (purchasedItemsJson != null) {
        final purchasedItems = List<String>.from(
          (purchasedItemsJson as List<dynamic>).map((item) => item.toString())
        );
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'purchasedItems': purchasedItems});
      }
    } catch (e) {
      LoggerService.error('同步購買商品時發生錯誤: $e');
    }
  }

  /// 載入購買的商品
  static Future<void> _loadPurchasedItems(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final purchasedItems = List<String>.from(userData['purchasedItems'] ?? []);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${_purchasedItemsKey}_$userId', purchasedItems.toString());
      }
    } catch (e) {
      LoggerService.error('載入購買商品時發生錯誤: $e');
    }
  }

  /// 同步聊天紀錄
  static Future<void> _syncChatMessages(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatMessagesJson = prefs.getString('${_chatMessagesKey}_$userId');
      
      if (chatMessagesJson != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'chatMessages': chatMessagesJson});
      }
    } catch (e) {
      LoggerService.error('同步聊天紀錄時發生錯誤: $e');
    }
  }

  /// 載入聊天紀錄
  static Future<void> _loadChatMessages(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final chatMessages = userData['chatMessages'] as String?;
        
        if (chatMessages != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('${_chatMessagesKey}_$userId', chatMessages);
        }
      }
    } catch (e) {
      LoggerService.error('載入聊天紀錄時發生錯誤: $e');
    }
  }

  /// 同步桌寵名稱
  static Future<void> _syncAiName(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final aiName = prefs.getString('${_aiNameKey}_$userId');
      
      if (aiName != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'aiName': aiName});
      }
    } catch (e) {
      LoggerService.error('同步桌寵名稱時發生錯誤: $e');
    }
  }

  /// 載入桌寵名稱
  static Future<void> _loadAiName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final aiName = userData['aiName'] as String?;
        
        if (aiName != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('${_aiNameKey}_$userId', aiName);
        }
      }
    } catch (e) {
      LoggerService.error('載入桌寵名稱時發生錯誤: $e');
    }
  }

  /// 同步經驗值和等級
  static Future<void> _syncExperienceAndLevel(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final experience = prefs.getInt('${_experienceKey}_$userId') ?? 0;
      final level = prefs.getInt('${_levelKey}_$userId') ?? 1;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'experience': experience,
        'level': level,
      });
    } catch (e) {
      LoggerService.error('同步經驗值和等級時發生錯誤: $e');
    }
  }

  /// 載入經驗值和等級
  static Future<void> _loadExperienceAndLevel(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final experience = userData['experience'] as int? ?? 0;
        final level = userData['level'] as int? ?? 1;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('${_experienceKey}_$userId', experience);
        await prefs.setInt('${_levelKey}_$userId', level);
      }
    } catch (e) {
      LoggerService.error('載入經驗值和等級時發生錯誤: $e');
    }
  }

  /// 同步解鎖功能
  static Future<void> _syncUnlockedFeatures(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedFeatures = prefs.getStringList('${_unlockedFeaturesKey}_$userId') ?? [];
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'unlockedFeatures': unlockedFeatures});
    } catch (e) {
      LoggerService.error('同步解鎖功能時發生錯誤: $e');
    }
  }

  /// 載入解鎖功能
  static Future<void> _loadUnlockedFeatures(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final unlockedFeatures = List<String>.from(userData['unlockedFeatures'] ?? []);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('${_unlockedFeaturesKey}_$userId', unlockedFeatures);
      }
    } catch (e) {
      LoggerService.error('載入解鎖功能時發生錯誤: $e');
    }
  }

  /// 獲取購買的商品（按分類）
  static Future<Map<String, List<StoreItem>>> getPurchasedItemsByCategory(String username) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      if (userDoc.docs.isNotEmpty) {
        // 這裡可以根據實際的商品數據結構來組織
        // 目前返回空的分類映射
        return {};
      }
      return {};
    } catch (e) {
      LoggerService.error('獲取購買商品時發生錯誤: $e');
      return {};
    }
  }

  /// 獲取勳章列表
  static Future<List<Medal>> getMedals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medalsJson = prefs.getStringList('medals') ?? [];
      
      return medalsJson
          .map((json) => Medal.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      LoggerService.error('獲取勳章時發生錯誤: $e');
      return [];
    }
  }

  /// 保存用戶數據
  static Future<void> saveUserData(String username, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList('registered_users') ?? [];
      
      // 檢查是否已存在該用戶
      final existingIndex = usersJson.indexWhere((json) {
        final user = Map<String, dynamic>.from(json as Map);
        return user['username'] == username;
      });
      
      final userJson = userData.toString();
      
      if (existingIndex != -1) {
        // 更新現有用戶
        usersJson[existingIndex] = userJson;
      } else {
        // 新增用戶
        usersJson.add(userJson);
      }
      
      await prefs.setStringList('registered_users', usersJson);
    } catch (e) {
      LoggerService.error('保存用戶數據時發生錯誤: $e');
    }
  }

  /// 備份用戶數據
  static Future<Map<String, dynamic>> backupUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final prefs = await SharedPreferences.getInstance();
      final backup = {
        'userId': user.uid,
        'timestamp': DateTime.now().toIso8601String(),
        'purchasedItems': prefs.getString('${_purchasedItemsKey}_${user.uid}'),
        'chatMessages': prefs.getString('${_chatMessagesKey}_${user.uid}'),
        'aiName': prefs.getString('${_aiNameKey}_${user.uid}'),
        'experience': prefs.getInt('${_experienceKey}_${user.uid}'),
        'level': prefs.getInt('${_levelKey}_${user.uid}'),
        'unlockedFeatures': prefs.getStringList('${_unlockedFeaturesKey}_${user.uid}'),
      };

      return backup;
    } catch (e) {
      LoggerService.error('備份用戶數據時發生錯誤: $e');
      return {};
    }
  }

  /// 恢復用戶數據
  static Future<bool> restoreUserData(Map<String, dynamic> backup) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final prefs = await SharedPreferences.getInstance();
      
      if (backup['purchasedItems'] != null) {
        await prefs.setString('${_purchasedItemsKey}_${user.uid}', backup['purchasedItems']);
      }
      
      if (backup['chatMessages'] != null) {
        await prefs.setString('${_chatMessagesKey}_${user.uid}', backup['chatMessages']);
      }
      
      if (backup['aiName'] != null) {
        await prefs.setString('${_aiNameKey}_${user.uid}', backup['aiName']);
      }
      
      if (backup['experience'] != null) {
        await prefs.setInt('${_experienceKey}_${user.uid}', backup['experience']);
      }
      
      if (backup['level'] != null) {
        await prefs.setInt('${_levelKey}_${user.uid}', backup['level']);
      }
      
      if (backup['unlockedFeatures'] != null) {
        await prefs.setStringList('${_unlockedFeaturesKey}_${user.uid}', backup['unlockedFeatures']);
      }

      return true;
    } catch (e) {
      LoggerService.error('恢復用戶數據時發生錯誤: $e');
      return false;
    }
  }
}

/// 商品項目類
class StoreItem {
  final String id;
  final String name;
  final String category;
  final int price;
  final String description;
  final String? imageUrl;
  final String? imagePath;
  final String rarity;
  final String iconName;

  StoreItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    this.imageUrl,
    this.imagePath,
    this.rarity = '常見',
    this.iconName = '',
  });

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      price: json['price'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      imagePath: json['imagePath'],
      rarity: json['rarity'] ?? '常見',
      iconName: json['iconName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'description': description,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'rarity': rarity,
      'iconName': iconName,
    };
  }
}

/// 勳章類
class Medal {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final String rarity;
  final int requirement;
  final String? imagePath;
  bool acquired;

  Medal({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.rarity,
    required this.requirement,
    this.imagePath,
    this.acquired = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconName': iconName,
      'rarity': rarity,
      'requirement': requirement,
      'imagePath': imagePath,
      'acquired': acquired,
    };
  }

  factory Medal.fromJson(Map<String, dynamic> json) {
    return Medal(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconName: json['iconName'],
      rarity: json['rarity'],
      requirement: json['requirement'],
      imagePath: json['imagePath'],
      acquired: json['acquired'] ?? false,
    );
  }
} 