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
import '../services/progress_service.dart';
import 'player.dart';
import 'spawn_director.dart';
import 'vfx_manager.dart';
import 'world.dart';

/// Orchestrates the whole gameplay loop: owns the [Player], [World],
/// [SpawnDirector] and [VfxManager], drives them with a [Ticker], resolves
/// collisions/pickups and exposes small [ValueNotifier]s / itself (as a
/// [Listenable]) for the UI layer to observe without ever calling
/// `setState` on the whole tree.
///
/// [GameController] is a [ChangeNotifier] purely so it can be handed to
/// [CustomPaint.repaint]: notifying listeners repaints the canvas without
/// rebuilding any widgets.
class GameController extends ChangeNotifier {
  GameController({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick);
  }

  final ProgressService _progress = ProgressService.instance;
  final Random _random = Random();

  late final Ticker _ticker;
  Duration? _lastTickElapsed;

  late final World world = World(_random);
  late final VfxManager vfxManager = VfxManager(_random);
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

  /// Summary of the most recently finished run, for the Game Over screen.
  RunResult lastRunResult = RunResult.none;

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
    cameraWorldY = 0;
    runTime = 0;
    _runEmbers = 0;
    _emberCombo = 0;
    _comboMultiplier = 1;
    _comboDecayTimer = 0;
    _shieldCharges = _progress.shieldCharges;
    _shieldGrace = 0;
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
    notifyListeners();
  }

  void handlePrimaryTap() {
    if (phase.value == GamePhase.ready) {
      start();
    }
  }

  /// Freezes the simulation without tearing the run down. The ticker keeps
  /// running so the frame clock stays continuous and resuming can't produce
  /// one huge catch-up delta.
  void pause() {
    if (phase.value != GamePhase.playing) return;
    phase.value = GamePhase.paused;
  }

  void resume() {
    if (phase.value != GamePhase.paused) return;
    phase.value = GamePhase.playing;
  }

  void requestLaneChange(Lane lane) {
    if (phase.value != GamePhase.playing) return;
    player.switchLane(lane);
  }

  void _onTick(Duration elapsed) {
    final Duration? last = _lastTickElapsed;
    _lastTickElapsed = elapsed;
    if (last == null) return;
    double dt = (elapsed - last).inMicroseconds / 1000000.0;
    if (dt <= 0) return;
    if (dt > GameConfig.maxDeltaSeconds) dt = GameConfig.maxDeltaSeconds;
    if (phase.value == GamePhase.playing) {
      _step(dt);
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

    player.update(dt, effectiveRiseSpeed);
    cameraWorldY = player.worldY;

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

    _checkPickups();

    if (_checkCollisions(playerRow) && !_absorbWithShield()) {
      _die(heightMeters);
      return;
    }

    _updateHud(heightMeters);
    notifyListeners();
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
    final String label =
        _comboMultiplier > 1 ? '+$payout x$_comboMultiplier' : '+$payout';
    vfxManager.spawnFloatingText(
      lane: pickup.lane,
      worldY: pickup.worldY,
      text: label,
    );
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
    vfxManager.spawnFloatingText(
      lane: player.lane,
      worldY: player.worldY,
      text: 'SHIELD!',
    );
    return true;
  }

  void _die(double heightMetersDouble) {
    if (phase.value != GamePhase.playing) return;
    final int heightMeters = heightMetersDouble.floor();
    lastRunResult = _progress.recordRun(
      heightMeters: heightMeters,
      embers: _runEmbers,
    );
    hud.value = HudSnapshot(
      heightMeters: heightMeters,
      bestHeightMeters: _progress.bestHeightMeters,
      ridgeNumber: _ridgeNumberFor(heightMeters),
      embersThisRun: _runEmbers,
      totalEmbers: _progress.totalEmbers,
    );
    phase.value = GamePhase.gameOver;
    notifyListeners();
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
      hud.value = next;
    }
  }

  int _ridgeNumberFor(int heightMeters) =>
      (heightMeters / GameConfig.metersPerRidge).floor() + 1;

  @override
  void dispose() {
    _ticker.dispose();
    phase.dispose();
    hud.dispose();
    super.dispose();
  }
}
