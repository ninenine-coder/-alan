import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';
import 'coin_service.dart';
import 'feature_unlock_service.dart';

class ChallengeService {
  static const String _dailyTasksKey = 'daily_challenge_tasks';
  static const String _weeklyTasksKey = 'weekly_challenge_tasks';
  static const String _lastResetDateKey = 'last_challenge_reset_date';
  static const String _lastWeeklyResetDateKey = 'last_weekly_reset_date';
  static const String _dailyMessageCountKey = 'daily_message_count';
  static const String _lastMessageDateKey = 'last_message_date';
  
  // 挑戰任務類型
  static const String taskMetroCheckin = 'metro_checkin';
  static const String taskPetInteraction = 'pet_interaction';
  static const String taskRouteExploration = 'route_exploration';
  static const String taskDailyMessage = 'daily_message';
  
  // 每周任務類型
  static const String taskBuyMetroItem = 'buy_metro_item';
  static const String taskReach5km = 'reach_5km';

  // 每日任務配置
  static final Map<String, DailyTask> dailyTaskConfigs = {
    taskMetroCheckin: DailyTask(
      id: taskMetroCheckin,
      title: '在任意捷運站打卡',
      description: '上傳照片到聊天頁面，當圖片中出現台北捷運標示時自動完成',
      reward: 5,
      maxDailyClaims: 1,
    ),
    taskPetInteraction: DailyTask(
      id: taskPetInteraction,
      title: '與桌寵完成互動',
      description: '前往桌寵頁面，點擊桌寵模型完成互動',
      reward: 5,
      maxDailyClaims: 1,
    ),
    taskRouteExploration: DailyTask(
      id: taskRouteExploration,
      title: '路線探索',
      description: '完成路線探索任務（功能開發中）',
      reward: 5,
      maxDailyClaims: 1,
    ),
    taskDailyMessage: DailyTask(
      id: taskDailyMessage,
      title: '每日聊天',
      description: '在聊天頁面發送訊息，每日上限15次',
      reward: 1,
      maxDailyClaims: 15,
    ),
  };

  // 每周任務配置
  static final Map<String, WeeklyTask> weeklyTaskConfigs = {
    taskBuyMetroItem: WeeklyTask(
      id: taskBuyMetroItem,
      title: '購買捷運商品',
      description: '在商城購買任意捷運商品',
      reward: 15,
      maxWeeklyClaims: 1,
    ),
    taskReach5km: WeeklyTask(
      id: taskReach5km,
      title: '里程數達 5 公里',
      description: '累積里程數達 5 公里',
      reward: 15,
      maxWeeklyClaims: 1,
    ),
  };

  // 檢查並重置每日任務
  static Future<void> checkAndResetDailyTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetDate = prefs.getString(_lastResetDateKey);
    final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

