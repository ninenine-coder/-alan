import 'package:flutter/material.dart';
import 'coin_service.dart';
import 'coin_display.dart';
import 'challenge_service.dart';

class ChallengePage extends StatefulWidget {
  const ChallengePage({super.key});

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();
  
  Map<String, DailyTaskStatus> _dailyTaskStatus = {};
  Map<String, WeeklyTaskStatus> _weeklyTaskStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dailyStatus = await ChallengeService.getDailyTaskStatus();
      final weeklyStatus = await ChallengeService.getWeeklyTaskStatus();
      setState(() {
        _dailyTaskStatus = dailyStatus;
        _weeklyTaskStatus = weeklyStatus;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _claimReward(String taskId) async {
    try {
      final success = await ChallengeService.claimReward(taskId);
      if (success) {
        // 刷新金幣顯示
        _coinDisplayKey.currentState?.refreshCoins();
        
        // 重新載入任務狀態
        await _loadTasks();
        
        // 顯示成功訊息
        if (mounted) {
          final task = ChallengeService.dailyTaskConfigs[taskId];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('恭喜完成任務！獲得 ${task?.reward} 金幣'),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('無法領取獎勵，請稍後再試'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error claiming reward: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('領取獎勵時發生錯誤: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _claimWeeklyReward(String taskId) async {
    try {
      final success = await ChallengeService.claimWeeklyReward(taskId);
      if (success) {
        // 刷新金幣顯示
        _coinDisplayKey.currentState?.refreshCoins();
        
        // 重新載入任務狀態
        await _loadTasks();
        
        // 顯示成功訊息
        if (mounted) {
          final task = ChallengeService.weeklyTaskConfigs[taskId];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('恭喜完成每周任務！獲得 ${task?.reward} 金幣'),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('無法領取獎勵，請稍後再試'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error claiming weekly reward: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('領取獎勵時發生錯誤: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildDailyTaskCard(String taskId, DailyTaskStatus status) {
    final task = status.task;
    final canClaim = status.canClaim;
    final progress = '${status.claimedCount}/${task.maxDailyClaims}';
    
    // 每日聊天任務不需要手動領取按鈕
    final isDailyMessageTask = taskId == ChallengeService.taskDailyMessage;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.claimedCount > 0 ? Icons.check_circle : Icons.circle_outlined,
                  color: status.claimedCount > 0 ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '獎勵: ${task.reward} 金幣',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    progress,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (canClaim && !isDailyMessageTask) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _claimReward(taskId),
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('領取獎勵'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
            if (isDailyMessageTask) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '自動發放獎勵',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTaskCard(String taskId, WeeklyTaskStatus status) {
    final task = status.task;
    final canClaim = status.canClaim;
    final progress = '${status.claimedCount}/${task.maxWeeklyClaims}';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.claimedCount > 0 ? Icons.check_circle : Icons.circle_outlined,
                  color: status.claimedCount > 0 ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '獎勵: ${task.reward} 金幣',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    progress,
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (canClaim) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _claimWeeklyReward(taskId),
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('領取獎勵'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('挑戰任務'),
        centerTitle: true,
        actions: [
          CoinDisplay(key: _coinDisplayKey),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '每日任務'),
            Tab(text: '每周任務'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 每日任務頁面
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 12),
                    itemCount: ChallengeService.dailyTaskConfigs.length,
                    itemBuilder: (context, index) {
                      final taskId = ChallengeService.dailyTaskConfigs.keys.elementAt(index);
                      final status = _dailyTaskStatus[taskId];
                      if (status == null) {
                        return const SizedBox.shrink();
                      }
                      return _buildDailyTaskCard(taskId, status);
                    },
                  ),
                ),
          // 每周任務頁面
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 12),
                    itemCount: ChallengeService.weeklyTaskConfigs.length,
                    itemBuilder: (context, index) {
                      final taskId = ChallengeService.weeklyTaskConfigs.keys.elementAt(index);
                      final status = _weeklyTaskStatus[taskId];
                      if (status == null) {
                        return const SizedBox.shrink();
                      }
                      return _buildWeeklyTaskCard(taskId, status);
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
