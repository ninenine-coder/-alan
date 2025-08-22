import 'package:flutter/material.dart';
import 'theme_background_service.dart';
import 'logger_service.dart';

class ThemeBackgroundWidget extends StatefulWidget {
  final Widget child;
  final Color? overlayColor;
  final double overlayOpacity;

  const ThemeBackgroundWidget({
    super.key,
    required this.child,
    this.overlayColor,
    this.overlayOpacity = 0.3,
  });

  @override
  State<ThemeBackgroundWidget> createState() => _ThemeBackgroundWidgetState();
}

class _ThemeBackgroundWidgetState extends State<ThemeBackgroundWidget> {
  String _backgroundImageUrl = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackgroundImage();
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final imageUrl = await ThemeBackgroundService.getSelectedThemeUrl();
      if (mounted) {
        setState(() {
          _backgroundImageUrl = imageUrl;
          _isLoading = false;
        });
      }
      LoggerService.debug('主題背景已載入: $_backgroundImageUrl');
    } catch (e) {
      LoggerService.error('載入主題背景失敗: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 重新載入背景圖片（用於主題更換時）
  Future<void> reloadBackground() async {
    setState(() {
      _isLoading = true;
    });
    await _loadBackgroundImage();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.child; // 載入期間先顯示原始內容
    }

    return Stack(
      children: [
        // 背景圖片層（最底層）
        if (_backgroundImageUrl.isNotEmpty)
          Positioned.fill(
            child: _buildBackgroundImage(),
          ),
        
        // 如果沒有背景圖片，使用預設漸變背景
        if (_backgroundImageUrl.isEmpty)
          Positioned.fill(
            child: _buildDefaultBackground(),
          ),
        
        // 半透明遮罩層（可選）
        if (widget.overlayColor != null)
          Positioned.fill(
            child: Container(
              color: widget.overlayColor!.withValues(alpha: widget.overlayOpacity),
            ),
          ),
        
        // 內容層（最上層）
        widget.child,
      ],
    );
  }

  Widget _buildBackgroundImage() {
    return Image.network(
      _backgroundImageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return _buildDefaultBackground(); // 載入期間顯示預設背景
      },
      errorBuilder: (context, error, stackTrace) {
        LoggerService.warning('背景圖片載入失敗: $error');
        return _buildDefaultBackground(); // 載入失敗時顯示預設背景
      },
    );
  }

  Widget _buildDefaultBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100,
            Colors.lightBlue.shade50,
          ],
        ),
      ),
    );
  }
}

/// 全局背景刷新通知器
class ThemeBackgroundNotifier extends ChangeNotifier {
  static final ThemeBackgroundNotifier _instance = ThemeBackgroundNotifier._internal();
  
  factory ThemeBackgroundNotifier() {
    return _instance;
  }
  
  ThemeBackgroundNotifier._internal();

  /// 通知所有監聽器背景已更換
  void notifyBackgroundChanged() {
    notifyListeners();
  }
}

/// 監聽主題背景變化的 Widget
class ThemeBackgroundListener extends StatefulWidget {
  final Widget child;
  final Color? overlayColor;
  final double overlayOpacity;

  const ThemeBackgroundListener({
    super.key,
    required this.child,
    this.overlayColor,
    this.overlayOpacity = 0.3,
  });

  @override
  State<ThemeBackgroundListener> createState() => _ThemeBackgroundListenerState();
}

class _ThemeBackgroundListenerState extends State<ThemeBackgroundListener> {
  final GlobalKey<_ThemeBackgroundWidgetState> _backgroundKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 監聽背景變化通知
    ThemeBackgroundNotifier().addListener(_onBackgroundChanged);
  }

  @override
  void dispose() {
    ThemeBackgroundNotifier().removeListener(_onBackgroundChanged);
    super.dispose();
  }

  void _onBackgroundChanged() {
    // 當背景變化時，重新載入背景
    _backgroundKey.currentState?.reloadBackground();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeBackgroundWidget(
      key: _backgroundKey,
      overlayColor: widget.overlayColor,
      overlayOpacity: widget.overlayOpacity,
      child: widget.child,
    );
  }
}
