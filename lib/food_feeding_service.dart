import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'logger_service.dart';
import 'food_service.dart';

class FoodFeedingService {
  /// 餵食飼料
  static Future<bool> feedFood(String foodId, String foodName, String foodImageUrl) async {
    try {
      // 檢查是否有足夠的飼料
      final inventory = await FoodService.getUserFoodInventory();
      final currentAmount = inventory[foodId] ?? 0;
      
      if (currentAmount <= 0) {
        LoggerService.warning('飼料庫存不足: $foodName');
        return false;
      }
      
      // 減少飼料庫存
      final success = await FoodService.consumeFood(foodId, 1);
      if (!success) {
        LoggerService.error('減少飼料庫存失敗');
        return false;
      }
      
      LoggerService.info('餵食成功: $foodName (ID: $foodId)');
      return true;
    } catch (e) {
      LoggerService.error('餵食失敗: $e');
      return false;
    }
  }
  
  /// 獲取飼料圖片URL
  static String getFoodImageUrl(String foodName) {
    // 這裡可以根據飼料名稱返回對應的圖片URL
    // 暫時返回一個預設的飼料圖片
    return 'https://i.postimg.cc/3JQZ8Q8Y/food.png';
  }
}

/// 餵食動畫組件
class FoodFeedingAnimation extends StatefulWidget {
  final String foodImageUrl;
  final String foodName;
  final VoidCallback onAnimationComplete;
  
  const FoodFeedingAnimation({
    super.key,
    required this.foodImageUrl,
    required this.foodName,
    required this.onAnimationComplete,
  });

  @override
  State<FoodFeedingAnimation> createState() => _FoodFeedingAnimationState();
}

class _FoodFeedingAnimationState extends State<FoodFeedingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化動畫控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // 設置動畫
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0), // 從頭像位置開始
      end: const Offset(0, -0.5), // 飛向特效中心
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3, // 飛到中心時變小
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0, // 飛到中心時消失
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // 開始動畫
    _startAnimation();
  }
  
  void _startAnimation() async {
    // 先放大一下
    await _scaleController.forward();
    await _scaleController.reverse();
    
    // 開始飛行動畫
    _animationController.forward();
    
    // 動畫結束後回調
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_animationController, _scaleController]),
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.network(
                    widget.foodImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.shade200,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          Icons.restaurant,
                          color: Colors.orange.shade600,
                          size: 30,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