    if (lastResetDate != today) {
      // 重置每日任務
      await _resetDailyTasks();
      await prefs.setString(_lastResetDateKey, today);
      
      // 重置每日訊息計數
      await prefs.setInt(_dailyMessageCountKey, 0);
      await prefs.setString(_lastMessageDateKey, today);
    }
  }

  // 檢查並重置每周任務
  static Future<void> checkAndResetWeeklyTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetDate = prefs.getString(_lastWeeklyResetDateKey);
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final thisWeek = startOfWeek.toIso8601String().split('T')[0]; // YYYY-MM-DD

    if (lastResetDate != thisWeek) {
      // 重置每周任務
      await _resetWeeklyTasks();
      await prefs.setString(_lastWeeklyResetDateKey, thisWeek);
    }
  }

  // 重置每日任務
  static Future<void> _resetDailyTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return;

    final username = userData['username'] ?? 'default';
    final tasksKey = '${_dailyTasksKey}_$username';
    final resetTasks = <String, dynamic>{};
    
    for (final task in dailyTaskConfigs.values) {
      resetTasks[task.id] = {
        'claimedCount': 0,
        'completed': false,
        'lastClaimDate': null,
      };
    }
    
    await prefs.setString(tasksKey, jsonEncode(resetTasks));
  }

  // 重置每周任務
  static Future<void> _resetWeeklyTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return;

    final username = userData['username'] ?? 'default';
    final tasksKey = '${_weeklyTasksKey}_$username';
    final resetTasks = <String, dynamic>{};
    
    for (final task in weeklyTaskConfigs.values) {
      resetTasks[task.id] = {
        'claimedCount': 0,
        'completed': false,
        'lastClaimDate': null,
      };
    }
    
    await prefs.setString(tasksKey, jsonEncode(resetTasks));
  }

  // 獲取用戶的每日任務狀態
  static Future<Map<String, DailyTaskStatus>> getDailyTaskStatus() async {
    await checkAndResetDailyTasks();
    
    final prefs = await SharedPreferences.getInstance();
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return {};

    final username = userData['username'] ?? 'default';
    final tasksKey = '${_dailyTasksKey}_$username';
    final tasksJson = prefs.getString(tasksKey);
    
    if (tasksJson == null) {
      await _resetDailyTasks();
      return getDailyTaskStatus();
    }

    final tasksData = jsonDecode(tasksJson) as Map<String, dynamic>;
    final Map<String, DailyTaskStatus> status = {};

    for (final task in dailyTaskConfigs.values) {
      final taskData = tasksData[task.id] as Map<String, dynamic>? ?? {};
      status[task.id] = DailyTaskStatus(
        task: task,
        claimedCount: taskData['claimedCount'] ?? 0,
        completed: taskData['completed'] ?? false,
        lastClaimDate: taskData['lastClaimDate'] != null 
            ? DateTime.parse(taskData['lastClaimDate']) 
            : null,
      );
    }

    return status;
  }

  // 獲取用戶的每周任務狀態
  static Future<Map<String, WeeklyTaskStatus>> getWeeklyTaskStatus() async {
    await checkAndResetWeeklyTasks();
    
    final prefs = await SharedPreferences.getInstance();
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return {};

    final username = userData['username'] ?? 'default';
    final tasksKey = '${_weeklyTasksKey}_$username';
    final tasksJson = prefs.getString(tasksKey);
    
    if (tasksJson == null) {
      await _resetWeeklyTasks();
      return getWeeklyTaskStatus();
    }

    final tasksData = jsonDecode(tasksJson) as Map<String, dynamic>;
    final Map<String, WeeklyTaskStatus> status = {};

    for (final task in weeklyTaskConfigs.values) {
      final taskData = tasksData[task.id] as Map<String, dynamic>? ?? {};
      status[task.id] = WeeklyTaskStatus(
        task: task,
        claimedCount: taskData['claimedCount'] ?? 0,
        completed: taskData['completed'] ?? false,
        lastClaimDate: taskData['lastClaimDate'] != null 
            ? DateTime.parse(taskData['lastClaimDate']) 
            : null,
      );
    }

    return status;
  }

  // 檢查任務是否可以領取獎勵
  static Future<bool> canClaimReward(String taskId) async {
    final status = await getDailyTaskStatus();
    final taskStatus = status[taskId];
    if (taskStatus == null) return false;

    final task = dailyTaskConfigs[taskId];
    if (task == null) return false;

    // 檢查是否達到每日上限
    if (taskStatus.claimedCount >= task.maxDailyClaims) {
      return false;
    }

    // 檢查是否在同一天已經領取過
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (taskStatus.lastClaimDate != null) {
      final lastClaimDate = taskStatus.lastClaimDate!.toIso8601String().split('T')[0];
      if (lastClaimDate == today) {
        return false;
      }
    }

    return true;
  }

  // 檢查每周任務是否可以領取獎勵
  static Future<bool> canClaimWeeklyReward(String taskId) async {
    final status = await getWeeklyTaskStatus();
    final taskStatus = status[taskId];
    if (taskStatus == null) return false;

    final task = weeklyTaskConfigs[taskId];
    if (task == null) return false;

    // 檢查是否達到每周上限
    if (taskStatus.claimedCount >= task.maxWeeklyClaims) {
      return false;
    }

    // 檢查是否在同一周已經領取過
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final thisWeek = startOfWeek.toIso8601String().split('T')[0];
    
    if (taskStatus.lastClaimDate != null) {
      final lastClaimDate = taskStatus.lastClaimDate!;
      final lastClaimWeek = lastClaimDate.subtract(Duration(days: lastClaimDate.weekday - 1));
      final lastClaimWeekStr = lastClaimWeek.toIso8601String().split('T')[0];
      
      if (lastClaimWeekStr == thisWeek) {
        return false;
      }
    }

    return true;
  }

  // 領取任務獎勵
  static Future<bool> claimReward(String taskId) async {
    // 檢查挑戰任務功能是否已解鎖
    if (!await isChallengeFeatureUnlocked()) {
      return false; // 功能未解鎖，不允許領取獎勵
    }

    if (!await canClaimReward(taskId)) {
      return false;
    }

    final task = dailyTaskConfigs[taskId];
    if (task == null) return false;

    // 添加金幣
    await CoinService.addCoins(task.reward);

    // 更新任務狀態
    await _updateTaskStatus(taskId);

    return true;
  }

  // 領取每周任務獎勵
  static Future<bool> claimWeeklyReward(String taskId) async {
    // 檢查挑戰任務功能是否已解鎖
    if (!await isChallengeFeatureUnlocked()) {
      return false; // 功能未解鎖，不允許領取獎勵
    }

    if (!await canClaimWeeklyReward(taskId)) {
      return false;
    }

    final task = weeklyTaskConfigs[taskId];
    if (task == null) return false;

    // 添加金幣
    await CoinService.addCoins(task.reward);

    // 更新每周任務狀態
    await _updateWeeklyTaskStatus(taskId);

    return true;
  }

  // 更新任務狀態
  static Future<void> _updateTaskStatus(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return;

    final username = userData['username'] ?? 'default';
    final tasksKey = '${_dailyTasksKey}_$username';
    final tasksJson = prefs.getString(tasksKey);
    final tasksData = tasksJson != null 
        ? jsonDecode(tasksJson) as Map<String, dynamic> 
        : <String, dynamic>{};

    final currentStatus = tasksData[taskId] as Map<String, dynamic>? ?? {};
    final currentCount = currentStatus['claimedCount'] ?? 0;

    tasksData[taskId] = {
      'claimedCount': currentCount + 1,
      'completed': true,
      'lastClaimDate': DateTime.now().toIso8601String(),
    };

    await prefs.setString(tasksKey, jsonEncode(tasksData));
  }

  // 更新每周任務狀態
  static Future<void> _updateWeeklyTaskStatus(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return;

    final username = userData['username'] ?? 'default';
    final tasksKey = '${_weeklyTasksKey}_$username';
    final tasksJson = prefs.getString(tasksKey);
    final tasksData = tasksJson != null 
        ? jsonDecode(tasksJson) as Map<String, dynamic> 
        : <String, dynamic>{};

    final currentStatus = tasksData[taskId] as Map<String, dynamic>? ?? {};
    final currentCount = currentStatus['claimedCount'] ?? 0;

    tasksData[taskId] = {
      'claimedCount': currentCount + 1,
      'completed': true,
      'lastClaimDate': DateTime.now().toIso8601String(),
    };

    await prefs.setString(tasksKey, jsonEncode(tasksData));
  }

  // 處理捷運打卡任務
  static Future<bool> handleMetroCheckin() async {
    // 檢查挑戰任務功能是否已解鎖
    if (!await isChallengeFeatureUnlocked()) {
      return false; // 功能未解鎖，不給予獎勵
    }

    if (await canClaimReward(taskMetroCheckin)) {
      return await claimReward(taskMetroCheckin);
    }
    return false;
  }

  // 處理桌寵互動任務
  static Future<bool> handlePetInteraction() async {
    // 檢查挑戰任務功能是否已解鎖
    if (!await isChallengeFeatureUnlocked()) {
      return false; // 功能未解鎖，不給予獎勵
    }

    if (await canClaimReward(taskPetInteraction)) {
      return await claimReward(taskPetInteraction);
    }
    return false;
  }

  // 處理每日訊息任務
  static Future<bool> handleDailyMessage() async {
    // 檢查挑戰任務功能是否已解鎖
    if (!await isChallengeFeatureUnlocked()) {
      return false; // 功能未解鎖，不給予獎勵
    }

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastMessageDate = prefs.getString(_lastMessageDateKey);
    
    // 如果是新的一天，重置計數
    if (lastMessageDate != today) {
      await prefs.setInt(_dailyMessageCountKey, 0);
      await prefs.setString(_lastMessageDateKey, today);
    }

    final currentCount = prefs.getInt(_dailyMessageCountKey) ?? 0;
    
    // 檢查是否達到每日上限
    if (currentCount >= dailyTaskConfigs[taskDailyMessage]!.maxDailyClaims) {
      return false;
    }

    // 增加計數
    await prefs.setInt(_dailyMessageCountKey, currentCount + 1);

    // 直接添加金幣獎勵
    await CoinService.addCoins(dailyTaskConfigs[taskDailyMessage]!.reward);

    // 更新任務狀態（記錄已領取次數）
    await _updateDailyMessageTaskStatus();

    return true;
  }

  // 更新每日訊息任務狀態
  static Future<void> _updateDailyMessageTaskStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return;

    final username = userData['username'] ?? 'default';
    final tasksKey = '${_dailyTasksKey}_$username';
    final tasksJson = prefs.getString(tasksKey);
    final tasksData = tasksJson != null 
        ? jsonDecode(tasksJson) as Map<String, dynamic> 
        : <String, dynamic>{};

    final dailyMessageCount = await getDailyMessageCount();

    tasksData[taskDailyMessage] = {
      'claimedCount': dailyMessageCount, // 使用實際的訊息計數
      'completed': true,
      'lastClaimDate': DateTime.now().toIso8601String(),
    };

    await prefs.setString(tasksKey, jsonEncode(tasksData));
  }

  // 獲取每日訊息計數
  static Future<int> getDailyMessageCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastMessageDate = prefs.getString(_lastMessageDateKey);
    
    if (lastMessageDate != today) {
      return 0;
    }
    
    return prefs.getInt(_dailyMessageCountKey) ?? 0;
  }

  /// 檢查挑戰任務功能是否已解鎖
  static Future<bool> isChallengeFeatureUnlocked() async {
    try {
      return await FeatureUnlockService.isFeatureUnlocked('挑戰任務');
    } catch (e) {
      return false;
    }
  }

  static Future<void> completeDailyTask(String taskId) async {
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return;
    
    final userId = userData['uid'];
    if (userId == null) return;
  }
}

