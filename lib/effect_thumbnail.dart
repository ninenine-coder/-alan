import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'logger_service.dart';

class EffectThumbnail extends StatefulWidget {
  final String videoPath; // e.g. "assets/MRTvedio/特效1.mp4"
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Widget? placeholder;
  final Widget? errorWidget;

  const EffectThumbnail({
    super.key,
    required this.videoPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<EffectThumbnail> createState() => _EffectThumbnailState();
}

class _EffectThumbnailState extends State<EffectThumbnail> {
  String? _thumbnailPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      LoggerService.info('正在生成縮圖: ${widget.videoPath}');
      
      // 複製 asset 到暫存資料夾
      final byteData = await rootBundle.load(widget.videoPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.videoPath.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      
      LoggerService.info('影片已複製到暫存檔案: ${tempFile.path}');
      
      final thumb = await VideoThumbnail.thumbnailFile(
        video: tempFile.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        maxWidth: 300,
        quality: 80,
      );

      if (mounted) {
        setState(() {
          _thumbnailPath = thumb;
          _isLoading = false;
          _hasError = false;
        });
      }
      
      LoggerService.info('縮圖生成成功: $thumb');
    } catch (e) {
      LoggerService.error('縮圖生成失敗: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = widget.placeholder ?? 
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade300, Colors.purple.shade300],
            ),
            borderRadius: widget.borderRadius,
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
    } else if (_hasError || _thumbnailPath == null) {
      content = widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey.shade300, Colors.grey.shade400],
            ),
            borderRadius: widget.borderRadius,
          ),
          child: const Center(
            child: Icon(
              Icons.video_library,
              size: 48,
              color: Colors.white,
            ),
          ),
        );
    } else {
      content = Image.file(
        File(_thumbnailPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          LoggerService.error('縮圖載入失敗: $error');
          return widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade300, Colors.orange.shade300],
                ),
                borderRadius: widget.borderRadius,
              ),
              child: const Center(
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            );
        },
      );
    }

    // 添加圓角
    if (widget.borderRadius != null) {
      content = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    // 添加點擊事件
    if (widget.onTap != null) {
      content = GestureDetector(
        onTap: widget.onTap,
        child: content,
      );
    }

    return content;
  }
}

// 快取版本的縮圖組件
class CachedEffectThumbnail extends StatefulWidget {
  final String videoPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedEffectThumbnail({
    super.key,
    required this.videoPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CachedEffectThumbnail> createState() => _CachedEffectThumbnailState();
}

class _CachedEffectThumbnailState extends State<CachedEffectThumbnail> {
  static final Map<String, String> _thumbnailCache = {};
  String? _thumbnailPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    // 檢查快取
    if (_thumbnailCache.containsKey(widget.videoPath)) {
      final cachedPath = _thumbnailCache[widget.videoPath];
      if (cachedPath != null && File(cachedPath).existsSync()) {
        setState(() {
          _thumbnailPath = cachedPath;
          _isLoading = false;
          _hasError = false;
        });
        return;
      }
    }

    // 生成新的縮圖
    await _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      LoggerService.info('正在生成縮圖: ${widget.videoPath}');
      
      // 複製 asset 到暫存資料夾
      final byteData = await rootBundle.load(widget.videoPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.videoPath.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      
      LoggerService.info('影片已複製到暫存檔案: ${tempFile.path}');
      
      final thumb = await VideoThumbnail.thumbnailFile(
        video: tempFile.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        maxWidth: 300,
        quality: 80,
      );

      if (mounted && thumb != null) {
        // 儲存到快取
        _thumbnailCache[widget.videoPath] = thumb;
        
        setState(() {
          _thumbnailPath = thumb;
          _isLoading = false;
          _hasError = false;
        });
      }
      
      LoggerService.info('縮圖生成成功: $thumb');
    } catch (e) {
      LoggerService.error('縮圖生成失敗: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = widget.placeholder ?? 
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade300, Colors.purple.shade300],
            ),
            borderRadius: widget.borderRadius,
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
    } else if (_hasError || _thumbnailPath == null) {
      content = widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey.shade300, Colors.grey.shade400],
            ),
            borderRadius: widget.borderRadius,
          ),
          child: const Center(
            child: Icon(
              Icons.video_library,
              size: 48,
              color: Colors.white,
            ),
          ),
        );
    } else {
      content = Image.file(
        File(_thumbnailPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          LoggerService.error('縮圖載入失敗: $error');
          return widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade300, Colors.orange.shade300],
                ),
                borderRadius: widget.borderRadius,
              ),
              child: const Center(
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            );
        },
      );
    }

    // 添加圓角
    if (widget.borderRadius != null) {
      content = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    // 添加點擊事件
    if (widget.onTap != null) {
      content = GestureDetector(
        onTap: widget.onTap,
        child: content,
      );
    }

    return content;
  }

  // 清除快取
  static void clearCache() {
    _thumbnailCache.clear();
  }

  // 清除特定影片的快取
  static void clearCacheForVideo(String videoPath) {
    _thumbnailCache.remove(videoPath);
  }
}
