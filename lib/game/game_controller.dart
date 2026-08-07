import 'dart:math';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/game_config.dart';
import '../models/falling_object.dart';
import '../models/game_phase.dart';
import '../models/hud_snapshot.dart';
import '../models/lane.dart';
import '../models/pickup.dart';
import '../models/progression.dart';
import '../models/updraft.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import 'camera_rig.dart';
import 'particle_field.dart';
import 'player.dart';
import 'spawn_director.dart';
import 'vfx_manager.dart';
import 'world.dart';

/// Orchestrates the whole gameplay loop: owns the [Player], [World],
/// [SpawnDirector], [VfxManager], [ParticleField] and [CameraRig], drives them
/// with a [Ticker], resolves collisions/pickups, fires audio + haptics, and
/// exposes small [ValueNotifier]s / itself (as a [Listenable]) for the UI layer
/// to observe without ever calling `setState` on the whole tree.
///
/// [GameController] is a [ChangeNotifier] purely so it can be handed to
/// [CustomPaint.repaint]: notifying listeners repaints the canvas without
/// rebuilding any widgets.
class GameController extends ChangeNotifier {
  GameController({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick);
    spawnDirector.onImpact = _onHazardImpact;
    spawnDirector.onUpdraftActivated = _onUpdraftActivated;
  }

  final ProgressService _progress = ProgressService.instance;
  final AudioService _audio = AudioService.instance;
  final HapticService _haptics = HapticService.instance;
  final Random _random = Random();

  late final Ticker _ticker;
  Duration? _lastTickElapsed;

  late final World world = World(_random);
  late final VfxManager vfxManager = VfxManager(_random);
  late final ParticleField particles = ParticleField(_random);
  late final CameraRig camera = CameraRig(_random);
  late final SpawnDirector spawnDirector =
      SpawnDirector(_random, world, vfxManager);
  final Player player = Player();

  final ValueNotifier<GamePhase> phase = ValueNotifier<GamePhase>(GamePhase.ready);
  final ValueNotifier<HudSnapshot> hud = ValueNotifier<HudSnapshot>(HudSnapshot.zero);

  /// World-space Y the camera is currently centered on (== player.worldY).
  double cameraWorldY = 0;
  Size viewportSize = Size.zero;

  /// Seconds of gameplay elapsed in the current run. Read only by the painter,
  /// to drive looping ambient animation (the breathing heat of the lava), so it
  /// freezes while paused exactly like everything else.
  double runTime = 0;

  int get bestHeightMeters => _progress.bestHeightMeters;

  int _runEmbers = 0;

  /// Current Ember pickup streak and the multiplier it currently pays out.
  /// Both drop to 0 / 1 when the player dies, or when [_comboDecayTimer]
  /// elapses between two pickups (see [GameConfig.comboDecaySeconds]).
  int _emberCombo = 0;
  int _comboMultiplier = 1;
  double _comboDecayTimer = 0;

  /// Shield charges left this run (from the upgrade shop) and, while positive,
  /// the grace period a spent charge bought. Lethal checks are skipped for as
  /// long as the grace lasts, which is the window the player gets to reach a
  /// safe lane instead of ending the run.
  int _shieldCharges = 0;
  double _shieldGrace = 0;

  /// Was the player riding an updraft last frame? Used to fire the boost cue
  /// (and stop the trail) exactly on the transitions.
  bool _wasBoosting = false;

  /// Accumulates so the boost trail emits at a fixed rate rather than once per
  /// frame, which would tie its density to the device's refresh rate.
  double _boostTrailTimer = 0;

  /// Remaining hit-stop, in seconds. While positive the simulation is frozen
  /// solid: the single most effective way to make an impact feel like it has
  /// weight.
  double _hitStop = 0;

  /// Death-beat clock. Runs from 0 while [GamePhase.dying], and the results
  /// overlay is shown when it passes [_deathBeatSeconds].
  double _deathBeat = 0;
  static const double _deathBeatSeconds = 1.15;

  /// The height/embers snapshot taken the moment the player died, so the
  /// results shown after the death animation match the instant of failure.
  int _pendingDeathHeight = 0;

