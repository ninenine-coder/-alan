import 'package:flutter/material.dart';

class LoginMarqueeWidget extends StatefulWidget {
  final List<String> messages;
  final Duration duration;
  final TextStyle? textStyle;
  final double height;
  final bool showIndicators;

  const LoginMarqueeWidget({
    super.key,
    required this.messages,
    this.duration = const Duration(seconds: 4),
    this.textStyle,
    this.height = 60,
    this.showIndicators = true,
  });

  @override
  State<LoginMarqueeWidget> createState() => _LoginMarqueeWidgetState();
}

class _LoginMarqueeWidgetState extends State<LoginMarqueeWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    if (!mounted) return;
    
    // 淡入顯示當前訊息
    await _fadeController.forward();
    
    // 等待顯示時間
    await Future.delayed(widget.duration);
    
    if (!mounted) return;
    
    // 淡出當前訊息
    await _fadeController.reverse();
    
    if (!mounted) return;
    
    // 切換到下一條訊息
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.messages.length;
    });
    
    // 重置動畫控制器
    _fadeController.reset();
    
    // 繼續下一輪動畫
    _startAnimation();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 主要文字區域
          Expanded(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
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
                );
              },
            ),
          ),
          
          // 指示器點
          if (widget.showIndicators && widget.messages.length > 1)
            Container(
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.messages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentIndex ? 12 : 8,
                    height: index == _currentIndex ? 12 : 8,
                    decoration: BoxDecoration(
                      color: index == _currentIndex
                          ? Colors.blue.shade400
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
