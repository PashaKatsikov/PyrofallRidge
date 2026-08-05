import 'dart:math';

import '../core/game_config.dart';
import '../core/object_pool.dart';
import '../models/falling_object.dart';
import '../models/floating_text.dart';
import '../models/lane.dart';
import '../models/vfx_instance.dart';
import '../rendering/vfx_sprites.dart';
import '../services/settings_service.dart';

/// Owns every short-lived cosmetic effect: impact bursts, lingering landed
/// smoke, distant ambient smoke and pickup "+N" popups. Everything is
/// pooled; nothing here ever touches collisions, segments or difficulty.
class VfxManager {
  VfxManager(this._random)
      : _vfxPool = ObjectPool<VfxInstance>(VfxInstance.new),
        _textPool = ObjectPool<FloatingText>(FloatingText.new);

  final Random _random;
  final ObjectPool<VfxInstance> _vfxPool;
  final ObjectPool<FloatingText> _textPool;

  final List<VfxInstance> active = <VfxInstance>[];
  final List<FloatingText> activeTexts = <FloatingText>[];

  double _timeUntilAmbientSmoke = 6;

  void reset() {
    for (final v in active) {
      _vfxPool.release(v);
    }
    active.clear();
    for (final t in activeTexts) {
      _textPool.release(t);
    }
    activeTexts.clear();
    _timeUntilAmbientSmoke =
        _randomRange(GameConfig.ambientSmokeMinInterval, GameConfig.ambientSmokeMaxInterval);
  }

  void update({
    required double dt,
    required double playerWorldY,
    required double viewportHeight,
  }) {
    for (final v in active) {
      v.update(dt);
    }
    active.removeWhere((v) {
      if (!v.finished) return false;
      v.active = false;
      _vfxPool.release(v);
      return true;
    });

    for (final t in activeTexts) {
      t.phaseTime += dt;
    }
    activeTexts.removeWhere((t) {
      if (t.phaseTime < t.duration) return false;
      t.active = false;
      _textPool.release(t);
      return true;
    });

    _timeUntilAmbientSmoke -= dt;
    if (_timeUntilAmbientSmoke <= 0 &&
        SettingsService.instance.effects == EffectsQuality.full &&
        _ambientCount() < GameConfig.maxAmbientSmoke &&
        active.length < _vfxBudget) {
      _spawnAmbientSmoke(playerWorldY, viewportHeight);
      _timeUntilAmbientSmoke = _randomRange(
        GameConfig.ambientSmokeMinInterval,
        GameConfig.ambientSmokeMaxInterval,
      );
    }
  }

  int _ambientCount() =>
      active.where((v) => v.kind == VfxKind.ambientSmoke).length;

  /// How many effects may be alive at once given the player's Effects
  /// setting. Zero means effects are off entirely.
  int get _vfxBudget =>
      (GameConfig.maxActiveVfx *
              SettingsService.instance.effects.vfxBudgetFactor)
          .round();

