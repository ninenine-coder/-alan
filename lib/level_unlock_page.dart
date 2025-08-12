import 'package:flutter/material.dart';
import 'experience_service.dart';
import 'logger_service.dart';

class LevelUnlockPage extends StatefulWidget {
  const LevelUnlockPage({super.key});

  @override
  State<LevelUnlockPage> createState() => _LevelUnlockPageState();
}

class _LevelUnlockPageState extends State<LevelUnlockPage> {
  Map<String, dynamic>? _currentExperience;
  List<String> _unlockedFeatures = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final experience = await ExperienceService.getCurrentExperience();
      final features = await ExperienceService.getUnlockedFeatures();
      
      if (mounted) {
        setState(() {
          _currentExperience = experience;
          _unlockedFeatures = features;
        });
      }
    } catch (e) {
      LoggerService.error('Error loading level unlock data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('等級與解鎖功能'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: _currentExperience == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 當前等級信息
                  _buildCurrentLevelCard(),
                  const SizedBox(height: 24),
                  
                  // 已解鎖功能
                  _buildUnlockedFeaturesSection(),
                  const SizedBox(height: 24),
                  
                  // 等級要求列表
                  _buildLevelRequirementsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentLevelCard() {
    final level = _currentExperience!['level'] as int;
    final experience = _currentExperience!['experience'] as int;
    final progress = _currentExperience!['progress'] as double;
    
    final levelInfo = ExperienceService.getLevelInfo(level);
    final expNeeded = levelInfo['expNeeded'] as int;
    final totalExpForLevel = levelInfo['totalExpForLevel'] as int;
    final currentLevelExp = experience - totalExpForLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getLevelColor(level).withValues(alpha: 0.1),
            _getLevelColor(level).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getLevelColor(level).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // 等級圖標和文字
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getLevelColor(level),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _getLevelColor(level).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '等級 $level',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getLevelColor(level),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getLevelTitle(level),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 經驗值進度
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '經驗值進度',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '$currentLevelExp/$expNeeded',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(_getLevelColor(level)),
              ),
              const SizedBox(height: 8),
              Text(
                '總經驗值: $experience',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '已解鎖功能',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        if (_unlockedFeatures.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Text(
                  '尚未解鎖任何功能',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
        else
          ...(_unlockedFeatures.map((feature) => _buildFeatureCard(feature, true))),
      ],
    );
  }

  Widget _buildLevelRequirementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '等級要求',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        _buildFeatureCard('login_reward', false, 1, '登入獎勵'),
        _buildFeatureCard('store', false, 1, '商城'),
        _buildFeatureCard('personalization', false, 6, '個人化裝扮'),
        _buildFeatureCard('pet_interaction', false, 6, '桌寵互動'),
        _buildFeatureCard('challenge_tasks', false, 11, '挑戰任務'),
        _buildFeatureCard('weekly_tasks', false, 21, '每週任務'),
        _buildFeatureCard('rare_items', false, 21, '稀有商品'),
      ],
    );
  }

  Widget _buildFeatureCard(String feature, bool isUnlocked, [int? requiredLevel, String? displayName]) {
    final name = displayName ?? _getFeatureDisplayName(feature);
    final level = requiredLevel ?? _getFeatureRequiredLevel(feature);
    final currentLevel = _currentExperience?['level'] ?? 1;
    final canUnlock = currentLevel >= level;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked 
            ? Colors.green.shade50 
            : canUnlock 
                ? Colors.blue.shade50 
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked 
              ? Colors.green.shade300 
              : canUnlock 
                  ? Colors.blue.shade300 
                  : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUnlocked ? Icons.check_circle : Icons.circle_outlined,
            color: isUnlocked 
                ? Colors.green.shade600 
                : canUnlock 
                    ? Colors.blue.shade600 
                    : Colors.grey.shade400,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked 
                        ? Colors.green.shade700 
                        : canUnlock 
                            ? Colors.blue.shade700 
                            : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isUnlocked 
                      ? '已解鎖' 
                      : '需要等級 $level',
                  style: TextStyle(
                    fontSize: 14,
                    color: isUnlocked 
                        ? Colors.green.shade600 
                        : canUnlock 
                            ? Colors.blue.shade600 
                            : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (!isUnlocked && canUnlock)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '可解鎖',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getFeatureDisplayName(String feature) {
    switch (feature) {
      case 'login_reward':
        return '登入獎勵';
      case 'store':
        return '商城';
      case 'personalization':
        return '個人化裝扮';
      case 'pet_interaction':
        return '桌寵互動';
      case 'challenge_tasks':
        return '挑戰任務';
      case 'weekly_tasks':
        return '每週任務';
      case 'rare_items':
        return '稀有商品';
      default:
        return feature;
    }
  }

  int _getFeatureRequiredLevel(String feature) {
    switch (feature) {
      case 'login_reward':
      case 'store':
        return 1;
      case 'personalization':
      case 'pet_interaction':
        return 6;
      case 'challenge_tasks':
        return 11;
      case 'weekly_tasks':
      case 'rare_items':
        return 21;
      default:
        return 1;
    }
  }

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

  String _getLevelTitle(int level) {
    if (level <= 5) {
      return '新手';
    } else if (level <= 10) {
      return '進階';
    } else if (level <= 20) {
      return '專家';
    } else {
      return '大師';
    }
  }
}
