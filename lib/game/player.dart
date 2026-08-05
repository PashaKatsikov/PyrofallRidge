import '../core/game_config.dart';
import '../models/lane.dart';

/// Player runtime state.
///
/// The player is always logically bound to a single [lane]; a swipe changes
/// [lane] immediately (per the fairness/control requirements) while
/// [visualLaneT] eases the on-screen X position towards it purely for
/// presentation.
class Player {
  Lane lane = Lane.left;
  Lane _visualFromLane = Lane.left;
  double _visualT = 1; // 0 -> just started transition, 1 -> settled.

  /// Absolute world height climbed so far, in logical pixels. Monotonic.
  double worldY = 0;

  int get currentRow => (worldY / GameConfig.segmentHeight).floor();

  /// Which way the climber is turned: 1 = towards the right lane, -1 = towards
  /// the left one. Purely cosmetic, but it makes a swipe read as the character
  /// turning rather than sliding sideways while staring straight ahead.
  int facing = 1;

  void switchLane(Lane target) {
    if (target == lane) return;
    _visualFromLane = _currentVisualLane();
    lane = target;
    facing = target == Lane.right ? 1 : -1;
    _visualT = 0;
  }

  Lane _currentVisualLane() => _visualT >= 1 ? lane : _visualFromLane;

  /// 0 = fully on the "from" lane, 1 = fully on [lane]. Used to interpolate
  /// the on-screen X position without affecting collision logic.
  double get laneAnimationT => _visualT;
  Lane get animationFromLane => _visualFromLane;

  void update(double dt, double riseSpeed) {
    worldY += riseSpeed * dt;
    if (_visualT < 1) {
      _visualT += dt / GameConfig.laneChangeAnimationSeconds;
      if (_visualT > 1) _visualT = 1;
    }
  }

  void reset() {
    lane = Lane.left;
    _visualFromLane = Lane.left;
    _visualT = 1;
    facing = 1;
    worldY = 0;
  }
}
