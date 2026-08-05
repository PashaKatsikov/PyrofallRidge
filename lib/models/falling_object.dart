import 'lane.dart';

enum FallingObjectType { rockfall, meteor }

/// Lifecycle phase of a falling object, as described in the design brief:
/// telegraph -> falling -> impact -> landed.
enum FallingPhase { telegraph, falling, impact, landed }

/// A single falling hazard-turned-platform.
///
/// Instances are pooled ([FallingObject.reset]) so the spawn director never
/// allocates during steady-state play.
class FallingObject {
  FallingObject();

  FallingObjectType type = FallingObjectType.rockfall;
  Lane lane = Lane.left;
  FallingPhase phase = FallingPhase.telegraph;

  /// The segment row this object will land on and turn into a platform.
  int targetRow = 0;

  /// Current elapsed time within the current [phase], seconds.
  double phaseTime = 0;

  /// Durations for the current run, resolved at spawn time so difficulty
  /// scaling can vary them per-object while staying deterministic.
  double telegraphDuration = 1.2;
  double fallDuration = 0.5;

  /// World-space Y the object starts falling from (above [targetRow]).
  double fallStartWorldY = 0;

  /// World-space Y of the target row (== landing position).
  double targetWorldY = 0;

  /// Current world-space Y while falling (interpolated each frame).
  double currentWorldY = 0;

  bool active = false;

  /// Picked once at spawn time so the renderer can deterministically choose
  /// one of several body/telegraph sprite variants (`variant % count`)
  /// instead of it flickering between choices every frame.
  int spriteVariant = 0;

  /// A homing meteor tracks the player's lane during its telegraph and locks
  /// on at ignition. Only ever true for [FallingObjectType.meteor], and only
  /// on rows where the alternative lane is also safe (see [SpawnDirector]) so
  /// escape is always possible.
  bool isHoming = false;

  double get halfWidth => type == FallingObjectType.rockfall ? 15 : 24;

  void reset({
    required FallingObjectType type,
    required Lane lane,
    required int targetRow,
    required double telegraphDuration,
    required double fallDuration,
    required double fallStartWorldY,
    required double targetWorldY,
    required int spriteVariant,
    bool isHoming = false,
  }) {
    this.type = type;
    this.lane = lane;
    this.targetRow = targetRow;
    this.telegraphDuration = telegraphDuration;
    this.fallDuration = fallDuration;
    this.fallStartWorldY = fallStartWorldY;
    this.targetWorldY = targetWorldY;
    this.spriteVariant = spriteVariant;
    this.isHoming = isHoming;
    currentWorldY = fallStartWorldY;
    phase = FallingPhase.telegraph;
    phaseTime = 0;
    active = true;
  }
}
