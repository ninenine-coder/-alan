import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'logger_service.dart';

class WelcomeCoinAnimation extends StatefulWidget {
  final VoidCallback onAnimationComplete;
  final int coinAmount;

  const WelcomeCoinAnimation({
    super.key,
    required this.onAnimationComplete,
    this.coinAmount = 500,
  });

  @override
  State<WelcomeCoinAnimation> createState() => _WelcomeCoinAnimationState();
}

class _WelcomeCoinAnimationState extends State<WelcomeCoinAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _coinController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final List<CoinAnimationData> _coins = [];
  final math.Random _random = math.Random();
  
  bool _isAnimating = false;
  bool _showCoins = false;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _coinController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
    ));

    // 初始化金幣動畫數據
    _initializeCoins();
    
    // 開始動畫
    _startAnimation();
  }

  void _initializeCoins() {
    _coins.clear();
    for (int i = 0; i < 20; i++) {
      _coins.add(CoinAnimationData(
        id: i,
        startPosition: Offset(
          _random.nextDouble() * 300 - 150,
          _random.nextDouble() * 200 - 100,
        ),
        delay: Duration(milliseconds: _random.nextInt(500)),
      ));
    }
  }

  void _startAnimation() async {
    LoggerService.info('Starting coin animation');
    setState(() {
      _isAnimating = true;
    });

    // 開始主動畫
    await _mainController.forward();
    LoggerService.debug('Main animation completed');

    // 顯示金幣
    setState(() {
      _showCoins = true;
    });
    LoggerService.debug('Coins shown');

    // 開始金幣動畫
    await _coinController.forward();
    LoggerService.debug('Coin animation completed');

    // 動畫完成
    setState(() {
      _isAnimating = false;
    });

    // 延遲一下再調用完成回調
    await Future.delayed(const Duration(milliseconds: 500));
    LoggerService.info('Calling animation complete callback');
    widget.onAnimationComplete();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _coinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: _fadeAnimation.value * 0.7),
          child: Stack(
            children: [
              // 背景模糊效果
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _fadeAnimation.value * 5,
                  sigmaY: _fadeAnimation.value * 5,
                ),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
              
              // 主要內容
              Center(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.amber.shade100,
                            Colors.amber.shade200,
                            Colors.orange.shade200,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 金幣圖標
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.amber.shade400,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.shade600.withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.monetization_on,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 標題
                          const Text(
                            '歡迎加入！',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          
                          // 描述
                          Text(
                            '首次登入贈送您',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 5),
                          
                          // 金幣數量
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.monetization_on,
                                color: Colors.amber.shade800,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.coinAmount}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // 領取按鈕
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isAnimating ? null : () {
                                if (!_isAnimating) {
                                  _startCoinAnimation();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 5,
                              ),
                              child: _isAnimating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      '立即領取',
                                      style: TextStyle(
                                        fontSize: 16,
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
              
              // 金幣動畫
              if (_showCoins)
                ..._coins.map((coin) => _buildCoinAnimation(coin)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoinAnimation(CoinAnimationData coin) {
    return AnimatedBuilder(
      animation: _coinController,
      builder: (context, child) {
        final progress = _coinController.value;
        final delayProgress = coin.delay.inMilliseconds / 500.0;
        final adjustedProgress = math.max(0, (progress - delayProgress) / (1 - delayProgress));
        
        if (adjustedProgress <= 0) return const SizedBox.shrink();

        // 計算金幣位置
        final startX = MediaQuery.of(context).size.width / 2 + coin.startPosition.dx;
        final startY = MediaQuery.of(context).size.height / 2 + coin.startPosition.dy;
        
        // 目標位置（左上角金幣框）
        final targetX = 60.0; // 左上角金幣框的X位置
        final targetY = 100.0; // 左上角金幣框的Y位置
        
        // 使用貝塞爾曲線創建拋物線效果
        final curve = Curves.easeInOut.transform(adjustedProgress.toDouble());
        final currentX = startX + (targetX - startX) * curve;
        final currentY = (startY + (targetY - startY) * curve - 50.0 * math.sin(curve * math.pi)).toDouble();
        
        // 縮放和透明度
        final scale = 1.0 - curve * 0.5;
        final opacity = 1.0 - curve * 0.8;

        return Positioned(
          left: currentX - 15,
          top: currentY - 15,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.amber.shade400,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.shade600.withValues(alpha: 0.5),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.monetization_on,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _startCoinAnimation() {
    setState(() {
      _isAnimating = true;
    });
    
    // 開始金幣動畫
    _coinController.forward().then((_) {
      setState(() {
        _isAnimating = false;
      });
    });
  }
}

class CoinAnimationData {
  final int id;
  final Offset startPosition;
  final Duration delay;

  CoinAnimationData({
    required this.id,
    required this.startPosition,
    required this.delay,
  });
} 