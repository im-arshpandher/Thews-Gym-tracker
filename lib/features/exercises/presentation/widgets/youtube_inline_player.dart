import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Inline YouTube video player that auto-plays muted on loop.
class YouTubeInlinePlayer extends StatefulWidget {
  final String videoId;

  const YouTubeInlinePlayer({super.key, required this.videoId});

  @override
  State<YouTubeInlinePlayer> createState() => _YouTubeInlinePlayerState();
}

class _YouTubeInlinePlayerState extends State<YouTubeInlinePlayer> {
  late final WebViewController _controller;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse(
          'https://www.youtube.com/embed/${widget.videoId}?enablejsapi=1&autoplay=1&mute=1&loop=1&playlist=${widget.videoId}&controls=0',
        ),
      );
  }

  @override
  void didUpdateWidget(covariant YouTubeInlinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller.loadRequest(
        Uri.parse(
          'https://www.youtube.com/embed/${widget.videoId}?enablejsapi=1&autoplay=1&mute=1&loop=1&playlist=${widget.videoId}&controls=0',
        ),
      );
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _controller.runJavaScript(
        "var v = document.querySelector('video'); if (v) v.play();",
      );
    } else {
      _controller.runJavaScript(
        "var v = document.querySelector('video'); if (v) v.pause();",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (!_isPlaying)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'PAUSED (Tap to Play)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
