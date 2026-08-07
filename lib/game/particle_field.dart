import 'dart:math';

import '../core/object_pool.dart';
import '../models/lane.dart';
import '../services/settings_service.dart';

/// What a particle looks like. The painter maps each kind to a colour ramp and
/// a blend of size/glow; the simulation only cares about the physics.
enum ParticleKind {
  /// Glowing motes rising off the ridge. The backbone of the atmosphere.
  ember,

  /// Grey flakes drifting down past the camera, for depth.
  ash,

  /// Grounded puff kicked up when the climber lands a leap.
  dust,

  /// Bright, fast, short-lived shrapnel from an impact or a collected Ember.
  spark,
}

/// One simulated particle.
///
/// Positions are stored the same way every other world object is - a [lane]
/// plus a horizontal offset from that lane's centre, and an absolute
/// [worldY] - so particles scroll with the ridge and scale with the playfield
/// on iPad for free.
class Particle {
  Lane lane = Lane.left;
  ParticleKind kind = ParticleKind.ember;

  /// Horizontal offset from the lane centre, in lane-width fractions, so a
  /// wider playfield spreads particles proportionally instead of bunching them.
  double offsetXFraction = 0;
  double worldY = 0;

  /// Velocities in lane-fractions/sec and world px/sec respectively.
  double velocityXFraction = 0;
  double velocityY = 0;

  double gravity = 0;
  double drag = 0;

  double age = 0;
  double life = 1;
  double size = 3;
  double spinSeed = 0;

  bool active = false;

  double get t => (age / life).clamp(0.0, 1.0).toDouble();
  bool get finished => age >= life;

  void reset({
    required Lane lane,
    required ParticleKind kind,
    required double offsetXFraction,
    required double worldY,
    required double velocityXFraction,
    required double velocityY,
    required double gravity,
    required double drag,
    required double life,
    required double size,
    required double spinSeed,
  }) {
    this.lane = lane;
    this.kind = kind;
    this.offsetXFraction = offsetXFraction;
    this.worldY = worldY;
    this.velocityXFraction = velocityXFraction;
    this.velocityY = velocityY;
    this.gravity = gravity;
    this.drag = drag;
    this.life = life;
    this.size = size;
    this.spinSeed = spinSeed;
    age = 0;
    active = true;
  }

  void update(double dt) {
    age += dt;
    offsetXFraction += velocityXFraction * dt;
    worldY += velocityY * dt;
    velocityY += gravity * dt;
    if (drag > 0) {
      final double damp = 1 - (drag * dt).clamp(0.0, 1.0);
      velocityXFraction *= damp;
      velocityY *= damp;
    }
  }
}

/// A pooled, allocation-free particle simulation for the atmospheric and
/// impact layer of the game.
///
/// Deliberately kept separate from [VfxManager]: that one plays authored
/// sprite timelines from the VFX atlas, while this one runs cheap physics on
/// hundreds of primitives. Both are purely cosmetic and both respect the
/// player's Effects setting - at `off` this field simply never spawns.
class ParticleField {
  ParticleField(this._random) : _pool = ObjectPool<Particle>(Particle.new);

  final Random _random;
  final ObjectPool<Particle> _pool;

  final List<Particle> active = <Particle>[];

  /// Hard ceiling at full quality. Sized so the worst case (a meteor impact
  /// during a boosted climb through an ash shower) still costs well under a
  /// millisecond of paint time on an iPhone SE.
  static const int _maxParticles = 90;

  double _emberTimer = 0;
  double _ashTimer = 0;

  int get budget =>
      (_maxParticles * SettingsService.instance.effects.vfxBudgetFactor)
          .round();

  bool get _hasRoom => active.length < budget;

  void reset() {
    for (final Particle p in active) {
      p.active = false;
      _pool.release(p);
    }
    active.clear();
    _emberTimer = 0;
    _ashTimer = 0;
  }

  void update({
    required double dt,
    required double playerWorldY,
    required double viewportHeight,
  }) {
    for (final Particle p in active) {
      p.update(dt);
    }
    active.removeWhere((Particle p) {
      if (!p.finished) return false;
      p.active = false;
      _pool.release(p);
      return true;
    });

    _spawnAtmosphere(dt, playerWorldY, viewportHeight);
  }

  /// The constant background layer: embers drifting up from the magma below,
  /// ash falling from the eruption above.
  void _spawnAtmosphere(
    double dt,
    double playerWorldY,
    double viewportHeight,
  ) {
    if (budget <= 0) return;

    _emberTimer -= dt;
    if (_emberTimer <= 0 && _hasRoom) {
      _emberTimer = 0.07 + _random.nextDouble() * 0.09;
      _spawn(
        kind: ParticleKind.ember,
        lane: _randomLane(),
        // Spread well past the lane edges so embers also drift over the void
        // strips and the chasm, tying the whole viewport together.
        offsetXFraction: _range(-1.1, 1.1),
        worldY: playerWorldY - viewportHeight * 0.45 - _random.nextDouble() * 60,
        velocityXFraction: _range(-0.10, 0.10),
        velocityY: 26 + _random.nextDouble() * 46,
        gravity: 6,
        drag: 0.12,
        life: 2.6 + _random.nextDouble() * 2.2,
        size: 1.4 + _random.nextDouble() * 2.4,
      );
    }

    // Ash only at full quality: it is the least readable layer and the first
    // thing worth dropping on a weaker device.
    if (SettingsService.instance.effects != EffectsQuality.full) return;
    _ashTimer -= dt;
    if (_ashTimer <= 0 && _hasRoom) {
      _ashTimer = 0.22 + _random.nextDouble() * 0.3;
      _spawn(
        kind: ParticleKind.ash,
        lane: _randomLane(),
        offsetXFraction: _range(-1.2, 1.2),
        worldY: playerWorldY + viewportHeight * 0.55 + _random.nextDouble() * 80,
        velocityXFraction: _range(-0.14, 0.14),
        velocityY: -(16 + _random.nextDouble() * 22),
        gravity: -4,
        drag: 0.05,
        life: 4.0 + _random.nextDouble() * 3.0,
        size: 1.6 + _random.nextDouble() * 2.0,
      );
    }
  }

