import 'package:flutter/material.dart';

class MarqueeWidget extends StatefulWidget {
  final List<String> messages;
  final Duration duration;
  final TextStyle? textStyle;
  final double height;

  const MarqueeWidget({
    super.key,
    required this.messages,
    this.duration = const Duration(seconds: 3),
    this.textStyle,
    this.height = 40,
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _startAnimation();
  }

  void _startAnimation() {
    _animationController.forward().then((_) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.messages.length;
        });
        _animationController.reset();
        _startAnimation();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Opacity(
            opacity: _animation.value,
            child: Center(
              child: Text(
                widget.messages[_currentIndex],
                style: widget.textStyle ??
                    TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
