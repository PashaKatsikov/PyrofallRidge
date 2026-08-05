import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A left-to-right progress bar bound to a real progress value (0..1).
///
/// This never advances on its own: whoever owns [progress] is responsible
/// for only reporting genuine load progress, so the bar can never finish
/// filling before the app has actually finished initializing.
class LoadingProgressBar extends StatelessWidget {
  const LoadingProgressBar({super.key, required this.progress});

  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0).toDouble(),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFC24C), Color(0xFFFF5B1F)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Loading" text with an animated 1-3 dot cycle, purely cosmetic.
class LoadingDotsText extends StatefulWidget {
  const LoadingDotsText({super.key});

  @override
  State<LoadingDotsText> createState() => _LoadingDotsTextState();
}

class _LoadingDotsTextState extends State<LoadingDotsText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final int dots = 1 + (_controller.value * 3).floor() % 3;
        return Text(
          'Loading${'.' * dots}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        );
      },
    );
  }
}
