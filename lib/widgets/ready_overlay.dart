import 'package:flutter/material.dart';

import '../services/progress_service.dart';
import 'progress_badges.dart';

/// Shown while [GamePhase.ready]: the control hint, an animated demonstration
/// of the one gesture the game uses, and a way back to the menu if the player
/// opened the climb by accident.
///
/// Starting is handled by the full-screen tap gesture in [GameScreen], so this
/// stays presentational and deliberately non-blocking.
class ReadyOverlay extends StatefulWidget {
  const ReadyOverlay({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  State<ReadyOverlay> createState() => _ReadyOverlayState();
}

class _ReadyOverlayState extends State<ReadyOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void dispose() {
    _pulse.dispose();
    _entrance.dispose();
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
                    width: 44,
                    height: 44,
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _entrance,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: _entrance, curve: Curves.easeOutCubic)),
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
                        shadows: <Shadow>[
                          Shadow(color: Colors.black87, blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SwipeHint(),
                    const SizedBox(height: 10),
                    Text(
                      'Swipe left or right to change lane',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // First climb only: the three rules that decide whether a
                    // new player understands what killed them. After that the
                    // swipe animation alone is enough of a reminder.
                    if (ProgressService.instance.runsPlayed == 0) ...[
                      const SizedBox(height: 20),
                      const _FirstRunRules(),
                    ],
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
            ),
          ),
        ],
      ),
    );
  }
}

/// The three things a first-time climber has to know, shown once.
class _FirstRunRules extends StatelessWidget {
  const _FirstRunRules();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccent.withValues(alpha: 0.35)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Rule(
            icon: Icons.whatshot_rounded,
            color: Color(0xFFFF5B1F),
            text: 'Never stand in the magma',
          ),
          SizedBox(height: 9),
          _Rule(
            icon: Icons.gps_fixed_rounded,
            color: Color(0xFFFFD24C),
            text: 'A ring on the ground means something is falling there',
          ),
          SizedBox(height: 9),
          _Rule(
            icon: Icons.local_fire_department_rounded,
            color: kAccent,
            text: 'Collect Embers in a row for a bigger multiplier',
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A finger sliding back and forth between two lane markers.
///
/// The game has exactly one control, and showing it beats describing it -
/// especially for a player who launched straight into a run without ever
/// opening How To Play.
class _SwipeHint extends StatefulWidget {
  const _SwipeHint();

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 54,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _SwipeHintPainter(_controller.value),
        ),
      ),
    );
  }
}

class _SwipeHintPainter extends CustomPainter {
  _SwipeHintPainter(this.t);

  /// 0..1, looping.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final double travel = size.width * 0.30;
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Two lane pads the finger travels between.
    for (final double dx in <double>[-travel, travel]) {
      paint.color = Colors.white.withValues(alpha: 0.13);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2 + dx, centerY),
            width: 54,
            height: 34,
          ),
          const Radius.circular(10),
        ),
        paint,
      );
    }

    // Ease out to the far pad, hold, ease back: a real swipe, not a pendulum.
    final double phase = t < 0.5 ? t * 2 : (1 - t) * 2;
    final double eased = Curves.easeInOutCubic.transform(phase);
    final double x = size.width / 2 + (eased * 2 - 1) * travel;

    // Motion trail behind the finger, fading with distance.
    final double direction = t < 0.5 ? -1 : 1;
    for (int i = 1; i <= 3; i++) {
      paint.color = kAccent.withValues(alpha: 0.16 / i);
      canvas.drawCircle(
        Offset(x + direction * i * 11, centerY),
        11.0 - i * 1.6,
        paint,
      );
    }

    paint.color = kAccent.withValues(alpha: 0.95);
    canvas.drawCircle(Offset(x, centerY), 11, paint);
    paint.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(x, centerY), 5.5, paint);

    // Chevrons on the outside of each pad, brightening as the finger nears.
    _drawChevron(canvas, Offset(size.width / 2 - travel - 40, centerY), -1,
        1 - eased);
    _drawChevron(
        canvas, Offset(size.width / 2 + travel + 40, centerY), 1, eased);
  }

  void _drawChevron(Canvas canvas, Offset center, double dir, double strength) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = kAccent.withValues(alpha: 0.25 + 0.55 * strength);
    const double h = 8;
    final Path path = Path()
      ..moveTo(center.dx - dir * 5, center.dy - h)
      ..lineTo(center.dx + dir * 5, center.dy)
      ..lineTo(center.dx - dir * 5, center.dy + h);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SwipeHintPainter oldDelegate) =>
      oldDelegate.t != t;
}