  // --- Event bursts ----------------------------------------------------

  /// Puff of grit kicked sideways when the climber lands a lane change.
  void spawnLandingDust({required Lane lane, required double worldY}) {
    final int count = _scaled(7);
    for (int i = 0; i < count; i++) {
      if (!_hasRoom) return;
      final double dir = i.isEven ? 1 : -1;
      _spawn(
        kind: ParticleKind.dust,
        lane: lane,
        offsetXFraction: _range(-0.12, 0.12),
        worldY: worldY - 4,
        velocityXFraction: dir * (0.25 + _random.nextDouble() * 0.5),
        velocityY: 20 + _random.nextDouble() * 40,
        gravity: -150,
        drag: 1.6,
        life: 0.32 + _random.nextDouble() * 0.22,
        size: 2.0 + _random.nextDouble() * 2.6,
      );
    }
  }

  /// Shrapnel and fire thrown out by a hazard slamming into the ridge.
  void spawnImpactBurst({
    required Lane lane,
    required double worldY,
    required bool heavy,
  }) {
    final int count = _scaled(heavy ? 16 : 10);
    for (int i = 0; i < count; i++) {
      if (!_hasRoom) return;
      final double angle = _random.nextDouble() * pi * 2;
      final double speed = (heavy ? 1.0 : 0.7) * (60 + _random.nextDouble() * 150);
      _spawn(
        kind: ParticleKind.spark,
        lane: lane,
        offsetXFraction: 0,
        worldY: worldY,
        velocityXFraction: cos(angle) * speed / 260,
        velocityY: sin(angle) * speed,
        gravity: -240,
        drag: 0.7,
        life: 0.4 + _random.nextDouble() * 0.45,
        size: 1.6 + _random.nextDouble() * 2.4,
      );
    }
  }

  /// Bright little fan of sparks when an Ember is banked.
  void spawnPickupBurst({required Lane lane, required double worldY}) {
    final int count = _scaled(8);
    for (int i = 0; i < count; i++) {
      if (!_hasRoom) return;
      final double angle = -pi / 2 + _range(-1.1, 1.1);
      final double speed = 70 + _random.nextDouble() * 110;
      _spawn(
        kind: ParticleKind.spark,
        lane: lane,
        offsetXFraction: 0,
        worldY: worldY,
        velocityXFraction: cos(angle) * speed / 300,
        velocityY: -sin(angle) * speed,
        gravity: -160,
        drag: 1.0,
        life: 0.35 + _random.nextDouble() * 0.3,
        size: 1.4 + _random.nextDouble() * 1.8,
      );
    }
  }

  /// Trail of embers torn off the climber while an updraft carries them.
  void spawnBoostTrail({required Lane lane, required double worldY}) {
    if (!_hasRoom) return;
    _spawn(
      kind: ParticleKind.ember,
      lane: lane,
      offsetXFraction: _range(-0.18, 0.18),
      worldY: worldY - 12,
      velocityXFraction: _range(-0.16, 0.16),
      velocityY: -(30 + _random.nextDouble() * 60),
      gravity: 0,
      drag: 0.9,
      life: 0.45 + _random.nextDouble() * 0.35,
      size: 2.0 + _random.nextDouble() * 2.4,
    );
  }

  /// The eruption of sparks that sells the moment a run ends.
  void spawnDeathBurst({required Lane lane, required double worldY}) {
    final int count = _scaled(26);
    for (int i = 0; i < count; i++) {
      if (!_hasRoom) return;
      final double angle = _random.nextDouble() * pi * 2;
      final double speed = 90 + _random.nextDouble() * 240;
      _spawn(
        kind: ParticleKind.spark,
        lane: lane,
        offsetXFraction: 0,
        worldY: worldY,
        velocityXFraction: cos(angle) * speed / 240,
        velocityY: sin(angle) * speed,
        gravity: -300,
        drag: 0.5,
        life: 0.6 + _random.nextDouble() * 0.7,
        size: 2.0 + _random.nextDouble() * 3.0,
      );
    }
  }

  // --- Helpers ---------------------------------------------------------

  /// Scales a burst size by the Effects setting, always leaving at least one
  /// particle so a `reduced` burst still reads as an event.
  int _scaled(int full) {
    final double factor = SettingsService.instance.effects.vfxBudgetFactor;
    if (factor <= 0) return 0;
    return max(1, (full * factor).round());
  }

  void _spawn({
    required ParticleKind kind,
    required Lane lane,
    required double offsetXFraction,
    required double worldY,
    required double velocityXFraction,
    required double velocityY,
    required double gravity,
    required double drag,
    required double life,
    required double size,
  }) {
    final Particle p = _pool.acquire();
    p.reset(
      lane: lane,
      kind: kind,
      offsetXFraction: offsetXFraction,
      worldY: worldY,
      velocityXFraction: velocityXFraction,
      velocityY: velocityY,
      gravity: gravity,
      drag: drag,
      life: life,
      size: size,
      spinSeed: _random.nextDouble() * pi * 2,
    );
    active.add(p);
  }

  Lane _randomLane() => _random.nextBool() ? Lane.left : Lane.right;

  double _range(double a, double b) => a + _random.nextDouble() * (b - a);
}
