import '../rendering/vfx_sprites.dart';
import 'lane.dart';

/// One frame of a VFX timeline: a sprite shown for [duration] seconds while
/// its scale and alpha ease linearly from the "from" to the "to" value.
class VfxFrameSpec {
  const VfxFrameSpec({
    required this.sprite,
    required this.duration,
    this.scaleFrom = 1,
    this.scaleTo = 1,
    this.alphaFrom = 1,
    this.alphaTo = 1,
  });

  final VfxCoord sprite;
  final double duration;
  final double scaleFrom;
  final double scaleTo;
  final double alphaFrom;
  final double alphaTo;
}

/// Purely cosmetic categories, used only to cap how many of each kind can
/// be alive at once (e.g. never more than a couple of ambient smoke puffs).
enum VfxKind { impact, landedSmoke, ambientSmoke, collectBlip }

/// A single pooled, lane-anchored visual effect playing a short list of
/// [VfxFrameSpec]s in sequence. Never affects collisions or gameplay.
class VfxInstance {
  VfxInstance();

  List<VfxFrameSpec> _frames = const <VfxFrameSpec>[];
  int _frameIndex = 0;
  double _frameTime = 0;

  Lane lane = Lane.left;
  double worldY = 0;
  double baseSize = 40;
  VfxKind kind = VfxKind.impact;
  bool active = false;

  bool get finished => _frameIndex >= _frames.length;

  VfxFrameSpec? get _currentFrame =>
      _frameIndex < _frames.length ? _frames[_frameIndex] : null;

  double get currentScale {
    final VfxFrameSpec? frame = _currentFrame;
    if (frame == null) return 1;
    final double t = frame.duration <= 0
        ? 1.0
        : (_frameTime / frame.duration).clamp(0.0, 1.0).toDouble();
    return frame.scaleFrom + (frame.scaleTo - frame.scaleFrom) * t;
  }

  double get currentAlpha {
    final VfxFrameSpec? frame = _currentFrame;
    if (frame == null) return 0;
    final double t = frame.duration <= 0
        ? 1.0
        : (_frameTime / frame.duration).clamp(0.0, 1.0).toDouble();
    return frame.alphaFrom + (frame.alphaTo - frame.alphaFrom) * t;
  }

  VfxCoord? get currentSprite => _currentFrame?.sprite;

  void reset({
    required List<VfxFrameSpec> frames,
    required Lane lane,
    required double worldY,
    required double baseSize,
    required VfxKind kind,
  }) {
    _frames = frames;
    _frameIndex = 0;
    _frameTime = 0;
    this.lane = lane;
    this.worldY = worldY;
    this.baseSize = baseSize;
    this.kind = kind;
    active = true;
  }

  void update(double dt) {
    if (finished) return;
    _frameTime += dt;
    while (!finished && _frameTime >= _frames[_frameIndex].duration) {
      _frameTime -= _frames[_frameIndex].duration;
      _frameIndex++;
    }
  }
}