  /// Summary of the most recently finished run, for the Game Over screen.
  RunResult lastRunResult = RunResult.none;

  /// 0..1 fade-to-black applied over the world during the death beat.
  double get deathFade {
    if (phase.value != GamePhase.dying && phase.value != GamePhase.gameOver) {
      return 0;
    }
    if (phase.value == GamePhase.gameOver) return 0.55;
    return (_deathBeat / _deathBeatSeconds).clamp(0.0, 1.0).toDouble() * 0.55;
  }

  Future<void> initialize() async {
    await _progress.initialize();
    hud.value = HudSnapshot.zero.copyWith(
      bestHeightMeters: _progress.bestHeightMeters,
      totalEmbers: _progress.totalEmbers,
    );
  }

  void setViewportSize(Size size) {
    viewportSize = size;
  }

  void start() {
    player.reset();
    world.reset();
    spawnDirector.reset();
    vfxManager.reset();
    particles.reset();
    camera.reset();
    cameraWorldY = 0;
    runTime = 0;
    _runEmbers = 0;
    _emberCombo = 0;
    _comboMultiplier = 1;
    _comboDecayTimer = 0;
    _shieldCharges = _progress.shieldCharges;
    _shieldGrace = 0;
    _wasBoosting = false;
    _boostTrailTimer = 0;
    _hitStop = 0;
    _deathBeat = 0;
    world.ensureGenerated(GameConfig.lookAheadSegments, GameConfig.minDangerChance);
    hud.value = HudSnapshot.zero.copyWith(
      bestHeightMeters: _progress.bestHeightMeters,
      totalEmbers: _progress.totalEmbers,
      shieldCharges: _shieldCharges,
    );
    phase.value = GamePhase.playing;
    if (!_ticker.isActive) {
      _ticker.start();
    }
    _audio.play(Sfx.levelStart);
    _audio.startAmbience();
    notifyListeners();
  }

  void handlePrimaryTap() {
    if (phase.value == GamePhase.ready) {
      _haptics.medium();
      start();
    }
  }

  /// Freezes the simulation without tearing the run down. The ticker keeps
  /// running so the frame clock stays continuous and resuming can't produce
  /// one huge catch-up delta.
  void pause() {
    if (phase.value != GamePhase.playing) return;
    phase.value = GamePhase.paused;
    _audio.play(Sfx.menuOpen);
    _audio.stopAmbience();
  }

  void resume() {
    if (phase.value != GamePhase.paused) return;
    phase.value = GamePhase.playing;
    _audio.play(Sfx.menuClose);
    _audio.startAmbience();
  }

  /// Stops every looping sound. Called when the player leaves the game screen
  /// so the ridge doesn't keep rumbling under the menus.
  void quit() {
    _audio.stopAmbience();
  }

  void requestLaneChange(Lane lane) {
    if (phase.value != GamePhase.playing) return;
    if (player.lane == lane) return;
    player.switchLane(lane);
    _audio.play(Sfx.laneSwipe, rate: 0.96 + _random.nextDouble() * 0.1);
    _haptics.selection();
  }

  void _onTick(Duration elapsed) {
    final Duration? last = _lastTickElapsed;
    _lastTickElapsed = elapsed;
    if (last == null) return;
    double dt = (elapsed - last).inMicroseconds / 1000000.0;
    if (dt <= 0) return;
    if (dt > GameConfig.maxDeltaSeconds) dt = GameConfig.maxDeltaSeconds;
    switch (phase.value) {
      case GamePhase.playing:
        if (_hitStop > 0) {
          // Hold the last drawn frame completely still, but keep the camera
          // rig running so the shake starts the instant the freeze ends.
          _hitStop -= dt;
          camera.update(dt);
          notifyListeners();
          return;
        }
        _step(dt);
        break;
      case GamePhase.dying:
        _stepDeath(dt);
        break;
      case GamePhase.ready:
      case GamePhase.paused:
      case GamePhase.gameOver:
        break;
    }
  }

  /// Advances the simulation by exactly [dt], bypassing the ticker so a test
  /// can drive a deterministic number of frames.
  @visibleForTesting
  void stepForTest(double dt) {
    if (phase.value == GamePhase.playing) _step(dt);
  }