  /// Flash -> fire burst -> smoke (+ molten splash for meteors), optionally
  /// followed by a separate shockwave ring. Triggered exactly once, right
  /// when a falling object transitions into its impact phase.
  void spawnImpact({
    required Lane lane,
    required double worldY,
    required FallingObjectType type,
  }) {
    final bool isMeteor = type == FallingObjectType.meteor;
    final List<VfxFrameSpec> frames = <VfxFrameSpec>[
      VfxFrameSpec(
        sprite: _pick(VfxSprites.impactFlash),
        duration: 0.09,
        scaleFrom: 0.55,
        scaleTo: 1.15,
        alphaFrom: 1,
        alphaTo: 0.9,
      ),
      VfxFrameSpec(
        sprite: _pick(VfxSprites.impactFireBurst),
        duration: 0.12,
        scaleFrom: 1.0,
        scaleTo: 1.3,
        alphaFrom: 0.95,
        alphaTo: 0.6,
      ),
      if (isMeteor)
        VfxFrameSpec(
          sprite: _pick(VfxSprites.meteorMoltenSplash),
          duration: 0.12,
          scaleFrom: 1.0,
          scaleTo: 1.3,
          alphaFrom: 0.9,
          alphaTo: 0.55,
        ),
      VfxFrameSpec(
        sprite: _pick(VfxSprites.impactSmoke),
        duration: 0.16,
        scaleFrom: 1.1,
        scaleTo: 1.6,
        alphaFrom: 0.55,
        alphaTo: 0.0,
      ),
    ];
    _spawnVfx(
      frames: frames,
      lane: lane,
      worldY: worldY,
      baseSize: isMeteor ? 58 : 40,
      kind: VfxKind.impact,
    );

    // Shockwave ring is optional per the brief; keep it occasional so the
    // active-VFX budget isn't dominated by a single hazard landing.
    if (SettingsService.instance.effects == EffectsQuality.full &&
        _random.nextDouble() < 0.45) {
      _spawnVfx(
        frames: <VfxFrameSpec>[
          VfxFrameSpec(
            sprite: _pick(VfxSprites.shockwave),
            duration: 0.28,
            scaleFrom: 0.4,
            scaleTo: 1.9,
            alphaFrom: 0.5,
            alphaTo: 0.0,
          ),
        ],
        lane: lane,
        worldY: worldY,
        baseSize: 50,
        kind: VfxKind.impact,
      );
    }

    // Light smoke lingering above the fresh platform for a second or two.
    _spawnVfx(
      frames: <VfxFrameSpec>[
        VfxFrameSpec(
          sprite: _pick(VfxSprites.platformSmoke),
          duration: 1.6,
          scaleFrom: 0.75,
          scaleTo: 1.3,
          alphaFrom: 0.4,
          alphaTo: 0.0,
        ),
      ],
      lane: lane,
      worldY: worldY,
      baseSize: 34,
      kind: VfxKind.landedSmoke,
    );
  }

  /// Small bright blip shown for a fraction of a second when a pickup is
  /// collected, per the brief ((1,9)/(5,3) - the same fire-burst sprites
  /// used for hazard impacts).
  void spawnCollectBlip({required Lane lane, required double worldY}) {
    _spawnVfx(
      frames: <VfxFrameSpec>[
        VfxFrameSpec(
          sprite: _pick(VfxSprites.impactFireBurst),
          duration: GameConfig.collectBlipDuration,
          scaleFrom: 0.4,
          scaleTo: 0.85,
          alphaFrom: 0.9,
          alphaTo: 0.0,
        ),
      ],
      lane: lane,
      worldY: worldY,
      baseSize: 22,
      kind: VfxKind.collectBlip,
    );
  }

  void spawnFloatingText({
    required Lane lane,
    required double worldY,
    required String text,
  }) {
    if (activeTexts.length >= GameConfig.maxActiveFloatingTexts) return;
    final FloatingText t = _textPool.acquire();
    t.reset(
      text: text,
      lane: lane,
      worldY: worldY,
      duration: GameConfig.floatingTextDuration,
    );
    activeTexts.add(t);
  }

  void _spawnAmbientSmoke(double playerWorldY, double viewportHeight) {
    final Lane lane = _random.nextBool() ? Lane.left : Lane.right;
    final double aheadOffset = viewportHeight * (0.3 + _random.nextDouble() * 0.5);
    _spawnVfx(
      frames: <VfxFrameSpec>[
        VfxFrameSpec(
          sprite: _pick(VfxSprites.ambientSmoke),
          duration: 4.5 + _random.nextDouble() * 2.5,
          scaleFrom: 0.9,
          scaleTo: 1.5,
          alphaFrom: 0.14,
          alphaTo: 0.0,
        ),
      ],
      lane: lane,
      worldY: playerWorldY + aheadOffset,
      baseSize: 60,
      kind: VfxKind.ambientSmoke,
    );
  }

  void _spawnVfx({
    required List<VfxFrameSpec> frames,
    required Lane lane,
    required double worldY,
    required double baseSize,
    required VfxKind kind,
  }) {
    if (active.length >= _vfxBudget) return;
    final VfxInstance instance = _vfxPool.acquire();
    instance.reset(
      frames: frames,
      lane: lane,
      worldY: worldY,
      baseSize: baseSize,
      kind: kind,
    );
    active.add(instance);
  }

  VfxCoord _pick(List<VfxCoord> options) =>
      options[_random.nextInt(options.length)];

  double _randomRange(double min, double max) =>
      min + _random.nextDouble() * (max - min);
}
