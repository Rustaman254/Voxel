import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

class ShakeAnimatedWidget extends StatefulWidget {
  final Widget child;
  final bool isShaking;
  final Duration duration;
  final double shakeOffset;
  final int shakeCount;
  final Duration startDelay;

  const ShakeAnimatedWidget({
    super.key,
    required this.child,
    this.isShaking = false,
    this.duration = const Duration(milliseconds: 500),
    this.shakeOffset = 5.0,
    this.shakeCount = 3,
    this.startDelay = Duration.zero,
  });

  @override
  _ShakeAnimatedWidgetState createState() => _ShakeAnimatedWidgetState();
}

class _ShakeAnimatedWidgetState extends State<ShakeAnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticIn,
    ));

    _checkShake();
  }

  @override
  void didUpdateWidget(ShakeAnimatedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShaking != oldWidget.isShaking) {
      _checkShake();
    }
  }

  void _checkShake() {
    _delayTimer?.cancel();
    if (widget.isShaking) {
      if (widget.startDelay > Duration.zero) {
        _delayTimer = Timer(widget.startDelay, () {
          if (mounted && widget.isShaking) {
             _controller.repeat(reverse: true);
          }
        });
      } else {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final sineValue =
            sin(widget.shakeCount * 2 * pi * _controller.value);
        return Transform.translate(
          offset: Offset(sineValue * widget.shakeOffset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
