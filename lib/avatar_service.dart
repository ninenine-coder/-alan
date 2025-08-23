import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'experience_service.dart';
import 'logger_service.dart';

class AvatarService extends ChangeNotifier {
  // 等級解鎖頭像配置
  static const Map<int, String> _levelAvatarUnlocks = {
    1: 'avatar3',   // 等級1時獲得頭像3
    5: 'avatar2',   // 等級5時獲得頭像2
    11: 'avatar4',  // 等級11時獲得頭像4
    21: 'avatar5',  // 等級21時獲得頭像5
    31: 'avatar6',  // 等級31時獲得頭像6
  };
  
  // 單例模式
  static final AvatarService _instance = AvatarService._internal();
  factory AvatarService() => _instance;
  AvatarService._internal();

  // 頭像顯示名稱映射
  static const Map<String, String> _avatarDisplayNames = {
    'avatar2': '見習旅人',
    'avatar3': '見習旅人',
    'avatar4': '資深旅人',
    'avatar5': '專家旅人',
    'avatar6': '大師旅人',
  };

  // 頭像圖片URL映射
  static const Map<String, String> _avatarImageUrls = {
    'avatar2': 'https://i.postimg.cc/L5PW2Tby/image.jpg',
    'avatar3': 'https://i.postimg.cc/L5PW2Tby/image.jpg',
    'avatar4': 'https://i.postimg.cc/L5PW2Tby/image.jpg',
    'avatar5': 'https://i.postimg.cc/L5PW2Tby/image.jpg',
    'avatar6': 'https://i.postimg.cc/L5PW2Tby/image.jpg',
  };

  /// 首次登入時初始化用戶頭像資料
  Future<void> initializeUserAvatars() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;
      LoggerService.info('開始初始化用戶頭像資料: $uid');

