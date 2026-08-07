import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/haptic_service.dart';

/// A tap target that presses in, clicks and taps back.
///
/// Every button in the game routes through this so the three halves of "this
/// control responded to me" - the visual squash, the sound and the Taptic
/// tick - can never drift apart or be forgotten on a new screen.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius,
    this.sfx = Sfx.buttonTap,
    this.scale = 0.94,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;

  /// Cue played on release. Null for controls that already make their own
  /// noise (a purchase, a skin select) and would otherwise double up.
  final Sfx? sfx;

  final double scale;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 150),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: widget.scale,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOutBack,
  ));

  bool get _interactive => widget.enabled && widget.onTap != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!_interactive) return;
    HapticService.instance.light();
    final Sfx? sfx = widget.sfx;
    if (sfx != null) AudioService.instance.play(sfx);
    widget.onTap!.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _interactive ? (_) => _controller.forward() : null,
      onTapUp: _interactive ? (_) => _controller.reverse() : null,
      onTapCancel: _interactive ? () => _controller.reverse() : null,
      onTap: _interactive ? _handleTap : null,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
