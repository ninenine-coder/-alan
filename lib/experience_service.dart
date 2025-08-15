import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';

// 升級回調函數類型
typedef LevelUpCallback = void Function(int newLevel);

class ExperienceService {
  static const String _experienceKey = 'user_experience';
  static const String _levelKey = 'user_level';
  static const String _loginTimeKey = 'user_login_time';
  
  // 升級回調列表
  static final List<LevelUpCallback> _levelUpCallbacks = [];
  
  // 等級經驗值需求配置（未來可能使用）
  // static const Map<String, int> _levelRequirements = {
  //   '1-5': 100,    // 1-5等，每級需要100經驗
  //   '6-10': 200,   // 6-10等，每級需要200經驗
  //   '11-20': 300,  // 11-20等，每級需要300經驗
  //   '21+': 500,    // 21等以上，每級需要500經驗
  // };

  // 等級解鎖功能配置
  static const Map<String, List<String>> _levelUnlocks = {
    '1': ['login_reward', 'store'],                    // 登入獎勵、商城
    '6': ['personalization', 'pet_interaction'],       // 個人化裝扮、桌寵互動
    '11': ['challenge_tasks'],                         // 挑戰任務
    '21': ['weekly_tasks', 'rare_items'],              // 每週任務、稀有商品
  };

  /// 註冊升級回調
  static void addLevelUpCallback(LevelUpCallback callback) {
    _levelUpCallbacks.add(callback);
  }

  /// 移除升級回調
  static void removeLevelUpCallback(LevelUpCallback callback) {
    _levelUpCallbacks.remove(callback);
  }

  /// 記錄用戶登入時間
  static Future<void> recordLoginTime() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        LoggerService.warning('No authenticated user found for login time recording');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final loginTime = DateTime.now();
      
      // 儲存登入時間到本地
      await prefs.setString('${_loginTimeKey}_${user.uid}', loginTime.toIso8601String());
      
