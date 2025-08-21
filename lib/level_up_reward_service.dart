import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'coin_service.dart';
import 'logger_service.dart';
import 'level_up_animation.dart';

class LevelUpRewardService {
  static const int _levelUpCoinReward = 10; // 每次升級獲得10金幣
  
  // 升級動畫管理器
  static final LevelUpAnimationManager _animationManager = LevelUpAnimationManager.instance;
  
  /// 處理升級事件
  static Future<void> handleLevelUp(int newLevel, BuildContext context) async {
    try {
      LoggerService.info('處理升級事件: 等級 $newLevel');
      
      // 1. 顯示升級動畫
      _showLevelUpAnimation(context, newLevel);
      
      // 2. 給予升級獎勵
      await _giveLevelUpReward(newLevel);
      
      // 3. 記錄升級事件
      await _recordLevelUpEvent(newLevel);
      
      LoggerService.info('升級事件處理完成: 等級 $newLevel');
      
    } catch (e) {
      LoggerService.error('處理升級事件時發生錯誤: $e');
    }
  }
  
  /// 顯示升級動畫
  static void _showLevelUpAnimation(BuildContext context, int newLevel) {
    try {
      _animationManager.showLevelUpAnimation(context, newLevel);
      LoggerService.info('升級動畫已顯示: 等級 $newLevel');
    } catch (e) {
      LoggerService.error('顯示升級動畫時發生錯誤: $e');
    }
  }
  
  /// 給予升級獎勵
  static Future<void> _giveLevelUpReward(int newLevel) async {
    try {
      // 添加金幣獎勵
      final newCoins = await CoinService.addCoins(_levelUpCoinReward);
      
      LoggerService.info('升級獎勵已發放: +$_levelUpCoinReward 金幣，總金幣: $newCoins');
      
    } catch (e) {
      LoggerService.error('發放升級獎勵時發生錯誤: $e');
    }
  }
  
  /// 記錄升級事件
  static Future<void> _recordLevelUpEvent(int newLevel) async {
    try {
      final userData = await UserService.getCurrentUserData();
      if (userData == null) return;

      final uid = userData['uid'] ?? 'default';
      
      // 更新 Firebase 用戶文檔
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'lastLevelUp': FieldValue.serverTimestamp(),
        'lastLevelUpLevel': newLevel,
        'totalLevelUps': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('升級事件已記錄: 等級 $newLevel');
      
    } catch (e) {
      LoggerService.error('記錄升級事件時發生錯誤: $e');
    }
  }
  
  /// 獲取升級金幣獎勵數量
  static int getLevelUpCoinReward() {
    return _levelUpCoinReward;
  }
  
  /// 隱藏升級動畫
  static void hideLevelUpAnimation() {
    try {
      _animationManager.hideLevelUpAnimation();
      LoggerService.debug('升級動畫已隱藏');
    } catch (e) {
      LoggerService.error('隱藏升級動畫時發生錯誤: $e');
    }
  }
}
