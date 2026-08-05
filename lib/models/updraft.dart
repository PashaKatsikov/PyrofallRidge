import 'lane.dart';

/// Lifecycle phase of an updraft: telegraph -> active -> expired.
///
/// Unlike [FallingObject], an updraft is never dangerous in any phase - it
/// is a purely helpful, rare rescue mechanic.
enum UpdraftPhase { telegraph, active, expired }

/// A vertical column of rising hot air spanning [GameConfig.updraftSpanRows]
/// segments in a single lane. While [UpdraftPhase.active], a player standing
/// in its lane and within its world-Y span is boosted upward.
///
/// Instances are pooled ([Updraft.reset]) like [FallingObject].
class Updraft {
  Updraft();

  Lane lane = Lane.left;
  UpdraftPhase phase = UpdraftPhase.telegraph;
  double phaseTime = 0;

  double telegraphDuration = 1.5;
  double activeDuration = 3.2;

  /// Inclusive row range the column spans.
  int bottomRow = 0;
  int topRow = 0;

  /// World-Y bounds matching [bottomRow]/[topRow], cached at spawn time so
  /// the per-frame boost check is a simple range comparison.
  double bottomWorldY = 0;
  double topWorldY = 0;

  bool active = false;

  void reset({
    required Lane lane,
    required int bottomRow,
    required int topRow,
    required double bottomWorldY,
    required double topWorldY,
    required double telegraphDuration,
    required double activeDuration,
  }) {
    this.lane = lane;
    this.bottomRow = bottomRow;
    this.topRow = topRow;
    this.bottomWorldY = bottomWorldY;
    this.topWorldY = topWorldY;
    this.telegraphDuration = telegraphDuration;
    this.activeDuration = activeDuration;
    phase = UpdraftPhase.telegraph;
    phaseTime = 0;
    active = true;
  }
}