  void _step(double dt) {
    runTime += dt;
    if (_shieldGrace > 0) _shieldGrace -= dt;
    if (_emberCombo > 0) {
      _comboDecayTimer -= dt;
      if (_comboDecayTimer <= 0) {
        _emberCombo = 0;
        _comboMultiplier = 1;
      }
    }
    final double heightMeters = player.worldY / GameConfig.pixelsPerMeter;
    final double difficulty = (heightMeters / GameConfig.difficultyRampMeters)
        .clamp(0.0, 1.0)
        .toDouble();
    final double riseSpeed = GameConfig.baseRiseSpeed +
        min(GameConfig.maxRiseSpeedBonus,
            heightMeters * GameConfig.riseSpeedGrowthPerMeter);

    // If the player is currently riding an active updraft in their lane,
    // give this frame's climb a big speed bonus on top of the normal rise.
    final bool boosting =
        spawnDirector.isBoosting(player.lane, player.worldY);
    final double effectiveRiseSpeed =
        riseSpeed + (boosting ? GameConfig.updraftBoostSpeedBonus : 0);

    player.update(dt, effectiveRiseSpeed, boosting: boosting);
    cameraWorldY = player.worldY;
    camera.update(dt);
    _updateBoostFeedback(dt, boosting);

    if (player.consumeLanding()) {
      // The swipe itself already got its own whoosh in [requestLaneChange];
      // this landing only needed a puff of dust and a tap, not a second
      // audio cue borrowed from the hazard-impact sound.
      particles.spawnLandingDust(lane: player.lane, worldY: player.worldY);
      _haptics.light();
    }

    final int playerRow = player.currentRow;
    final double dangerChance = lerpDouble(
      GameConfig.minDangerChance,
      GameConfig.maxDangerChance,
      difficulty,
    )!;
    world.ensureGenerated(playerRow + GameConfig.lookAheadSegments, dangerChance);

    final double viewportHeight =
        viewportSize.height > 0 ? viewportSize.height : 720;
    final double visibleBottomWorldY =
        cameraWorldY - viewportHeight * (1 - GameConfig.playerAnchorFraction);
    world.cleanup(visibleBottomWorldY);
    world.updateGlow(dt);

    spawnDirector.update(
      dt: dt,
      playerWorldY: player.worldY,
      riseSpeed: riseSpeed,
      heightMeters: heightMeters,
      viewportHeight: viewportHeight,
      playerLane: player.lane,
    );
    vfxManager.update(
      dt: dt,
      playerWorldY: player.worldY,
      viewportHeight: viewportHeight,
    );
    particles.update(
      dt: dt,
      playerWorldY: player.worldY,
      viewportHeight: viewportHeight,
    );

    _checkPickups();

    if (_checkCollisions(playerRow) && !_absorbWithShield()) {
      _die(heightMeters);
      return;
    }

    _updateHud(heightMeters);
    notifyListeners();
  }

  /// Runs the world forward during the death beat so the ridge keeps living
  /// (lava breathes, sparks fly, the camera shakes) while the climber falls,
  /// then hands over to the results overlay.
  void _stepDeath(double dt) {
    _deathBeat += dt;
    runTime += dt;
    camera.update(dt);
    player.update(dt, 0);
    final double viewportHeight =
        viewportSize.height > 0 ? viewportSize.height : 720;
    world.updateGlow(dt);
    vfxManager.update(
      dt: dt,
      playerWorldY: player.worldY,
      viewportHeight: viewportHeight,
    );
    particles.update(
      dt: dt,
      playerWorldY: player.worldY,
      viewportHeight: viewportHeight,
    );
    if (_deathBeat >= _deathBeatSeconds) {
      _finishDeath();
    }
    notifyListeners();
  }

  void _updateBoostFeedback(double dt, bool boosting) {
    if (boosting && !_wasBoosting) {
      _audio.play(Sfx.updraftBoost);
      _haptics.medium();
    }
    _wasBoosting = boosting;
    if (!boosting) {
      _boostTrailTimer = 0;
      return;
    }
    _boostTrailTimer -= dt;
    if (_boostTrailTimer <= 0) {
      _boostTrailTimer = 0.035;
      particles.spawnBoostTrail(lane: player.lane, worldY: player.worldY);
    }
  }

