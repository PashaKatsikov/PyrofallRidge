import 'dart:math';

/// Screen shake, driven by a single "trauma" value the way most action games
/// do it.
///
/// Callers add trauma for an event (a meteor landing, a shield firing, the
/// run ending) and the rig turns it into a smoothly decaying offset. Because
/// the offset is derived from `trauma²`, small events barely register while
/// big ones hit hard, and every shake tapers off instead of stopping dead.
///
/// The offset is applied by the painter as a canvas translation only: it never
/// moves the camera's world anchor, so shaking can't change what the player is
/// standing on or hide a hazard's telegraph.
class CameraRig {
  CameraRig(this._random);

  final Random _random;

  double _trauma = 0;

  /// Independent phase offsets so X and Y never trace the same wave, which is
  /// what makes a two-axis shake read as an impact rather than a wobble.
  double _time = 0;
  double _seedX = 0;
  double _seedY = 1000;

  /// How fast trauma bleeds off, in units per second.
  static const double _decayPerSecond = 1.9;

  /// Maximum displacement, in logical pixels, at full trauma.
  static const double _maxOffset = 18;

  /// Oscillations per second.
  static const double _frequency = 21;

  double offsetX = 0;
  double offsetY = 0;

  /// True while the rig is doing anything, so the painter can skip the
  /// save/translate/restore entirely on a calm frame.
  bool get isShaking => _trauma > 0.001;

  /// Adds [amount] of trauma (0..1). Stacking is capped rather than additive
  /// past 1, so a pile-up of impacts can't produce an unreadable screen.
  void addTrauma(double amount) {
    _trauma = (_trauma + amount).clamp(0.0, 1.0).toDouble();
  }

  void update(double dt) {
    if (_trauma <= 0) {
      offsetX = 0;
      offsetY = 0;
      return;
    }
    _time += dt;
    _trauma = max(0, _trauma - _decayPerSecond * dt);

    final double shake = _trauma * _trauma;
    offsetX = _maxOffset * shake * _noise(_seedX);
    offsetY = _maxOffset * shake * 0.7 * _noise(_seedY);
  }

  /// Cheap smooth pseudo-noise in -1..1: two incommensurable sines, which is
  /// plenty for an 18-pixel jitter and costs a fraction of real value noise.
  double _noise(double seed) =>
      sin((_time * _frequency) + seed) * 0.65 +
      sin((_time * _frequency * 1.73) + seed * 2.1) * 0.35;

  void reset() {
    _trauma = 0;
    _time = 0;
    offsetX = 0;
    offsetY = 0;
    _seedX = _random.nextDouble() * 100;
    _seedY = 1000 + _random.nextDouble() * 100;
  }
}
