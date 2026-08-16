import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// GIF player widget with pause/resume frame-freeze support.
class GifPlayerWidget extends StatefulWidget {
  final String url;
  final bool isPaused;
  final bool isDark;

  const GifPlayerWidget({
    super.key,
    required this.url,
    required this.isPaused,
    required this.isDark,
  });

  @override
  State<GifPlayerWidget> createState() => _GifPlayerWidgetState();
}

class _GifPlayerWidgetState extends State<GifPlayerWidget> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _currentFrame;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant GifPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _unsubscribe();
      _subscribe();
    } else if (oldWidget.isPaused != widget.isPaused) {
      if (widget.isPaused) {
        _unsubscribe();
      } else {
        _subscribe();
      }
    }
  }

  void _subscribe() {
    final provider = NetworkImage(widget.url);
    _stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() {
          _currentFrame = info;
        });
      }
    });
    _stream?.addListener(_listener!);
  }

  void _unsubscribe() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentFrame != null && widget.isPaused) {
      return RawImage(
        image: _currentFrame!.image,
        scale: _currentFrame!.scale,
        fit: BoxFit.contain,
      );
    }
    return Image.network(
      widget.url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: 180,
          child: Center(
            child: CircularProgressIndicator(
              color:
                  widget.isDark
                      ? AppColors.primaryVolt
                      : AppColors.lightPrimary,
            ),
          ),
        );
      },
      errorBuilder:
          (context, error, stackTrace) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 8),
                Text(
                  'Unable to load demo GIF',
                  style: AppTypography.bodySm(color: AppColors.error),
                ),
              ],
            ),
          ),
    );
  }
}
