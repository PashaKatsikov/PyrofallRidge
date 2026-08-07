import 'dart:math';

import '../core/game_config.dart';
import '../models/lane.dart';

/// Player runtime state, split into two strictly separate halves.
///
/// **Simulation**: the player is always logically bound to a single [lane] and
/// a single [worldY]; a swipe changes [lane] immediately (per the fairness
/// requirements) and nothing in the animation layer below can ever move a
/// hitbox.
///
/// **Presentation**: a small procedural rig ([bobOffset], [hopOffset], [lean],
/// [scaleX]/[scaleY], [shadowScale]...) turns the single static skin sprite
/// into a character that climbs, leaps between ledges, lands heavily and gets
/// stretched upward by an updraft. All of it is derived from the simulation
/// state, so it can be frozen, rewound or skipped with zero gameplay effect.
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

  // --- Animation rig ---------------------------------------------------

  /// Phase of the two-step climb cycle, in radians. Advances with the actual
  /// rise speed so the character visibly picks up its pace as the ridge gets
  /// steeper instead of pedalling at a fixed rate.
  double _climbPhase = 0;

  /// 1 right after touching down, decaying to 0. Drives the squash-and-stretch
  /// that gives a lane change its weight.
  double _landSquash = 0;

  /// Set for exactly one frame when a leap touches down; see
  /// [consumeLanding].
  bool _landedThisFrame = false;

  /// Smoothed 0..1 "am I riding an updraft" value. Smoothed rather than
  /// boolean so entering and leaving a column eases the pose instead of
  /// snapping it.
  double _boostBlend = 0;

  /// Death animation clock, in seconds. Negative while alive.
  double _deathTime = -1;
  double _deathSpin = 0;
  double _deathRotation = 0;

  bool get isDying => _deathTime >= 0;
  double get deathTime => _deathTime;

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

  /// True on the single frame a lane-change leap touches down, so the caller
  /// can fire a landing thud and a puff of dust exactly once.
  bool consumeLanding() {
    if (!_landedThisFrame) return false;
    _landedThisFrame = false;
    return true;
  }

  void update(double dt, double riseSpeed, {bool boosting = false}) {
    worldY += riseSpeed * dt;

    if (_deathTime >= 0) {
      _updateDeath(dt);
      return;
    }

    _boostBlend += ((boosting ? 1.0 : 0.0) - _boostBlend) *
        min(1.0, dt * (boosting ? 9.0 : 5.0));

    // One full cycle = two steps. Tied to rise speed, with a floor so the
    // climber never freezes mid-stride when the climb is at its slowest.
    final double stepRate = 1.1 + (riseSpeed / GameConfig.baseRiseSpeed) * 0.9;
    _climbPhase = (_climbPhase + dt * stepRate * pi * 2) % (pi * 2);

    final bool wasAirborne = _visualT < 1;
    if (wasAirborne) {
      _visualT += dt / GameConfig.laneChangeAnimationSeconds;
      if (_visualT >= 1) {
        _visualT = 1;
        _landSquash = 1;
        _landedThisFrame = true;
      }
    }

    if (_landSquash > 0) {
      _landSquash -= dt / _landSquashSeconds;
      if (_landSquash < 0) _landSquash = 0;
    }
  }

  static const double _landSquashSeconds = 0.20;

  // --- Death -----------------------------------------------------------

  /// Kicks off the death animation: the climber is thrown off the ledge and
  /// tumbles out of frame while the camera holds. [awayFromLane] points the
  /// launch sideways, so a hit from a meteor in the right lane flings them
  /// left.
  void startDeath({required int awayFromLane}) {
    if (_deathTime >= 0) return;
    _deathTime = 0;
    _deathSpin = 5.2 * (awayFromLane >= 0 ? 1 : -1);
    _deathRotation = 0;
    _visualT = 1;
    _landSquash = 0;
  }

  void _updateDeath(double dt) {
    _deathTime += dt;
    _deathRotation += _deathSpin * dt;
  }

  /// Vertical offset (negative = up the screen) of the climber during the
  /// death tumble: thrown up, then dragged back down past the bottom of the
  /// frame. Integrated analytically so the arc is identical at any frame rate.
  double get deathOffsetY {
    if (_deathTime < 0) return 0;
    return -(210 * _deathTime - 450 * _deathTime * _deathTime);
  }

  double get deathOffsetX =>
      _deathTime < 0 ? 0 : _deathSpin * 11 * _deathTime;

  double get deathRotation => _deathRotation;

  double get deathAlpha {
    if (_deathTime < 0) return 1;
    return (1 - (_deathTime - 0.45) / 0.5).clamp(0.0, 1.0).toDouble();
  }

  // --- Presentation accessors -------------------------------------------

  /// Eased 0..1 progress of the lane-change leap.
  double get _hopT {
    final double t = _visualT.clamp(0.0, 1.0).toDouble();
    return 1 - pow(1 - t, 2).toDouble();
  }

  /// Vertical bob of the two-step climb cycle, in logical pixels. Negative is
  /// up. Fades out while airborne, because a leaping character shouldn't also
  /// be jogging.
  double get bobOffset {
    if (isDying) return 0;
    final double grounded = _visualT >= 1 ? 1.0 : 0.0;
    return -(sin(_climbPhase).abs()) * 3.4 * grounded;
  }

  /// Parabolic arc of the lane-change leap, in logical pixels (negative = up).
  double get hopOffset {
    if (isDying || _visualT >= 1) return 0;
    return -sin(_hopT * pi) * 22;
  }

  /// Body rotation in radians. Combines the small sway of the climb cycle with
  /// a much stronger lean into whichever lane the player is leaping towards.
  double get lean {
    if (isDying) return deathRotation;
    final double sway = sin(_climbPhase) * 0.035;
    if (_visualT >= 1) return sway;
    final double direction = lane == Lane.right ? 1.0 : -1.0;
    // Peaks early in the leap and unwinds on the way down, like a real jump.
    final double leapLean = sin(_hopT * pi) * 0.30 * direction;
    return sway * 0.4 + leapLean;
  }

  /// Horizontal scale, for squash-and-stretch. Airborne = narrow, landing =
  /// wide.
  double get scaleX {
    if (isDying) return 1;
    double s = 1 + _landSquash * 0.20;
    if (_visualT < 1) s -= sin(_hopT * pi) * 0.10;
    return s;
  }

  /// Vertical scale. Mirrors [scaleX] so the character keeps its volume, plus
  /// an extra upward stretch while an updraft has hold of them.
  double get scaleY {
    if (isDying) return 1;
    double s = 1 - _landSquash * 0.22;
    if (_visualT < 1) s += sin(_hopT * pi) * 0.12;
    // A hint of effort in the climb cycle itself.
    s += sin(_climbPhase * 2) * 0.018;
    s += _boostBlend * 0.16;
    return s;
  }

  /// 0..1 how strongly the updraft pose is applied. Exposed so the painter can
  /// scale the flame halo and the trail with it.
  double get boostBlend => _boostBlend;

  /// How far off the ground the character currently is, 0..1. Drives the
  /// contact shadow.
  double get airborneT => _visualT >= 1 ? 0 : sin(_hopT * pi);

  /// Contact-shadow size multiplier: tight and dark on the ground, wide and
  /// faint at the top of a leap.
  double get shadowScale => 1 + airborneT * 0.55 + _landSquash * 0.25;

  double get shadowAlpha => (0.38 - airborneT * 0.24) * (isDying ? 0 : 1);

  void reset() {
    lane = Lane.left;
    _visualFromLane = Lane.left;
    _visualT = 1;
    facing = 1;
    worldY = 0;
    _climbPhase = 0;
    _landSquash = 0;
    _landedThisFrame = false;
    _boostBlend = 0;
    _deathTime = -1;
    _deathSpin = 0;
    _deathRotation = 0;
  }
}
