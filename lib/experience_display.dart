import 'package:flutter/material.dart';
import 'dart:async';
import 'experience_service.dart';
import 'logger_service.dart';

class ExperienceDisplay extends StatefulWidget {
  final GlobalKey<ExperienceDisplayState>? displayKey;

  const ExperienceDisplay({this.displayKey, super.key});

  @override
  State<ExperienceDisplay> createState() => ExperienceDisplayState();
}

class ExperienceDisplayState extends State<ExperienceDisplay> {
  Map<String, dynamic> _experienceData = {
    'experience': 0,
    'level': 1,
    'progress': 0.0,
  };
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadExperienceData();
    _startExperienceTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 載入經驗值數據
  Future<void> _loadExperienceData() async {
    try {
      final data = await ExperienceService.getCurrentExperience();
      if (mounted) {
        setState(() {
          _experienceData = data;
        });
      }
    } catch (e) {
      LoggerService.error('Error loading experience data: $e');
    }
  }

  /// 開始經驗值計時器（每分鐘增加1經驗）
  void _startExperienceTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await ExperienceService.addExperience(1);
      await _loadExperienceData(); // 重新載入數據
    });
  }

  /// 刷新經驗值顯示
  Future<void> refreshExperience() async {
    await _loadExperienceData();
  }

  @override
  Widget build(BuildContext context) {
    final level = _experienceData['level'] as int;
    final experience = _experienceData['experience'] as int;
    final progress = _experienceData['progress'] as double;
    
    // 獲取等級信息
    final levelInfo = ExperienceService.getLevelInfo(level);
    final expNeeded = levelInfo['expNeeded'] as int;
    final totalExpForLevel = levelInfo['totalExpForLevel'] as int;
    final currentLevelExp = experience - totalExpForLevel;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 等級圖標
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getLevelColor(level),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // 經驗值進度條
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 等級文字
              Text(
                '等級 $level',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 2),
              
              // 進度條
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.blue.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(_getLevelColor(level)),
                ),
              ),
              const SizedBox(height: 2),
              
              // 經驗值文字
              Text(
                '$currentLevelExp/$expNeeded',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 根據等級獲取顏色
  Color _getLevelColor(int level) {
    if (level <= 5) {
      return Colors.green.shade600; // 新手綠色
    } else if (level <= 10) {
      return Colors.blue.shade600; // 進階藍色
    } else if (level <= 20) {
      return Colors.purple.shade600; // 專家紫色
    } else {
      return Colors.orange.shade600; // 大師橙色
    }
  }
}

/// 經驗值顯示組件（簡化版，用於AppBar）
class ExperienceDisplaySmall extends StatelessWidget {
  const ExperienceDisplaySmall({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ExperienceService.getCurrentExperience(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final level = data['level'] as int;
        final progress = data['progress'] as double;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 等級圖標
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _getLevelColor(level),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              
              // 進度條
              SizedBox(
                width: 40,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.blue.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(_getLevelColor(level)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 根據等級獲取顏色
  Color _getLevelColor(int level) {
    if (level <= 5) {
      return Colors.green.shade600;
    } else if (level <= 10) {
      return Colors.blue.shade600;
    } else if (level <= 20) {
      return Colors.purple.shade600;
    } else {
      return Colors.orange.shade600;
    }
  }
}
