import 'package:flutter/material.dart';
import 'coin_service.dart';
import 'coin_display.dart';

// Task 類別搬到外面
class Task {
  final String title;
  final String description;
  final String reward;
  bool completed;

  Task({
    required this.title,
    required this.description,
    required this.reward,
    this.completed = false,
  });
}

class ChallengePage extends StatefulWidget {
  const ChallengePage({super.key});

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();

  // 每日任務清單
  final List<Task> dailyTasks = [
    Task(
      title: '在任意捷運站打卡',
      description: '到任意捷運站並打卡完成任務。',
      reward: '5 金幣',
    ),
    Task(
      title: '與桌寵互動 / 取得訊息',
      description: '與桌寵完成互動或取得任意訊息。',
      reward: '5 金幣',
    ),
    Task(
      title: '路線探索',
      description: '完成路線探索任務。',
      reward: '5 金幣',
    ),
    Task(
      title: '每日問問題',
      description: '每日上線 15 次，每問一個問題可獲得 1 points。',
      reward: '最多 15 points',
    ),
  ];

  // 每周任務清單
  final List<Task> weeklyTasks = [
    Task(
      title: '購買捷運商品',
      description: '在商城購買任意捷運商品。',
      reward: '15 金幣',
    ),
    Task(
      title: '里程數達 5 公里',
      description: '累積里程數達 5 公里。',
      reward: '15 金幣',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleTaskCompletion(List<Task> taskList, int index) async {
    final task = taskList[index];
    final wasCompleted = task.completed;
    
    setState(() {
      task.completed = !task.completed;
    });

    // 如果任務剛被完成（從未完成變為完成），給予金幣獎勵
    if (!wasCompleted && task.completed) {
      final coinAmount = _extractCoinAmount(task.reward);
      if (coinAmount > 0) {
        await CoinService.addCoins(coinAmount);
        // 刷新金幣顯示
        _coinDisplayKey.currentState?.refreshCoins();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('恭喜完成任務！獲得 $coinAmount 金幣'),
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
    }
  }

  // 從獎勵文字中提取金幣數量
  int _extractCoinAmount(String reward) {
    final regex = RegExp(r'(\d+)\s*金幣');
    final match = regex.firstMatch(reward);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0;
  }

  Widget _buildTaskCard(Task task, int index, List<Task> taskList) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Icon(
          task.completed ? Icons.check_circle : Icons.circle_outlined,
          color: task.completed ? Colors.green : Colors.grey,
          size: 32,
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: task.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(task.description),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: task.completed ? Colors.grey.shade400 : Colors.amber.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            task.reward,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        onTap: () => _toggleTaskCompletion(taskList, index),
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
          ListView.builder(
            padding: const EdgeInsets.only(top: 12),
            itemCount: dailyTasks.length,
            itemBuilder: (context, index) {
              return _buildTaskCard(dailyTasks[index], index, dailyTasks);
            },
          ),
          ListView.builder(
            padding: const EdgeInsets.only(top: 12),
            itemCount: weeklyTasks.length,
            itemBuilder: (context, index) {
              return _buildTaskCard(weeklyTasks[index], index, weeklyTasks);
            },
          ),
        ],
      ),
    );
  }
}
