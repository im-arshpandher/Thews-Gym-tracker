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

  String _buildIframeHtml(String videoId) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background-color: #000000; overflow: hidden; }
    .iframe-container { position: relative; width: 100%; height: 100%; }
    .iframe-container iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  <div class="iframe-container">
    <iframe id="player"
      src="https://www.youtube.com/embed/$videoId?enablejsapi=1&autoplay=1&mute=1&loop=1&playlist=$videoId&controls=0&playsinline=1&rel=0"
      allow="autoplay; encrypted-media; picture-in-picture"
      allowfullscreen>
    </iframe>
  </div>
</body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            // Ignore non-critical webview resource error / cache miss
          },
        ),
      )
      ..loadHtmlString(
        _buildIframeHtml(widget.videoId),
        baseUrl: 'https://www.youtube.com',
      );
  }

  @override
  void didUpdateWidget(covariant YouTubeInlinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller.loadHtmlString(
        _buildIframeHtml(widget.videoId),
        baseUrl: 'https://www.youtube.com',
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
