import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isFullScreen; //  New Parameter: Check chat bubble vs Full screen
  final bool autoPlay;     //  New Parameter: Auto play logic

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.isFullScreen = false, // Default false (Chat mode)
    this.autoPlay = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  Future<void> initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    await _videoPlayerController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: widget.autoPlay, // 🔥 Control via parameter
      looping: widget.isFullScreen, // Full screen me loop on rakha hai
      aspectRatio: _videoPlayerController.value.aspectRatio,
      allowFullScreen: !widget.isFullScreen, // Agar already full screen hai toh button hide karo
      errorBuilder: (context, errorMessage) {
        return const Center(child: Text("Error playing video", style: TextStyle(color: Colors.white)));
      },
    );

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        height: widget.isFullScreen ? null : 200, // Chat me fixed height, Fullscreen me center
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // 🔥 LOGIC: Chat me Fixed Height, FullScreen me AspectRatio (Fit to screen)
    if (widget.isFullScreen) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoPlayerController.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      );
    } else {
      return Container(
        height: 200,
        width: double.infinity,
        color: Colors.black,
        child: Chewie(controller: _chewieController!),
      );
    }
  }
}