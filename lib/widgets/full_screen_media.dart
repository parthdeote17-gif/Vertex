import 'package:flutter/material.dart';
import 'video_player_widget.dart';

class FullScreenMedia extends StatelessWidget {
  final String mediaUrl;
  final String type; // 'image' or 'video'

  const FullScreenMedia({
    super.key,
    required this.mediaUrl,
    required this.type
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, // Content AppBar ke peeche jayega (Immersive)
      appBar: AppBar(
        backgroundColor: Colors.transparent, //  Invisible AppBar
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4), // Back button ke peeche thoda shade
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Center(
        child: type == 'video'
            ? VideoPlayerWidget(
          videoUrl: mediaUrl,
          isFullScreen: true, //  Full Screen Mode ON
          autoPlay: true,     // Auto Play ON
        )
            : InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(double.infinity), // 🔥 Free movement (Instagram style)
          minScale: 0.5,
          maxScale: 5.0, //  Deep Zoom enabled
          child: Image.network(
            mediaUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
          ),
        ),
      ),
    );
  }
}