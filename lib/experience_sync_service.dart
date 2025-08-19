import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'experience_service.dart';
import 'logger_service.dart';
import 'offline_experience_dialog.dart';

class ExperienceSyncService {
  static const String _lastSyncKey = 'last_experience_sync';
  static const String _offlineExperienceKey = 'offline_experience';
  
  /// 初始化經驗值同步（在用戶登入時調用）
  static Future<void> initializeExperienceSync({BuildContext? context}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 獲取上次離線時的經驗值
      final lastOfflineExp = await getLastOfflineExperience();
      
      if (lastOfflineExp != null) {
        // 同步到當前會話
        await _syncOfflineExperience(lastOfflineExp);
        
        // 顯示離線經驗值信息（在同步後）
        if (context != null) {
          // 在異步操作前檢查 context 是否仍然有效
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              _showOfflineExperienceInfo(lastOfflineExp, context);
            }
          });
        }
      }
      
      // 記錄同步時間
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_lastSyncKey}_${user.uid}', DateTime.now().toIso8601String());
      
      LoggerService.info('Experience sync initialized for user: ${user.uid}');
    } catch (e) {
      LoggerService.error('Error initializing experience sync: $e');
    }
  }

  /// 獲取上次離線時的經驗值
  static Future<Map<String, dynamic>?> getLastOfflineExperience() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final lastExp = userData['experience'] ?? 0;
        final lastLevel = userData['level'] ?? 1;
        final lastUpdate = userData['lastExperienceUpdate'];
        
        return {
          'experience': lastExp,
          'level': lastLevel,
          'lastUpdate': lastUpdate,
          'progress': ExperienceService.getLevelInfo(lastLevel)['progress'] ?? 0.0,
        };
      }
      
      return null;
    } catch (e) {
      LoggerService.error('Error getting last offline experience: $e');
      return null;
    }
  }

  /// 顯示離線經驗值信息
  static Future<void> _showOfflineExperienceInfo(Map<String, dynamic> offlineExp, BuildContext? context) async {
    try {
      final lastUpdate = offlineExp['lastUpdate'] as Timestamp?;
      final experience = offlineExp['experience'] as int;
      final level = offlineExp['level'] as int;
      
      String timeInfo = '未知時間';
      if (lastUpdate != null) {
        final lastUpdateTime = lastUpdate.toDate();
        final now = DateTime.now();
        final difference = now.difference(lastUpdateTime);
        
        if (difference.inDays > 0) {
          timeInfo = '${difference.inDays}天前';
        } else if (difference.inHours > 0) {
          timeInfo = '${difference.inHours}小時前';
        } else if (difference.inMinutes > 0) {
          timeInfo = '${difference.inMinutes}分鐘前';
        } else {
          timeInfo = '剛剛';
        }
      }
      
      LoggerService.info('上次離線經驗值: $experience exp, 等級: $level, 更新時間: $timeInfo');
      
      // 如果有 context，顯示對話框
      if (context != null) {
        await OfflineExperienceDialog.showOfflineExperienceDialog(context, offlineExp);
      }
    } catch (e) {
      LoggerService.error('Error showing offline experience info: $e');
    }
  }

  /// 同步離線經驗值到當前會話
  static Future<void> _syncOfflineExperience(Map<String, dynamic> offlineExp) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final currentExp = prefs.getInt('user_experience_${user.uid}') ?? 0;
      final offlineExperience = offlineExp['experience'] as int;
      
      // 如果離線經驗值更高，使用離線經驗值
      if (offlineExperience > currentExp) {
        await ExperienceService.setExperience(offlineExperience);
        LoggerService.info('Synced offline experience: $offlineExperience');
      }
    } catch (e) {
      LoggerService.error('Error syncing offline experience: $e');
    }
  }

  /// 保存當前經驗值作為離線數據
  static Future<void> saveOfflineExperience() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final currentExp = await ExperienceService.getCurrentExperience();
      final experience = currentExp['experience'] as int;
      final level = currentExp['level'] as int;
      
      // 保存到本地作為離線數據
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_offlineExperienceKey}_${user.uid}', experience);
      await prefs.setInt('${_offlineExperienceKey}_level_${user.uid}', level);
      await prefs.setString('${_offlineExperienceKey}_time_${user.uid}', DateTime.now().toIso8601String());
      
      LoggerService.info('Offline experience saved: $experience exp, level: $level');
    } catch (e) {
      LoggerService.error('Error saving offline experience: $e');
    }
  }

  /// 獲取本地保存的離線經驗值
  static Future<Map<String, dynamic>?> getLocalOfflineExperience() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final experience = prefs.getInt('${_offlineExperienceKey}_${user.uid}');
      final level = prefs.getInt('${_offlineExperienceKey}_level_${user.uid}');
      final timeString = prefs.getString('${_offlineExperienceKey}_time_${user.uid}');
      
      if (experience != null && level != null && timeString != null) {
        final time = DateTime.parse(timeString);
        return {
          'experience': experience,
          'level': level,
          'lastUpdate': time,
          'progress': ExperienceService.getLevelInfo(level)['progress'] ?? 0.0,
        };
      }
      
      return null;
    } catch (e) {
      LoggerService.error('Error getting local offline experience: $e');
      return null;
    }
  }

  /// 檢查是否有新的經驗值更新
  static Future<bool> hasNewExperienceUpdate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final lastLocalUpdate = prefs.getString('${_lastSyncKey}_${user.uid}');
      
      if (lastLocalUpdate == null) return true; // 首次同步
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final lastFirebaseUpdate = userData['lastExperienceUpdate'];
        
        if (lastFirebaseUpdate != null) {
          final localTime = DateTime.parse(lastLocalUpdate);
          final firebaseTime = (lastFirebaseUpdate as Timestamp).toDate();
          
          return firebaseTime.isAfter(localTime);
        }
      }
      
      return false;
    } catch (e) {
      LoggerService.error('Error checking for new experience updates: $e');
      return false;
    }
  }

  /// 強制同步經驗值到 Firebase
  static Future<bool> forceSyncExperience() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final currentExp = await ExperienceService.getCurrentExperience();
      final experience = currentExp['experience'] as int;
      final level = currentExp['level'] as int;
      
      // 直接更新到 Firebase
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'experience': experience,
        'level': level,
        'lastExperienceUpdate': FieldValue.serverTimestamp(),
      });
      
      // 更新同步時間
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_lastSyncKey}_${user.uid}', DateTime.now().toIso8601String());
      
      LoggerService.info('Experience force synced: $experience exp, level: $level');
      return true;
    } catch (e) {
      LoggerService.error('Error force syncing experience: $e');
      return false;
    }
  }

  /// 獲取經驗值同步狀態
  static Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'synced': false, 'lastSync': null, 'hasUpdates': false};

      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString('${_lastSyncKey}_${user.uid}');
      final hasUpdates = await hasNewExperienceUpdate();
      
      DateTime? lastSync;
      if (lastSyncString != null) {
        lastSync = DateTime.parse(lastSyncString);
      }
      
      return {
        'synced': lastSync != null,
        'lastSync': lastSync,
        'hasUpdates': hasUpdates,
      };
    } catch (e) {
      LoggerService.error('Error getting sync status: $e');
      return {'synced': false, 'lastSync': null, 'hasUpdates': false};
    }
  }

  /// 清理離線經驗值數據
  static Future<void> clearOfflineExperience() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_offlineExperienceKey}_${user.uid}');
      await prefs.remove('${_offlineExperienceKey}_level_${user.uid}');
      await prefs.remove('${_offlineExperienceKey}_time_${user.uid}');
      
      LoggerService.info('Offline experience data cleared');
    } catch (e) {
      LoggerService.error('Error clearing offline experience: $e');
    }
  }
}
