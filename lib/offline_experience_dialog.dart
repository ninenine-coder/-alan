import 'package:flutter/material.dart';
import 'experience_sync_service.dart';
import 'logger_service.dart';

class OfflineExperienceDialog extends StatelessWidget {
  final Map<String, dynamic> offlineExperience;

  const OfflineExperienceDialog({
    super.key,
    required this.offlineExperience,
  });

  @override
  Widget build(BuildContext context) {
    final experience = offlineExperience['experience'] as int;
    final level = offlineExperience['level'] as int;
    final lastUpdate = offlineExperience['lastUpdate'];
    final progress = offlineExperience['progress'] as double;

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

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.sync, color: Colors.blue),
          SizedBox(width: 8),
          Text('經驗值同步完成'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '歡迎回來！以下是您上次離線時的經驗值：',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '等級 $level',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '$experience 經驗值',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '更新時間：$timeInfo',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: 4),
                Text(
                  '升級進度：${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            '您的經驗值已成功同步到雲端，下次登入時將顯示最新數據。',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '知道了',
            style: TextStyle(color: Colors.blue),
          ),
        ),
      ],
    );
  }

  /// 顯示離線經驗值對話框
  static Future<void> showOfflineExperienceDialog(
    BuildContext context,
    Map<String, dynamic> offlineExperience,
  ) async {
    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => OfflineExperienceDialog(
          offlineExperience: offlineExperience,
        ),
      );
    } catch (e) {
      LoggerService.error('Error showing offline experience dialog: $e');
    }
  }
}