// 每日任務配置類
class DailyTask {
  final String id;
  final String title;
  final String description;
  final int reward;
  final int maxDailyClaims;

  const DailyTask({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.maxDailyClaims,
  });
}

// 每周任務配置類
class WeeklyTask {
  final String id;
  final String title;
  final String description;
  final int reward;
  final int maxWeeklyClaims;

  const WeeklyTask({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.maxWeeklyClaims,
  });
}

// 每日任務狀態類
class DailyTaskStatus {
  final DailyTask task;
  final int claimedCount;
  final bool completed;
  final DateTime? lastClaimDate;

  DailyTaskStatus({
    required this.task,
    required this.claimedCount,
    required this.completed,
    this.lastClaimDate,
  });

  bool get canClaim => completed && claimedCount < task.maxDailyClaims;
  int get remainingClaims => task.maxDailyClaims - claimedCount;
}

// 每周任務狀態類
class WeeklyTaskStatus {
  final WeeklyTask task;
  final int claimedCount;
  final bool completed;
  final DateTime? lastClaimDate;

  WeeklyTaskStatus({
    required this.task,
    required this.claimedCount,
    required this.completed,
    this.lastClaimDate,
  });

  bool get canClaim => completed && claimedCount < task.maxWeeklyClaims;
  int get remainingClaims => task.maxWeeklyClaims - claimedCount;
} 