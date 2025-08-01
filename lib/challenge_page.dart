import 'package:flutter/material.dart';

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

  void _toggleTaskCompletion(List<Task> taskList, int index) {
    setState(() {
      taskList[index].completed = !taskList[index].completed;
    });
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
