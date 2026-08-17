import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Clean Fade-In Entrance Animation (No positional displacement / movement)
class FadeSlideEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;

  const FadeSlideEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 250),
    this.slideOffset = 0.0,
  });

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.child,
    );
  }
}

/// Tactile Spring-Scale Bouncing Button
class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;
  final BorderRadius? borderRadius;

  const BouncingButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 120),
    this.borderRadius,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Rolling Numeric Count-Up Text (for KM, Tonnage, Reps, XP)
class AnimatedCountText extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int decimalPlaces;
  final Duration duration;

  const AnimatedCountText({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 0,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        final formatted = decimalPlaces > 0
            ? val.toStringAsFixed(decimalPlaces)
            : val.round().toString();
        return Text(
          '$prefix$formatted$suffix',
          style: style,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// Smooth Interpolating Circular Progress Ring
class AnimatedProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;
  final Widget? centerChild;
  final Duration duration;

  const AnimatedProgressRing({
    super.key,
    required this.progress,
    this.size = 64.0,
    this.strokeWidth = 6.0,
    this.progressColor = AppColors.primaryVolt,
    this.backgroundColor = AppColors.darkSurfaceContainerHighest,
    this.centerChild,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: progress.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: val,
                strokeWidth: strokeWidth,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                backgroundColor: backgroundColor,
              ),
              ?centerChild,
            ],
          ),
        );
      },
    );
  }
}
