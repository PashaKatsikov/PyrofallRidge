import 'lane.dart';

/// A small pooled "+N" popup shown briefly above a collected pickup. The
/// [TextPainter] used to render it is owned and cached by the renderer
/// (see `GamePainter`), not here - this model only tracks position/timing.
class FloatingText {
  FloatingText();

  String text = '';
  Lane lane = Lane.left;
  double worldY = 0;
  double phaseTime = 0;
  double duration = 0.9;
  bool active = false;

  /// Cache key so the renderer knows when it must re-layout the
  /// [TextPainter] (only when the text content actually changes) instead of
  /// doing it every frame.
  String? paintedText;

  /// Quantised alpha bucket the currently cached [TextPainter] was built for;
  /// `-1` forces a rebuild on the next paint.
  int paintedAlphaBucket = -1;

  void reset({
    required String text,
    required Lane lane,
    required double worldY,
    required double duration,
  }) {
    this.text = text;
    this.lane = lane;
    this.worldY = worldY;
    this.duration = duration;
    phaseTime = 0;
    active = true;
    paintedText = null;
    paintedAlphaBucket = -1;
  }
}
