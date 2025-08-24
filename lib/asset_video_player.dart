import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'logger_service.dart';

class AssetVideoPlayer extends StatefulWidget {
  final String assetPath;
  final String? title;
  final bool autoPlay;
  final bool showControls;
  final BoxFit fit;

  const AssetVideoPlayer({
    super.key,
    required this.assetPath,
    this.title,
    this.autoPlay = false,
    this.showControls = true,
    this.fit = BoxFit.contain,
  });

  @override
  State<AssetVideoPlayer> createState() => _AssetVideoPlayerState();
}

class _AssetVideoPlayerState extends State<AssetVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _hasError = false;
  String? _errorMessage;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      LoggerService.info('正在載入影片: ${widget.assetPath}');
      
      // 複製 asset 到暫存資料夾
      final byteData = await rootBundle.load(widget.assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.assetPath.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      
      LoggerService.info('影片已複製到暫存檔案: ${tempFile.path}');

      // 初始化播放器
      final controller = VideoPlayerController.file(tempFile);
      await controller.initialize();

      if (mounted) {
        setState(() {
          _controller = controller;
          _tempFile = tempFile;
          _loading = false;
          _hasError = false;
        });

        // 自動播放
        if (widget.autoPlay) {
          await controller.play();
        }
        
        LoggerService.info('影片播放器初始化成功');
      }
    } catch (e) {
      LoggerService.error('載入影片失敗: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller != null) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      });
    }
  }

  void _restart() {
    if (_controller != null) {
      _controller!.seekTo(Duration.zero);
      _controller!.play();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    // 清理暫存檔案
    _tempFile?.delete().catchError((e) {
      LoggerService.error('清理暫存檔案失敗: $e');
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                '載入中...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                '影片載入失敗',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadVideo,
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '播放器初始化失敗',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: VideoPlayer(_controller!),
      ),
    );
  }
}

// 全螢幕影片播放器
class FullScreenVideoPlayer extends StatefulWidget {
  final String assetPath;
  final String title;

  const FullScreenVideoPlayer({
    super.key,
    required this.assetPath,
    required this.title,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _hasError = false;
  String? _errorMessage;
  File? _tempFile;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      LoggerService.info('正在載入全螢幕影片: ${widget.assetPath}');
      
      // 複製 asset 到暫存資料夾
      final byteData = await rootBundle.load(widget.assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.assetPath.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      
      LoggerService.info('影片已複製到暫存檔案: ${tempFile.path}');

      // 初始化播放器
      final controller = VideoPlayerController.file(tempFile);
      
      // 添加監聽器
      controller.addListener(() {
        if (mounted) {
          setState(() {
            _position = controller.value.position;
            _duration = controller.value.duration;
            _isPlaying = controller.value.isPlaying;
          });
        }
      });
      
      await controller.initialize();

      if (mounted) {
        setState(() {
          _controller = controller;
          _tempFile = tempFile;
          _loading = false;
          _hasError = false;
        });

        // 自動開始播放
        await controller.play();
        
        LoggerService.info('全螢幕影片播放器初始化成功');
      }
    } catch (e) {
      LoggerService.error('載入全螢幕影片失敗: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller != null) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      });
    }
  }

  void _seekTo(Duration position) {
    if (_controller != null) {
      _controller!.seekTo(position);
    }
  }

  void _restart() {
    if (_controller != null) {
      _controller!.seekTo(Duration.zero);
      _controller!.play();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller?.dispose();
    // 清理暫存檔案
    _tempFile?.delete().catchError((e) {
      LoggerService.error('清理暫存檔案失敗: $e');
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 影片播放區域
          Expanded(
            child: Center(
              child: _loading
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          '載入中...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    )
                  : _hasError
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '影片載入失敗',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadVideo,
                              child: const Text('重試'),
                            ),
                          ],
                        )
                      : _controller != null
                          ? Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: _controller!.value.aspectRatio,
                                  child: VideoPlayer(_controller!),
                                ),
                              ),
                            )
                          : const Text(
                              '播放器初始化失敗',
                              style: TextStyle(color: Colors.white),
                            ),
            ),
          ),
          
          // 控制區域
          if (!_loading && !_hasError && _controller != null) ...[
            // 進度條
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Slider(
                    value: _position.inMilliseconds.toDouble(),
                    min: 0,
                    max: _duration.inMilliseconds.toDouble(),
                    onChanged: (value) {
                      _seekTo(Duration(milliseconds: value.toInt()));
                    },
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.3),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 播放控制按鈕
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 重新播放按鈕
                  IconButton(
                    onPressed: _restart,
                    icon: const Icon(Icons.replay, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 20),
                  
                  // 播放/暫停按鈕
                  FloatingActionButton(
                    onPressed: _togglePlayPause,
                    backgroundColor: Colors.white,
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  
                  // 循環播放按鈕
                  IconButton(
                    onPressed: () {
                      _controller!.setLooping(!_controller!.value.isLooping);
                      setState(() {});
                    },
                    icon: Icon(
                      _controller!.value.isLooping ? Icons.repeat_one : Icons.repeat,
                      color: _controller!.value.isLooping ? Colors.blue : Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
