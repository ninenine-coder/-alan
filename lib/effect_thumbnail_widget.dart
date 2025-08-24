import 'package:flutter/material.dart';
import 'logger_service.dart';

class EffectThumbnailWidget extends StatelessWidget {
  final String effectName;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const EffectThumbnailWidget({
    super.key,
    required this.effectName,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildThumbnailContent(),
        ),
      ),
    );
  }

  Widget _buildThumbnailContent() {
    // 直接顯示預設封面
    return _buildFallbackThumbnail();
  }

  Widget _buildFallbackThumbnail() {
    // 根據特效名稱選擇不同的背景顏色和圖案
    final colors = _getEffectColors(effectName);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          // 背景圖案
          Positioned.fill(
            child: _buildBackgroundPattern(),
          ),
          // 特效圖標
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildEffectIcon(),
                const SizedBox(height: 8),
                _buildEffectName(),
              ],
            ),
          ),
          // 播放按鈕
          Positioned(
            bottom: 8,
            right: 8,
            child: _buildPlayButton(),
          ),
          // 特效類型標籤
          Positioned(
            top: 8,
            left: 8,
            child: _buildTypeLabel(),
          ),
        ],
      ),
    );
  }

  List<Color> _getEffectColors(String effectName) {
    // 根據特效名稱返回不同的顏色組合
    switch (effectName) {
      case '夜市生活':
        return [Colors.orange.shade400, Colors.red.shade400];
      case 'B-Boy':
        return [Colors.purple.shade400, Colors.blue.shade400];
      case '校外教學':
        return [Colors.green.shade400, Colors.teal.shade400];
      case '跑酷少年':
        return [Colors.indigo.shade400, Colors.purple.shade400];
      case '登山客':
        return [Colors.brown.shade400, Colors.orange.shade400];
      case '泡溫泉':
        return [Colors.blue.shade400, Colors.cyan.shade400];
      case '下雨天':
        return [Colors.grey.shade400, Colors.blue.shade400];
      case '文青少年':
        return [Colors.pink.shade400, Colors.purple.shade400];
      default:
        return [Colors.blue.shade400, Colors.purple.shade400];
    }
  }

  Widget _buildBackgroundPattern() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
      ),
      child: CustomPaint(
        painter: _EffectPatternPainter(),
      ),
    );
  }

  Widget _buildEffectIcon() {
    IconData iconData;
    double iconSize = 32;
    
    switch (effectName) {
      case '夜市生活':
        iconData = Icons.nightlife;
        break;
      case 'B-Boy':
        iconData = Icons.music_note;
        break;
      case '校外教學':
        iconData = Icons.school;
        break;
      case '跑酷少年':
        iconData = Icons.directions_run;
        break;
      case '登山客':
        iconData = Icons.landscape;
        break;
      case '泡溫泉':
        iconData = Icons.hot_tub;
        break;
      case '下雨天':
        iconData = Icons.water_drop;
        break;
      case '文青少年':
        iconData = Icons.book;
        break;
      default:
        iconData = Icons.video_library;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: iconSize,
        color: Colors.white,
      ),
    );
  }

  Widget _buildEffectName() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        effectName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPlayButton() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.play_arrow,
        size: 18,
        color: Colors.blue.shade600,
      ),
    );
  }

  Widget _buildTypeLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '特效',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EffectPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // 繪製一些裝飾性的線條
    for (int i = 0; i < 5; i++) {
      final y = size.height * (i + 1) / 6;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    for (int i = 0; i < 5; i++) {
      final x = size.width * (i + 1) / 6;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