  void _onHazardImpact(FallingObject obj) {
    final bool isMeteor = obj.type == FallingObjectType.meteor;
    particles.spawnImpactBurst(
      lane: obj.lane,
      worldY: obj.targetWorldY,
      heavy: isMeteor,
    );

    // Shake and thump in proportion to how close the impact was: a meteor
    // landing right beside the player should be felt, one four segments up
    // shouldn't drown out whatever they're currently dodging.
    final double rowDistance =
        (obj.targetWorldY - player.worldY).abs() / GameConfig.segmentHeight;
    final double proximity = (1 - rowDistance / 6).clamp(0.0, 1.0).toDouble();
    camera.addTrauma((isMeteor ? 0.42 : 0.26) * (0.35 + proximity * 0.65));

    _audio.play(
      isMeteor ? Sfx.meteorImpact : Sfx.stonePlatform,
      volumeScale: 0.5 + proximity * 0.5,
      rate: 0.92 + _random.nextDouble() * 0.16,
    );
    if (proximity > 0.55) {
      isMeteor ? _haptics.heavy() : _haptics.medium();
    }
  }

  void _onUpdraftActivated(Updraft updraft) {
    _audio.play(Sfx.updraftCharging, volumeScale: 0.7);
  }

  void _checkPickups() {
    final Pickup? pickup = spawnDirector.tryCollectAt(
      player.lane,
      player.worldY,
      radiusBonus: _progress.pickupRadiusBonus,
    );
    if (pickup == null) return;
    // Extend the streak first, so the pickup we just picked up already earns
    // its own new multiplier bracket (e.g. the third pickup in a row is the
    // one that flips x1 -> x2, not the fourth).
    final int previousMultiplier = _comboMultiplier;
    _emberCombo += 1;
    _comboMultiplier = (1 + _emberCombo ~/ GameConfig.comboStep)
        .clamp(1, GameConfig.comboMaxMultiplier);
    _comboDecayTimer =
        GameConfig.comboDecaySeconds + _progress.comboWindowBonusSeconds;

    final int baseValue =
        (pickup.type.value * _progress.emberValueMultiplier).round();
    final int payout = baseValue * _comboMultiplier;
    _runEmbers += payout;
    vfxManager.spawnCollectBlip(lane: pickup.lane, worldY: pickup.worldY);
    particles.spawnPickupBurst(lane: pickup.lane, worldY: pickup.worldY);
    final String label =
        _comboMultiplier > 1 ? '+$payout x$_comboMultiplier' : '+$payout';
    vfxManager.spawnFloatingText(
      lane: pickup.lane,
      worldY: pickup.worldY,
      text: label,
    );

    final bool isBig = pickup.type == PickupType.crystal ||
        pickup.type == PickupType.chest;
    if (isBig) {
      _audio.play(Sfx.bigPickup);
      camera.addTrauma(0.16);
      _haptics.medium();
    } else {
      // Rising pitch across the streak turns a run of Embers into a phrase
      // instead of the same blip over and over.
      _audio.play(
        Sfx.pickup,
        rate: 1.0 + min(_emberCombo, 8) * 0.045,
      );
      _haptics.light();
    }

    if (_comboMultiplier > previousMultiplier) {
      _audio.play(Sfx.comboChain);
      _haptics.medium();
      vfxManager.spawnFloatingText(
        lane: pickup.lane,
        worldY: pickup.worldY + GameConfig.segmentHeight * 0.55,
        text: 'COMBO x$_comboMultiplier',
      );
    }
  }

  bool _checkCollisions(int playerRow) {
    for (final obj in spawnDirector.active) {
      if (obj.phase != FallingPhase.falling) continue;
      if (obj.lane != player.lane) continue;
      final double distance = (obj.currentWorldY - player.worldY).abs();
      if (distance <= GameConfig.segmentHeight * 0.55) {
        return true;
      }
    }
    // Riding an active updraft makes the player airborne: immune to
    // ground/chasm danger for as long as they stay inside its column, so it
    // can genuinely be used to cross a dangerous stretch.
    if (spawnDirector.isBoosting(player.lane, player.worldY)) {
      return false;
    }
    return !world.isSafeToStand(playerRow, player.lane);
  }

