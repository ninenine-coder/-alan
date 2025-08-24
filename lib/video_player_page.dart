import 'package:flutter/material.dart';
import 'asset_video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final String assetPath;
  final String effectName;

  const VideoPlayerPage({
    super.key,
    required this.assetPath,
    required this.effectName,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  @override
  Widget build(BuildContext context) {
    return FullScreenVideoPlayer(
      assetPath: widget.assetPath,
      title: widget.effectName,
    );
  }
}
