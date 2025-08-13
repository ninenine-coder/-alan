import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'logger_service.dart';

class LevelUpAnimation extends StatefulWidget {
  final int newLevel;
  final VoidCallback? onAnimationComplete;

  const LevelUpAnimation({
    super.key,
    required this.newLevel,
    this.onAnimationComplete,
  });

  @override
  State<LevelUpAnimation> createState() => _LevelUpAnimationState();
}

class _LevelUpAnimationState extends State<LevelUpAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _rotationController;
  late AnimationController _particleController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimation();
  }

  void _initializeAnimations() {
    // 縮放動畫
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // 淡入淡出動畫
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // 旋轉動畫
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    // 粒子動畫
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOut,
    ));
  }

  void _startAnimation() async {
    // 開始所有動畫
    _scaleController.forward();
    _fadeController.forward();
    _rotationController.forward();
    _particleController.forward();

    // 等待動畫完成
    await Future.delayed(const Duration(milliseconds: 2500));

    // 開始淡出
    await _fadeController.reverse();

    // 動畫完成回調
    if (mounted && widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _scaleController,
        _fadeController,
        _rotationController,
        _particleController,
      ]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Stack(
            children: [
              // 背景遮罩
              Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
              
              // 主體動畫
              Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: _buildMainContent(),
                  ),
                ),
              ),
              
              // 粒子效果
              ..._buildParticles(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return Container(
      width: 300,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getLevelColor(widget.newLevel).withValues(alpha: 0.9),
            _getLevelColor(widget.newLevel).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getLevelColor(widget.newLevel).withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 升級圖標
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.star,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // 升級文字
          Text(
            '升級！',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          
          // 新等級
          Text(
            '等級 ${widget.newLevel}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          
          // 等級稱號
          Text(
            _getLevelTitle(widget.newLevel),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildParticles() {
    final particles = <Widget>[];
    final particleCount = 12;
    
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final radius = 150.0 * _particleAnimation.value;
      final x = MediaQuery.of(context).size.width / 2 + math.cos(angle) * radius;
      final y = MediaQuery.of(context).size.height / 2 + math.sin(angle) * radius;
      
      particles.add(
        Positioned(
          left: x - 4,
          top: y - 4,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getLevelColor(widget.newLevel),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    
    return particles;
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

/// 升級動畫管理器
class LevelUpAnimationManager {
  static LevelUpAnimationManager? _instance;
  static LevelUpAnimationManager get instance => _instance ??= LevelUpAnimationManager._();
  
  LevelUpAnimationManager._();

  OverlayEntry? _currentAnimation;

  /// 顯示升級動畫
  void showLevelUpAnimation(BuildContext context, int newLevel) {
    // 如果已有動畫在顯示，先移除
    hideLevelUpAnimation();
    
    _currentAnimation = OverlayEntry(
      builder: (context) => LevelUpAnimation(
        newLevel: newLevel,
        onAnimationComplete: () {
          hideLevelUpAnimation();
        },
      ),
    );
    
    Overlay.of(context).insert(_currentAnimation!);
    LoggerService.info('顯示升級動畫: 等級 $newLevel');
  }

  /// 隱藏升級動畫
  void hideLevelUpAnimation() {
    _currentAnimation?.remove();
    _currentAnimation = null;
  }
}
