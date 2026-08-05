import 'package:flutter/material.dart';

import 'progress_badges.dart';

/// Shown while [GamePhase.ready]: the single control hint, plus a way back to
/// the menu if the player opened the climb by accident. Starting is handled by
/// the full-screen tap gesture in [GameScreen], so this stays presentational.
class ReadyOverlay extends StatefulWidget {
  const ReadyOverlay({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  State<ReadyOverlay> createState() => _ReadyOverlayState();
}

class _ReadyOverlayState extends State<ReadyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately not wrapped in an IgnorePointer: plain text never
    // intercepts hit-testing, so taps on empty space still reach the
    // full-screen "tap to start" detector beneath, while the back button
    // wins its own taps.
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Material(
                color: Colors.black.withValues(alpha: 0.38),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: widget.onExit,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'READY TO CLIMB',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Swipe left or right to change lane',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 26),
                FadeTransition(
                  opacity: Tween<double>(begin: 0.4, end: 1).animate(_pulse),
                  child: const Text(
                    'TAP TO START',
                    style: TextStyle(
                      color: kAccent,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
