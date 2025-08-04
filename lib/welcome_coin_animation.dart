import 'package:flutter/material.dart';
import 'coin_service.dart';

class WelcomeCoinAnimation extends StatefulWidget {
  final VoidCallback? onAnimationComplete;
  final Offset? targetPosition; // 目標位置（右上角金幣顯示位置）

  const WelcomeCoinAnimation({
    super.key, 
    this.onAnimationComplete,
    this.targetPosition,
  });

  @override
  State<WelcomeCoinAnimation> createState() => _WelcomeCoinAnimationState();
}

class _WelcomeCoinAnimationState extends State<WelcomeCoinAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _coinController;
  late AnimationController _flyController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _coinAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _flyAnimation;
  late Animation<double> _flyScaleAnimation;
  late Animation<double> _flyOpacityAnimation;

  bool _showCoins = false;
  bool _showClaimButton = false;
  bool _isFlying = false;
  int _currentCoins = 0;
  final int _targetCoins = 500;
  final int _coinIncrement = 10;

  // 計算目標位置（右上角金幣顯示元件的位置）
  Offset get _targetOffset {
    // 根據螢幕尺寸計算右上角位置
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // 右上角位置，稍微偏移以避免被狀態欄遮擋
    return Offset(screenWidth * 0.85, screenHeight * 0.08);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _coinController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _flyController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ));

    _coinAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _coinController,
      curve: Curves.easeInOut,
    ));

    // 金幣飛行動畫 - 飛向整個畫面右上角
    _flyAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero, // 將在 build 中動態計算
    ).animate(CurvedAnimation(
      parent: _flyController,
      curve: Curves.easeInOut,
    ));

    _flyScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.2,
    ).animate(CurvedAnimation(
      parent: _flyController,
      curve: Curves.easeInOut,
    ));

    _flyOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _flyController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    // 開始主動畫
    await _controller.forward();
    
    // 顯示金幣計數動畫
    setState(() {
      _showCoins = true;
    });
    
    // 開始金幣計數動畫
    _coinController.forward();
    _animateCoinCount();
  }

  void _animateCoinCount() async {
    while (_currentCoins < _targetCoins) {
      await Future.delayed(const Duration(milliseconds: 20));
      setState(() {
        _currentCoins += _coinIncrement;
        if (_currentCoins > _targetCoins) {
          _currentCoins = _targetCoins;
        }
      });
    }
    
    // 顯示領取按鈕
    setState(() {
      _showClaimButton = true;
    });
  }

  void _claimCoins() async {
    setState(() {
      _isFlying = true;
    });

    // 開始飛行動畫
    await _flyController.forward();
    
    // 動畫完成後關閉整個歡迎動畫
    if (mounted) {
      await _controller.reverse();
      widget.onAnimationComplete?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _coinController.dispose();
    _flyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 動態計算飛向目標位置
    final targetOffset = _targetOffset;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            color: Colors.black54,
            child: Stack(
              children: [
                // 歡迎動畫內容
                Center(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(40),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade300,
                              Colors.amber.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 歡迎文字
                            const Text(
                              '歡迎來到捷米小助手！',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            
                            // 金幣圖示
                            AnimatedBuilder(
                              animation: _flyController,
                              builder: (context, child) {
                                if (_isFlying) {
                                  // 計算從中心到目標的偏移
                                  final centerX = MediaQuery.of(context).size.width / 2;
                                  final centerY = MediaQuery.of(context).size.height / 2;
                                  final offsetX = targetOffset.dx - centerX;
                                  final offsetY = targetOffset.dy - centerY;
                                  
                                  return Transform.translate(
                                    offset: Offset(
                                      offsetX * _flyController.value,
                                      offsetY * _flyController.value,
                                    ),
                                    child: Transform.scale(
                                      scale: _flyScaleAnimation.value,
                                      child: Opacity(
                                        opacity: _flyOpacityAnimation.value,
                                        child: Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade400,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.amber.shade200.withOpacity(0.5),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.monetization_on,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                // 靜止的金幣
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.monetization_on,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            
                            // 贈送金幣文字
                            const Text(
                              '首次登入贈送',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            
                            // 金幣數量
                            AnimatedBuilder(
                              animation: _coinAnimation,
                              builder: (context, child) {
                                return Text(
                                  '$_currentCoins 金幣',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            
                            // 慶祝動畫
                            if (_showCoins && !_isFlying)
                              AnimatedBuilder(
                                animation: _coinAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: 0.8 + (_coinAnimation.value * 0.2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(5, (index) {
                                        return AnimatedContainer(
                                          duration: Duration(
                                            milliseconds: 200 + (index * 100),
                                          ),
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Icon(
                                            Icons.star,
                                            color: Colors.white,
                                            size: 20 + (_coinAnimation.value * 10),
                                          ),
                                        );
                                      }),
                                    ),
                                  );
                                },
                              ),
                            
                            // 領取按鈕
                            if (_showClaimButton && !_isFlying)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                child: ElevatedButton(
                                  onPressed: _claimCoins,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.amber.shade700,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: const Text(
                                    '領取金幣',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // 目標位置指示器（可選，用於調試）
                // if (_isFlying)
                //   Positioned(
                //     left: targetOffset.dx - 20,
                //     top: targetOffset.dy - 20,
                //     child: Container(
                //       width: 40,
                //       height: 40,
                //       decoration: BoxDecoration(
                //         color: Colors.red.withOpacity(0.3),
                //         shape: BoxShape.circle,
                //       ),
                //     ),
                //   ),
              ],
            ),
          ),
        );
      },
    );
  }
} 