      // 同步到 Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'lastLoginTime': loginTime,
        'lastLoginDate': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('Login time recorded: ${loginTime.toIso8601String()}');
    } catch (e) {
      LoggerService.error('Error recording login time: $e');
    }
  }

  /// 計算並添加基於登入時間的經驗值
  static Future<void> calculateAndAddLoginExperience() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        LoggerService.warning('No authenticated user found for experience calculation');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final loginTimeString = prefs.getString('${_loginTimeKey}_${user.uid}');
      
      if (loginTimeString == null) {
        LoggerService.warning('No login time found for experience calculation');
        return;
      }

      final loginTime = DateTime.parse(loginTimeString);
      final logoutTime = DateTime.now();
      
      // 計算登入時長（以分鐘為單位）
      final duration = logoutTime.difference(loginTime).inMinutes;
      
      // 經驗值 = 登入時長 * 10
      final experienceGained = duration * 10;
      
      if (experienceGained > 0) {
        await addExperience(experienceGained);
        LoggerService.info('Login experience calculated: $duration minutes = $experienceGained exp');
      }
      
      // 清除登入時間記錄
      await prefs.remove('${_loginTimeKey}_${user.uid}');
      
    } catch (e) {
      LoggerService.error('Error calculating login experience: $e');
    }
  }

  /// 獲取用戶當前經驗值和等級
  static Future<Map<String, dynamic>> getCurrentExperience() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        LoggerService.warning('No authenticated user found');
        return {'experience': 0, 'level': 1, 'progress': 0.0};
      }

      final prefs = await SharedPreferences.getInstance();
      
      // 檢查是否為首次登入
      final isFirstTime = prefs.getBool('first_time_${user.uid}') ?? true;
      
      if (isFirstTime) {
        // 首次登入，設置初始值
        await prefs.setInt('${_experienceKey}_${user.uid}', 0);
        await prefs.setInt('${_levelKey}_${user.uid}', 1);
        await prefs.setBool('first_time_${user.uid}', false);
        
        // 同步到 Firestore
        await _syncToFirestore(user.uid, 0, 1);
        
        LoggerService.info('First time user, initialized experience to 0');
        return {'experience': 0, 'level': 1, 'progress': 0.0};
      }
      
      // 非首次登入，從本地和 Firestore 獲取數據
      final localExp = prefs.getInt('${_experienceKey}_${user.uid}') ?? 0;
      final localLevel = prefs.getInt('${_levelKey}_${user.uid}') ?? 1;
      
      // 嘗試從 Firestore 獲取最新數據
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final firestoreExp = userData['experience'] ?? 0;
          
          // 使用較新的數據
          final finalExp = firestoreExp > localExp ? firestoreExp : localExp;
          final finalLevel = _calculateLevel(finalExp);
          
          // 更新本地數據
          await prefs.setInt('${_experienceKey}_${user.uid}', finalExp);
          await prefs.setInt('${_levelKey}_${user.uid}', finalLevel);
          
          final progress = _calculateProgress(finalExp, finalLevel);
          
          LoggerService.debug('Experience loaded: $finalExp, level: $finalLevel, progress: $progress');
          
          return {
            'experience': finalExp,
            'level': finalLevel,
            'progress': progress,
          };
        }
      } catch (e) {
        LoggerService.warning('Failed to load from Firestore, using local data: $e');
      }
      
      // 如果 Firestore 失敗，使用本地數據
      final progress = _calculateProgress(localExp, localLevel);
      
      LoggerService.debug('Using local experience data: $localExp, level: $localLevel, progress: $progress');
      
      return {
        'experience': localExp,
        'level': localLevel,
        'progress': progress,
      };
    } catch (e) {
      LoggerService.error('Error getting current experience: $e');
      return {'experience': 0, 'level': 1, 'progress': 0.0};
    }
  }

  /// 增加經驗值
  static Future<void> addExperience(int amount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        LoggerService.warning('No authenticated user found for experience update');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final currentExp = prefs.getInt('${_experienceKey}_${user.uid}') ?? 0;
      final currentLevel = prefs.getInt('${_levelKey}_${user.uid}') ?? 1;
      
      final newExp = currentExp + amount;
      final newLevel = _calculateLevel(newExp);
      
      // 保存新的經驗值和等級
      await prefs.setInt('${_experienceKey}_${user.uid}', newExp);
      await prefs.setInt('${_levelKey}_${user.uid}', newLevel);
      
      // 同步到 Firestore
      await _syncToFirestore(user.uid, newExp, newLevel);
      
      LoggerService.info('Experience updated: +$amount exp, total: $newExp, level: $newLevel');
      
      // 檢查是否升級
      if (newLevel > currentLevel) {
        LoggerService.info('Level up! New level: $newLevel');
        await _handleLevelUp(newLevel);
        
        // 觸發所有升級回調
        for (final callback in _levelUpCallbacks) {
          try {
            callback(newLevel);
          } catch (e) {
            LoggerService.error('Error in level up callback: $e');
          }
        }
      }
    } catch (e) {
      LoggerService.error('Error adding experience: $e');
    }
  }

  /// 計算等級
  static int _calculateLevel(int experience) {
    int level = 1;
    int remainingExp = experience;
    
    // 1-5等：每級100經驗
    for (int i = 1; i <= 5; i++) {
      if (remainingExp >= 100) {
        level = i + 1;
        remainingExp -= 100;
      } else {
        return level;
      }
    }
    
    // 6-10等：每級200經驗
    for (int i = 6; i <= 10; i++) {
      if (remainingExp >= 200) {
        level = i + 1;
        remainingExp -= 200;
      } else {
        return level;
      }
    }
    
    // 11-20等：每級300經驗
    for (int i = 11; i <= 20; i++) {
      if (remainingExp >= 300) {
        level = i + 1;
        remainingExp -= 300;
      } else {
        return level;
      }
    }
    
    // 21等以上：每級500經驗
    while (remainingExp >= 500) {
      level++;
      remainingExp -= 500;
    }
    
    return level;
  }

  /// 計算當前等級的進度百分比
  static double _calculateProgress(int experience, int level) {
    int expForNextLevel = _getExperienceForLevel(level + 1);
    int currentLevelExp = _getTotalExperienceForLevel(level);
    
    int expInCurrentLevel = experience - currentLevelExp;
    int expNeededForNextLevel = expForNextLevel;
    
    if (expNeededForNextLevel == 0) return 1.0; // 已達最高等級
    
    return expInCurrentLevel / expNeededForNextLevel;
  }

  /// 獲取指定等級所需的經驗值
  static int _getExperienceForLevel(int level) {
    if (level <= 5) return 100;
    if (level <= 10) return 200;
    if (level <= 20) return 300;
    return 500; // 21等以上
  }

  /// 獲取達到指定等級所需的總經驗值
  static int _getTotalExperienceForLevel(int level) {
    int totalExp = 0;
    
    // 1-5等：每級100經驗
    for (int i = 1; i < level && i <= 5; i++) {
      totalExp += 100;
    }
    
    // 6-10等：每級200經驗
    for (int i = 6; i < level && i <= 10; i++) {
      totalExp += 200;
    }
    
    // 11-20等：每級300經驗
    for (int i = 11; i < level && i <= 20; i++) {
      totalExp += 300;
    }
    
    // 21等以上：每級500經驗
    for (int i = 21; i < level; i++) {
      totalExp += 500;
    }
    
    return totalExp;
  }

  /// 同步經驗值到 Firestore
  static Future<void> _syncToFirestore(String userId, int experience, int level) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'experience': experience,
        'level': level,
        'lastExperienceUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggerService.error('Error syncing experience to Firestore: $e');
    }
  }

  /// 處理升級事件
  static Future<void> _handleLevelUp(int newLevel) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 檢查解鎖的功能
      final unlockedFeatures = _getUnlockedFeatures(newLevel);
      
      // 保存解鎖的功能到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('unlocked_features_${user.uid}', unlockedFeatures);
      
      // 同步到 Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'unlockedFeatures': unlockedFeatures,
        'lastLevelUp': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('Level up to $newLevel, unlocked features: $unlockedFeatures');
    } catch (e) {
      LoggerService.error('Error handling level up: $e');
    }
  }

  /// 獲取指定等級解鎖的功能
  static List<String> _getUnlockedFeatures(int level) {
    List<String> features = [];
    
    for (String levelStr in _levelUnlocks.keys) {
      int unlockLevel = int.parse(levelStr);
      if (level >= unlockLevel) {
        features.addAll(_levelUnlocks[levelStr]!);
      }
    }
    
    return features;
  }

  /// 檢查功能是否已解鎖
  static Future<bool> isFeatureUnlocked(String feature) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final unlockedFeatures = prefs.getStringList('unlocked_features_${user.uid}') ?? [];
      
      return unlockedFeatures.contains(feature);
    } catch (e) {
      LoggerService.error('Error checking feature unlock: $e');
      return false;
    }
  }

  /// 獲取所有已解鎖的功能
  static Future<List<String>> getUnlockedFeatures() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('unlocked_features_${user.uid}') ?? [];
    } catch (e) {
      LoggerService.error('Error getting unlocked features: $e');
      return [];
    }
  }

  /// 重置經驗值（用於測試或重置）
  static Future<void> resetExperience() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_experienceKey}_${user.uid}', 0);
      await prefs.setInt('${_levelKey}_${user.uid}', 1);
      await prefs.setStringList('unlocked_features_${user.uid}', []);
      
      await _syncToFirestore(user.uid, 0, 1);
      
      LoggerService.info('Experience reset for user: ${user.uid}');
    } catch (e) {
      LoggerService.error('Error resetting experience: $e');
    }
  }

  /// 獲取等級信息（用於顯示）
  static Map<String, dynamic> getLevelInfo(int level) {
    final expNeeded = _getExperienceForLevel(level);
    final totalExpForLevel = _getTotalExperienceForLevel(level);
    
    return {
      'level': level,
      'expNeeded': expNeeded,
      'totalExpForLevel': totalExpForLevel,
      'unlockedFeatures': _getUnlockedFeatures(level),
    };
  }

  /// 獲取當前登入時長（用於顯示）
  static Future<Duration?> getCurrentLoginDuration() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final loginTimeString = prefs.getString('${_loginTimeKey}_${user.uid}');
      
      if (loginTimeString == null) return null;

      final loginTime = DateTime.parse(loginTimeString);
      return DateTime.now().difference(loginTime);
    } catch (e) {
      LoggerService.error('Error getting current login duration: $e');
      return null;
    }
  }

  /// 獲取預估經驗值（基於當前登入時長）
  static Future<int> getEstimatedExperience() async {
    try {
      final duration = await getCurrentLoginDuration();
      if (duration == null) return 0;
      
      return duration.inMinutes * 10;
    } catch (e) {
      LoggerService.error('Error getting estimated experience: $e');
      return 0;
    }
  }
}
