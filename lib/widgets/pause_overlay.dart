import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'menu_tile.dart';
import 'progress_badges.dart';

/// Shown while [GamePhase.paused]: the simulation is frozen and the player
/// can resume, start over, or leave for the main menu.
///
/// The frozen world stays visible but is blurred and dimmed, so the pause reads
/// as "the climb is waiting for you" rather than as a separate screen the run
/// was thrown away for.
class PauseOverlay extends StatefulWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<PauseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation eased =
        CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: eased,
      builder: (context, child) => BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 6 * eased.value,
          sigmaY: 6 * eased.value,
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.62 * eased.value),
          child: child,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: eased,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(eased),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'PAUSED',
                    style: TextStyle(
                      color: kAccent,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 26),
                  PrimaryButton(label: 'RESUME', width: 210, onTap: widget.onResume),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'RESTART',
                    icon: Icons.refresh,
                    filled: false,
                    width: 210,
                    onTap: widget.onRestart,
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'MAIN MENU',
                    icon: Icons.home_rounded,
                    filled: false,
                    width: 210,
                    onTap: widget.onExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
