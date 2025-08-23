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
    LoggerService.debug('ThemeBackgroundWidget 初始化');
    _loadBackgroundImageOptimized();
  }

  Future<void> _loadBackgroundImage() async {
    try {
      LoggerService.debug('開始載入背景圖片');
      final imageUrl = await ThemeBackgroundService.getSelectedThemeUrl();
      LoggerService.debug('獲取到背景URL: $imageUrl');
      
      if (mounted) {
        setState(() {
          _backgroundImageUrl = imageUrl;
          _isLoading = false;
        });
        LoggerService.debug('背景圖片狀態已更新: $_backgroundImageUrl');
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

  /// 優化的背景載入方法
  Future<void> _loadBackgroundImageOptimized() async {
    try {
      LoggerService.debug('開始優化載入背景圖片');
      
      // 設置載入狀態
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final imageUrl = await ThemeBackgroundService.getSelectedThemeUrl();
      LoggerService.debug('優化載入獲取到背景URL: $imageUrl');
      
      if (mounted) {
        setState(() {
          _backgroundImageUrl = imageUrl;
          _isLoading = false;
        });
        LoggerService.debug('優化載入背景圖片狀態已更新: $_backgroundImageUrl');
      }
      
      LoggerService.debug('主題背景已優化載入: $_backgroundImageUrl');
    } catch (e) {
      LoggerService.error('優化載入主題背景失敗: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 重新載入背景圖片（用於主題更換時）
  Future<void> reloadBackground() async {
    LoggerService.debug('重新載入背景圖片');
    setState(() {
      _isLoading = true;
    });
    await _loadBackgroundImage();
  }

  @override
  Widget build(BuildContext context) {
    LoggerService.debug('ThemeBackgroundWidget build - isLoading: $_isLoading, backgroundUrl: $_backgroundImageUrl');
    
    if (_isLoading) {
      LoggerService.debug('顯示載入狀態');
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
    LoggerService.debug('構建背景圖片: $_backgroundImageUrl');
    return Image.network(
      _backgroundImageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // 添加快取和預載入機制
      cacheWidth: MediaQuery.of(context).size.width.toInt(),
      cacheHeight: MediaQuery.of(context).size.height.toInt(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          LoggerService.debug('背景圖片載入完成');
          return child;
        }
        LoggerService.debug('背景圖片載入中: ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes}');
        // 顯示載入進度
        return Stack(
          children: [
            _buildDefaultBackground(),
            Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) {
        LoggerService.warning('背景圖片載入失敗: $error');
        return _buildDefaultBackground(); // 載入失敗時顯示預設背景
      },
    );
  }

  Widget _buildDefaultBackground() {
    LoggerService.debug('構建預設背景');
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
    LoggerService.debug('通知背景變化');
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
  String _lastBackgroundUrl = '';

  @override
  void initState() {
    super.initState();
    LoggerService.debug('ThemeBackgroundListener 初始化');
    // 監聽背景變化通知
    ThemeBackgroundNotifier().addListener(_onBackgroundChanged);
  }

  @override
  void dispose() {
    ThemeBackgroundNotifier().removeListener(_onBackgroundChanged);
    super.dispose();
  }

  void _onBackgroundChanged() async {
    LoggerService.debug('收到背景變化通知');
    // 檢查背景是否真的改變了，避免不必要的重複載入
    try {
      final newBackgroundUrl = await ThemeBackgroundService.getSelectedThemeUrl();
      LoggerService.debug('檢查背景變化 - 舊: $_lastBackgroundUrl, 新: $newBackgroundUrl');
      
      if (newBackgroundUrl != _lastBackgroundUrl) {
        _lastBackgroundUrl = newBackgroundUrl;
        // 當背景變化時，重新載入背景
        _backgroundKey.currentState?.reloadBackground();
        LoggerService.debug('背景已更新: $newBackgroundUrl');
      } else {
        LoggerService.debug('背景未變化，跳過重載');
      }
    } catch (e) {
      LoggerService.error('檢查背景變化失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    LoggerService.debug('ThemeBackgroundListener build');
    return ThemeBackgroundWidget(
      key: _backgroundKey,
      overlayColor: widget.overlayColor,
      overlayOpacity: widget.overlayOpacity,
      child: widget.child,
    );
  }
}
