import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The signature element: a quiet presence that watches over the room.
/// Dormant at rest, a dim steady glow while listening, and a slow ~4s
/// breath while a clip is actually recording — echoing the rhythm of the
/// sleep this app exists to not disturb. The one animated thing on this
/// screen; everywhere else stays still.
enum RingState { idle, listening, recording }

class BreathingRing extends StatefulWidget {
  const BreathingRing({super.key, required this.state, this.child, this.size = 220});

  final RingState state;

  /// Rendered centered inside the ring — typically the status word.
  final Widget? child;
  final double size;

  @override
  State<BreathingRing> createState() => _BreathingRingState();
}

class _BreathingRingState extends State<BreathingRing> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BreathingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _sync();
  }

  void _sync() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (widget.state == RingState.recording && !reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = widget.state == RingState.recording ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final breathe = widget.state == RingState.recording ? _controller.value : 0.0;
        final baseGlow = switch (widget.state) {
          RingState.idle => 0.10,
          RingState.listening => 0.26,
          RingState.recording => 0.40,
        };
        final glowOpacity = (baseGlow + breathe * 0.35).clamp(0.0, 1.0);
        final borderOpacity = switch (widget.state) {
          RingState.idle => 0.25,
          RingState.listening => 0.55,
          RingState.recording => (0.55 + breathe * 0.45).clamp(0.0, 1.0),
        };

        return SizedBox.square(
          dimension: widget.size,
          child: Transform.scale(
            scale: 1 + breathe * 0.05,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.moonlight.withValues(alpha: glowOpacity),
                    AppColors.moonlight.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: widget.size * 0.56,
                  height: widget.size * 0.56,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.moonlight.withValues(alpha: borderOpacity), width: 1.5),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