      // 檢查是否已經初始化過
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        LoggerService.warning('用戶文檔不存在，跳過頭像初始化');
        return;
      }

      final userData = userDoc.data()!;
      
      // 檢查是否已有頭像資料
      if (userData.containsKey('avatars')) {
        LoggerService.info('用戶頭像資料已存在，跳過初始化');
        return;
      }

      // 獲取當前等級
      final experienceData = await ExperienceService.getCurrentExperience();
      final currentLevel = experienceData['level'] as int;

      // 初始化頭像資料
      final avatars = <String, bool>{};
      for (final entry in _levelAvatarUnlocks.entries) {
        final avatarId = entry.value;
        final requiredLevel = entry.key;
        avatars[avatarId] = currentLevel >= requiredLevel;
      }

      // 寫入用戶文檔
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'avatars': avatars});

      LoggerService.info('用戶頭像資料初始化完成: $avatars');
    } catch (e) {
      LoggerService.error('初始化用戶頭像資料失敗: $e');
    }
  }

  /// 檢查並解鎖基於等級的頭像
  Future<void> checkAndUnlockAvatarsByLevel() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;

      // 獲取當前等級
      final experienceData = await ExperienceService.getCurrentExperience();
      final currentLevel = experienceData['level'] as int;

      // 獲取當前頭像狀態
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        LoggerService.warning('用戶文檔不存在，無法檢查頭像解鎖');
        return;
      }

      final userData = userDoc.data()!;
      final currentAvatars = Map<String, bool>.from(userData['avatars'] ?? {});
      final updatedAvatars = Map<String, bool>.from(currentAvatars);
      bool hasChanges = false;

      // 檢查需要解鎖的頭像
      for (final entry in _levelAvatarUnlocks.entries) {
        final avatarId = entry.value;
        final requiredLevel = entry.key;
        
        if (currentLevel >= requiredLevel && !(currentAvatars[avatarId] ?? false)) {
          updatedAvatars[avatarId] = true;
          hasChanges = true;
          LoggerService.info('解鎖頭像: $avatarId (等級 $currentLevel >= $requiredLevel)');
        }
      }

      // 如果有變更，更新資料庫
      if (hasChanges) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'avatars': updatedAvatars});

        LoggerService.info('頭像解鎖更新完成: $updatedAvatars');
        
        // 通知UI更新
        notifyListeners();
        LoggerService.info('已通知UI更新頭像列表');
      }
    } catch (e) {
      LoggerService.error('檢查頭像解鎖失敗: $e');
    }
  }

  /// 獲取用戶已擁有的頭像
  Future<List<Map<String, dynamic>>> getOwnedAvatars() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final uid = user.uid;

      // 獲取用戶頭像狀態
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final avatars = Map<String, bool>.from(userData['avatars'] ?? {});

      // 篩選已擁有的頭像
      final ownedAvatars = <Map<String, dynamic>>[];
      for (final entry in avatars.entries) {
        if (entry.value) {
          ownedAvatars.add({
            'id': entry.key,
            'name': _avatarDisplayNames[entry.key] ?? entry.key,
            '圖片': _avatarImageUrls[entry.key] ?? '',
            'imageUrl': _avatarImageUrls[entry.key] ?? '',
            'category': '頭像',
            'status': '已擁有',
            'unlockLevel': _getUnlockLevel(entry.key),
          });
        }
      }

      LoggerService.info('獲取到 ${ownedAvatars.length} 個已擁有的頭像');
      return ownedAvatars;
    } catch (e) {
      LoggerService.error('獲取已擁有頭像失敗: $e');
      return [];
    }
  }

  /// 獲取所有頭像（包括未擁有的）
  Future<List<Map<String, dynamic>>> getAllAvatars() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final uid = user.uid;

      // 獲取用戶頭像狀態
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final avatars = Map<String, bool>.from(userData['avatars'] ?? {});

      // 獲取當前等級
      final experienceData = await ExperienceService.getCurrentExperience();
      final currentLevel = experienceData['level'] as int;

      // 構建所有頭像列表
      final allAvatars = <Map<String, dynamic>>[];
      for (final entry in _levelAvatarUnlocks.entries) {
        final avatarId = entry.value;
        final requiredLevel = entry.key;
        final isOwned = avatars[avatarId] ?? false;
        final canUnlock = currentLevel >= requiredLevel;

        allAvatars.add({
          'id': avatarId,
          'name': _avatarDisplayNames[avatarId] ?? avatarId,
          '圖片': _avatarImageUrls[avatarId] ?? '',
          'imageUrl': _avatarImageUrls[avatarId] ?? '',
          'category': '頭像',
          'status': isOwned ? '已擁有' : (canUnlock ? '可解鎖' : '未解鎖'),
          'unlockLevel': requiredLevel,
          'currentLevel': currentLevel,
          'canUnlock': canUnlock,
        });
      }

      // 排序：已擁有的在前，可解鎖的在中間，未解鎖的在後
      allAvatars.sort((a, b) {
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

      LoggerService.info('獲取到 ${allAvatars.length} 個頭像');
      return allAvatars;
    } catch (e) {
      LoggerService.error('獲取所有頭像失敗: $e');
      return [];
    }
  }

  /// 檢查特定頭像是否已解鎖
  Future<bool> isAvatarUnlocked(String avatarId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final uid = user.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
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

  /// 獲取頭像解鎖等級
  static int _getUnlockLevel(String avatarId) {
    for (final entry in _levelAvatarUnlocks.entries) {
      if (entry.value == avatarId) {
        return entry.key;
      }
    }
    return 0;
  }

  /// 獲取頭像解鎖等級信息
  static Map<String, int> getAvatarUnlockLevels() {
    return Map.from(_levelAvatarUnlocks);
  }

  /// 獲取用戶當前等級可以解鎖的頭像
  static List<String> getUnlockableAvatarsByLevel(int level) {
    final unlockableAvatars = <String>[];
    
    for (final entry in _levelAvatarUnlocks.entries) {
      if (level >= entry.key) {
        unlockableAvatars.add(entry.value);
      }
    }
    
    return unlockableAvatars;
  }

  /// 獲取下一個可解鎖的頭像信息
  static Map<String, dynamic>? getNextUnlockableAvatar(int level) {
    for (final entry in _levelAvatarUnlocks.entries) {
      if (level < entry.key) {
        return {
          'avatarId': entry.value,
          'avatarName': _avatarDisplayNames[entry.value] ?? entry.value,
          'requiredLevel': entry.key,
          'currentLevel': level,
          'levelsNeeded': entry.key - level,
        };
      }
    }
    
    return null; // 已解鎖所有頭像
  }

  /// 獲取頭像顯示名稱
  static String getAvatarDisplayName(String avatarId) {
    return _avatarDisplayNames[avatarId] ?? avatarId;
  }

  /// 獲取頭像圖片URL
  static String getAvatarImageUrl(String avatarId) {
    return _avatarImageUrls[avatarId] ?? '';
  }
}