  /// Spends a shield charge on a hit that would otherwise be lethal, returning
  /// true if the run survives.
  ///
  /// A charge buys [GameConfig.shieldGraceSeconds] of full immunity rather than
  /// just cancelling this one frame: the player is usually standing *in* lava
  /// when it triggers, so without a grace window the next frame would consume
  /// the whole stack at once.
  bool _absorbWithShield() {
    if (_shieldGrace > 0) return true;
    if (_shieldCharges <= 0) return false;
    _shieldCharges--;
    _shieldGrace = GameConfig.shieldGraceSeconds;
    vfxManager.spawnImpact(
      lane: player.lane,
      worldY: player.worldY,
      type: FallingObjectType.rockfall,
    );
    particles.spawnImpactBurst(
      lane: player.lane,
      worldY: player.worldY,
      heavy: true,
    );
    vfxManager.spawnFloatingText(
      lane: player.lane,
      worldY: player.worldY,
      text: 'SHIELD!',
    );
    camera.addTrauma(0.55);
    _hitStop = 0.07;
    _audio.play(Sfx.shield);
    _haptics.heavy();
    return true;
  }

  void _die(double heightMetersDouble) {
    if (phase.value != GamePhase.playing) return;
    _pendingDeathHeight = heightMetersDouble.floor();

    // The death beat: freeze hard for a moment, then let the climber tumble
    // off the ledge while the camera reels, before any UI appears.
    _hitStop = 0;
    _deathBeat = 0;
    camera.addTrauma(1.0);
    particles.spawnDeathBurst(lane: player.lane, worldY: player.worldY);
    player.startDeath(awayFromLane: player.lane == Lane.left ? 1 : -1);

    _audio.play(Sfx.failure);
    _audio.stopAmbience();
    _haptics.death();

    phase.value = GamePhase.dying;
    notifyListeners();
  }

  /// Banks the run and reveals the results panel, once the death animation has
  /// had its moment.
  void _finishDeath() {
    lastRunResult = _progress.recordRun(
      heightMeters: _pendingDeathHeight,
      embers: _runEmbers,
    );
    hud.value = HudSnapshot(
      heightMeters: _pendingDeathHeight,
      bestHeightMeters: _progress.bestHeightMeters,
      ridgeNumber: _ridgeNumberFor(_pendingDeathHeight),
      embersThisRun: _runEmbers,
      totalEmbers: _progress.totalEmbers,
    );
    phase.value = GamePhase.gameOver;
    _audio.play(
      lastRunResult.isNewBest ? Sfx.levelComplete : Sfx.popupAppear,
    );
  }

  void _updateHud(double heightMetersDouble) {
    final int heightMeters = heightMetersDouble.floor();
    final HudSnapshot next = HudSnapshot(
      heightMeters: heightMeters,
      bestHeightMeters: max(_progress.bestHeightMeters, heightMeters),
      ridgeNumber: _ridgeNumberFor(heightMeters),
      embersThisRun: _runEmbers,
      totalEmbers: _progress.totalEmbers,
      comboCount: _emberCombo,
      comboMultiplier: _comboMultiplier,
      shieldCharges: _shieldCharges,
    );
    if (next != hud.value) {
      // Crossing into a new Ridge is the game's only pacing milestone; give it
      // a small flourish so a long climb has punctuation.
      if (next.ridgeNumber > hud.value.ridgeNumber && hud.value.ridgeNumber > 0) {
        _audio.play(Sfx.reward, volumeScale: 0.8);
        _haptics.medium();
        vfxManager.spawnFloatingText(
          lane: player.lane,
          worldY: player.worldY + GameConfig.segmentHeight * 0.8,
          text: 'RIDGE ${next.ridgeNumber}',
        );
      }
      hud.value = next;
    }
  }

  int _ridgeNumberFor(int heightMeters) =>
      (heightMeters / GameConfig.metersPerRidge).floor() + 1;

  @override
  void dispose() {
    _audio.stopAmbience();
    _ticker.dispose();
    phase.dispose();
    hud.dispose();
    super.dispose();
  }
}
