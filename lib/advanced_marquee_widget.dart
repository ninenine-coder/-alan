import 'package:flutter/material.dart';

class AdvancedMarqueeWidget extends StatefulWidget {
  final List<String> messages;
  final Duration duration;
  final TextStyle? textStyle;
  final double height;
  final Duration transitionDuration;

  const AdvancedMarqueeWidget({
    super.key,
    required this.messages,
    this.duration = const Duration(seconds: 4),
    this.textStyle,
    this.height = 50,
    this.transitionDuration = const Duration(milliseconds: 500),
  });

  @override
  State<AdvancedMarqueeWidget> createState() => _AdvancedMarqueeWidgetState();
}

class _AdvancedMarqueeWidgetState extends State<AdvancedMarqueeWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentIndex = 0;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    if (!mounted) return;
    
    // 開始顯示當前訊息
    _fadeController.forward();
    _slideController.forward();
    
    // 等待顯示時間
    await Future.delayed(widget.duration);
    
    if (!mounted) return;
    
    // 開始過渡動畫
    setState(() {
      _isTransitioning = true;
    });
    
    // 淡出當前訊息
    await _fadeController.reverse();
    await _slideController.reverse();
    
    if (!mounted) return;
    
    // 切換到下一條訊息
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.messages.length;
      _isTransitioning = false;
    });
    
    // 重置動畫控制器
    _fadeController.reset();
    _slideController.reset();
    
    // 繼續下一輪動畫
    _startAnimation();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_fadeController, _slideController]),
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.messages[_currentIndex],
                    style: widget.textStyle ??
                        TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
