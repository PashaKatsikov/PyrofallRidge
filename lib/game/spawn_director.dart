import 'dart:math';
import 'dart:ui' show lerpDouble;

import '../core/game_config.dart';
import '../core/object_pool.dart';
import '../models/falling_object.dart';
import '../models/lane.dart';
import '../models/pickup.dart';
import '../models/segment.dart';
import '../models/updraft.dart';
import '../rendering/item_sprites.dart';
import 'vfx_manager.dart';
import 'world.dart';

/// Decides when and where falling objects and updrafts spawn, and advances
/// their lifecycles (telegraph -> falling -> impact -> landed for hazards;
/// telegraph -> active -> expired for updrafts).
///
/// Fairness is enforced structurally rather than by ad-hoc checks:
///  * A target row (or row range, for updrafts) is only ever picked far
///    enough ahead of the player (measured from the player's exact,
///    non-floored world position) that its telegraph (+ fall, for hazards)
///    always completes before the player can physically reach it at the
///    current rise speed.
///  * That look-ahead is measured against the fastest the player could
///    possibly climb the stretch, not just [riseSpeed]: riding an updraft is
///    several times faster, so both spawn paths price in the time a column
///    between the player and the target row could save them. Hazards are also
///    placed against the longest telegraph they might end up using, since
///    whether a meteor homes is only decided after the row is picked. Without
///    either correction a hazard can still be in the air when the player
///    arrives, and then it falls *through* them on its way down.
///  * Any two simultaneously active (non-expired/non-landed) pieces of
///    content - hazard or updraft, in either combination - must keep at
///    least [GameConfig.minHazardRowGap] (or [GameConfig.updraftSafetyMarginRows]
///    for updrafts) rows of clearance between them, regardless of lane. For
///    hazards alone this rules out two hazards being genuinely dangerous on
///    opposite lanes at the same moment. For updrafts it additionally
///    guarantees a boosted player can never be carried into, or land right
///    next to, a falling hazard without a normal reaction window.
class SpawnDirector {
  SpawnDirector(this._random, this._world, this._vfx)
      : _pool = ObjectPool<FallingObject>(FallingObject.new),
        _updraftPool = ObjectPool<Updraft>(Updraft.new),
        _pickupPool = ObjectPool<Pickup>(Pickup.new);

  final Random _random;
  final World _world;
  final VfxManager _vfx;
  final ObjectPool<FallingObject> _pool;
  final ObjectPool<Updraft> _updraftPool;
  final ObjectPool<Pickup> _pickupPool;

  final List<FallingObject> active = <FallingObject>[];
  final List<Updraft> updrafts = <Updraft>[];
  final List<Pickup> pickups = <Pickup>[];

  double _timeUntilNextSpawn = 1.4;
  double _timeUntilNextUpdraft = 30;
  int _nextPickupRow = 6;

  void reset() {
    for (final obj in active) {
      _pool.release(obj);
    }
    active.clear();
    for (final u in updrafts) {
      _updraftPool.release(u);
    }
    updrafts.clear();
    for (final p in pickups) {
      _pickupPool.release(p);
    }
    pickups.clear();
    _timeUntilNextSpawn = 2.2;
    _timeUntilNextUpdraft = _randomRange(
      GameConfig.firstUpdraftMinSeconds,
      GameConfig.firstUpdraftMaxSeconds,
    );
    _nextPickupRow = 6;
  }

  /// True if [fromRow]..[toRow] (inclusive) is clear of every other active
  /// hazard and updraft, honoring both fairness margins. Used both when
  /// placing a new single-row hazard ([fromRow] == [toRow]) and a new
  /// multi-row updraft span.
  bool _rangeIsClear(int fromRow, int toRow) {
    final bool hazardConflict = active.any(
      (o) =>
          o.phase != FallingPhase.landed &&
          o.targetRow >= fromRow - GameConfig.minHazardRowGap &&
          o.targetRow <= toRow + GameConfig.minHazardRowGap,
    );
    if (hazardConflict) return false;

    final bool updraftConflict = updrafts.any(
      (u) =>
          u.phase != UpdraftPhase.expired &&
          fromRow <= u.topRow + GameConfig.updraftSafetyMarginRows &&
          toRow >= u.bottomRow - GameConfig.updraftSafetyMarginRows,
    );
    return !updraftConflict;
  }

  double _difficultyOf(double heightMeters) =>
      (heightMeters / GameConfig.difficultyRampMeters).clamp(0.0, 1.0).toDouble();

  /// Seconds saved by riding the stretch of an updraft column that lies
  /// between [fromWorldY] and [toWorldY], compared to climbing the same
  /// stretch at [riseSpeed].
  ///
  /// Both spawn paths have to account for this. The boost is several times
  /// the normal climb speed, so a player who rides a column reaches
  /// everything above it much earlier than the plain-speed arithmetic
  /// assumes - which is exactly how a hazard scheduled against the normal
  /// speed can end up landing on top of them.
  static double _savingAcross({
    required double spanBottom,
    required double spanTop,
    required double fromWorldY,
    required double toWorldY,
    required double riseSpeed,
  }) {
    final double from = max(spanBottom, fromWorldY);
    final double to = min(spanTop, toWorldY);
    if (to <= from) return 0;
    final double boosted = riseSpeed + GameConfig.updraftBoostSpeedBonus;
    return (to - from) * (1 / riseSpeed - 1 / boosted);
  }

  /// Worst-case [_savingAcross] over every column the player could still
  /// ride on their way up.
  double _updraftTimeSaving({
    required double playerWorldY,
    required double toWorldY,
    required double riseSpeed,
  }) {
    double saving = 0;
    for (final u in updrafts) {
      if (u.phase == UpdraftPhase.expired) continue;
      saving += _savingAcross(
        spanBottom: u.bottomWorldY,
        spanTop: u.topWorldY,
        fromWorldY: playerWorldY,
        toWorldY: toWorldY,
        riseSpeed: riseSpeed,
      );
    }
    return saving;
  }

  /// Seconds left before [obj] is resolved into solid ground and stops being
  /// lethal.
  static double _timeUntilLanded(FallingObject obj) {
    switch (obj.phase) {
      case FallingPhase.telegraph:
        return (obj.telegraphDuration - obj.phaseTime) + obj.fallDuration;
      case FallingPhase.falling:
        return obj.fallDuration - obj.phaseTime;
      case FallingPhase.impact:
      case FallingPhase.landed:
        return 0;
    }
  }

  /// True if a player standing in [lane] at [worldY] is currently inside an
  /// active updraft and should be boosted / immune to ground danger.
  bool isBoosting(Lane lane, double worldY) => updrafts.any(
        (u) =>
            u.phase == UpdraftPhase.active &&
            u.lane == lane &&
            worldY >= u.bottomWorldY &&
            worldY <= u.topWorldY,
      );

  /// Advances spawning + all active objects. Returns nothing; collision
  /// checks are read by the caller from [active] afterwards.
  void update({
    required double dt,
    required double playerWorldY,
    required double riseSpeed,
    required double heightMeters,
    required double viewportHeight,
    Lane? playerLane,
  }) {
    final double difficulty = _difficultyOf(heightMeters);

    _updateActiveObjects(dt, playerLane);
    _updateUpdrafts(dt);

    _timeUntilNextSpawn -= dt;
    if (_timeUntilNextSpawn <= 0 &&
        active.length < GameConfig.maxActiveFallingObjects) {
      _trySpawn(
        playerWorldY: playerWorldY,
        riseSpeed: riseSpeed,
        difficulty: difficulty,
        viewportHeight: viewportHeight,
      );
      final double interval = lerpDouble(
        GameConfig.maxSpawnInterval,
        GameConfig.minSpawnInterval,
        difficulty,
      )!;
      _timeUntilNextSpawn = interval * (0.85 + _random.nextDouble() * 0.3);
    }

    _timeUntilNextUpdraft -= dt;
    if (_timeUntilNextUpdraft <= 0 &&
        updrafts.length < GameConfig.maxActiveUpdrafts) {
      _trySpawnUpdraft(playerWorldY: playerWorldY, riseSpeed: riseSpeed);
      _timeUntilNextUpdraft = _randomRange(
        GameConfig.updraftMinIntervalSeconds,
        GameConfig.updraftMaxIntervalSeconds,
      );
    }

    for (final p in pickups) {
      p.age += dt;
    }
    // Recycle pickups the player has long since passed without collecting,
    // so the list never grows unbounded over a long run.
    pickups.removeWhere((p) {
      if (playerWorldY - p.worldY < viewportHeight * 1.5) return false;
      p.active = false;
      _pickupPool.release(p);
      return true;
    });

    _updatePickupSpawning(playerWorldY);
  }

  void _updateActiveObjects(double dt, Lane? playerLane) {
    final List<FallingObject> toRetire = <FallingObject>[];
    for (final obj in active) {
      switch (obj.phase) {
        case FallingPhase.telegraph:
          obj.phaseTime += dt;
          // Homing meteor tracks the player's lane while its telegraph is
          // still burning, and locks onto whichever lane they are in at the
          // moment it drops. Only ever considered when a [playerLane] is
          // supplied (i.e. the run is actually being played, not previewed).
          if (obj.isHoming && playerLane != null && obj.lane != playerLane) {
            obj.lane = playerLane;
          }
          if (obj.phaseTime >= obj.telegraphDuration) {
            if (obj.isHoming && playerLane != null) {
              obj.lane = playerLane;
            }
            obj.phase = FallingPhase.falling;
            obj.phaseTime = 0;
            obj.currentWorldY = obj.fallStartWorldY;
          }
          break;
        case FallingPhase.falling:
          obj.phaseTime += dt;
          final double t =
              (obj.phaseTime / obj.fallDuration).clamp(0.0, 1.0).toDouble();
          obj.currentWorldY =
              lerpDouble(obj.fallStartWorldY, obj.targetWorldY, t)!;
          if (t >= 1) {
            obj.phase = FallingPhase.impact;
            obj.phaseTime = 0;
            obj.currentWorldY = obj.targetWorldY;
            _world.markPlatform(obj.targetRow, obj.lane, obj.type);
            _vfx.spawnImpact(
              lane: obj.lane,
              worldY: obj.targetWorldY,
              type: obj.type,
            );
          }
          break;
        case FallingPhase.impact:
          obj.phaseTime += dt;
          if (obj.phaseTime >= GameConfig.impactDuration) {
            obj.phase = FallingPhase.landed;
            obj.phaseTime = 0;
          }
          break;
        case FallingPhase.landed:
          obj.phaseTime += dt;
          if (obj.phaseTime >= GameConfig.landedFlashDuration) {
            toRetire.add(obj);
          }
          break;
      }
    }
    for (final obj in toRetire) {
      active.remove(obj);
      obj.active = false;
      _pool.release(obj);
    }
  }

  void _updateUpdrafts(double dt) {
    final List<Updraft> toRetire = <Updraft>[];
    for (final u in updrafts) {
      switch (u.phase) {
        case UpdraftPhase.telegraph:
          u.phaseTime += dt;
          if (u.phaseTime >= u.telegraphDuration) {
            u.phase = UpdraftPhase.active;
            u.phaseTime = 0;
          }
          break;
        case UpdraftPhase.active:
          u.phaseTime += dt;
          if (u.phaseTime >= u.activeDuration) {
            u.phase = UpdraftPhase.expired;
            u.phaseTime = 0;
          }
          break;
        case UpdraftPhase.expired:
          u.phaseTime += dt;
          if (u.phaseTime >= GameConfig.updraftFadeDuration) {
            toRetire.add(u);
          }
          break;
      }
    }
    for (final u in toRetire) {
      updrafts.remove(u);
      u.active = false;
      _updraftPool.release(u);
    }
  }

  /// True if a column spanning [spanBottom]..[spanTop] still leaves every
  /// hazard currently in the air enough time to land before the (now faster)
  /// player can reach its target row.
  bool _spanKeepsHazardsFair({
    required double spanBottom,
    required double spanTop,
    required double playerWorldY,
    required double riseSpeed,
  }) {
    for (final obj in active) {
      if (obj.phase == FallingPhase.landed) continue;
      final double saving = _savingAcross(
        spanBottom: spanBottom,
        spanTop: spanTop,
        fromWorldY: playerWorldY,
        toWorldY: obj.targetWorldY,
        riseSpeed: riseSpeed,
      );
      if (saving <= 0) continue;
      final double arrivesIn =
          (obj.targetWorldY - playerWorldY) / riseSpeed - saving;
      if (arrivesIn <
          _timeUntilLanded(obj) + GameConfig.spawnSafetyBufferSeconds) {
        return false;
      }
    }
    return true;
  }

  void _trySpawnUpdraft({
    required double playerWorldY,
    required double riseSpeed,
  }) {
    final double telegraphDuration = _randomRange(
      GameConfig.updraftTelegraphMin,
      GameConfig.updraftTelegraphMax,
    );

    // Same style of guarantee as hazards: the column must already be fully
    // active well before the player's exact world position reaches it.
    final double safeLeadSeconds = max(
      telegraphDuration + GameConfig.spawnSafetyBufferSeconds,
      GameConfig.absoluteMinReactionSeconds,
    );
    final double minBottomWorldY = playerWorldY +
        safeLeadSeconds * riseSpeed +
        GameConfig.segmentHeight;
    final int minBottomRow =
        (minBottomWorldY / GameConfig.segmentHeight).ceil();

    for (int offset = 0; offset < 10; offset++) {
      final int bottomRow = minBottomRow + offset;
      final int topRow = bottomRow + GameConfig.updraftSpanRows - 1;
      if (!_rangeIsClear(bottomRow, topRow)) continue;

      final double bottomWorldY = World.worldYForRow(bottomRow);
      final double topWorldY = World.worldYForRow(topRow + 1);
      // The row-clearance rule above only spaces the column away from
      // hazards; this covers the other dimension. Riding the column speeds
      // the player up, so a hazard further above - however many rows away -
      // could otherwise still be in the air when they arrive.
      if (!_spanKeepsHazardsFair(
        spanBottom: bottomWorldY,
        spanTop: topWorldY,
        playerWorldY: playerWorldY,
        riseSpeed: riseSpeed,
      )) {
        continue;
      }

      final Lane lane = _random.nextBool() ? Lane.left : Lane.right;

      final Updraft u = _updraftPool.acquire();
      u.reset(
        lane: lane,
        bottomRow: bottomRow,
        topRow: topRow,
        bottomWorldY: bottomWorldY,
        topWorldY: topWorldY,
        telegraphDuration: telegraphDuration,
        activeDuration: GameConfig.updraftActiveDuration,
      );
      updrafts.add(u);
      return;
    }
    // No clear span found this cycle; the next scheduled attempt will retry.
  }

  void _trySpawn({
    required double playerWorldY,
    required double riseSpeed,
    required double difficulty,
    required double viewportHeight,
  }) {
    final bool preferMeteor = _random.nextDouble() < 0.34 + difficulty * 0.3;
    final FallingObjectType type =
        preferMeteor ? FallingObjectType.meteor : FallingObjectType.rockfall;

    final double telegraphDuration = _randomRange(
      type == FallingObjectType.rockfall
          ? GameConfig.rockfallTelegraphMin
          : GameConfig.meteorTelegraphMin,
      type == FallingObjectType.rockfall
          ? GameConfig.rockfallTelegraphMax
          : GameConfig.meteorTelegraphMax,
    );

    final double fallSpeedMultiplier = lerpDouble(
      GameConfig.minFallSpeedMultiplier,
      GameConfig.maxFallSpeedMultiplier,
      difficulty,
    )!;
    final double baseFallDuration = type == FallingObjectType.rockfall
        ? GameConfig.rockfallFallDuration
        : GameConfig.meteorFallDuration;
    final double fallDuration = baseFallDuration / fallSpeedMultiplier;

    // Placement has to budget for the *longest* telegraph this object might
    // end up using, not the one rolled above: whether a meteor turns out to
    // be homing is only decided once a candidate row is known, and a homing
    // meteor burns [homingMeteorExtraTelegraph] longer before it drops. Budget
    // for the short telegraph and a homing meteor lands after the player has
    // already climbed past its target row, sweeping down through them.
    final double worstTelegraph = telegraphDuration +
        (type == FallingObjectType.meteor
            ? GameConfig.homingMeteorExtraTelegraph
            : 0);

    final double leadSeconds = worstTelegraph +
        fallDuration +
        GameConfig.spawnSafetyBufferSeconds +
        // An updraft the player has not passed yet can carry them upwards
        // several times faster than [riseSpeed], so the row has to be placed
        // as if they ride every column on the way.
        _updraftTimeSaving(
          playerWorldY: playerWorldY,
          toWorldY: double.infinity,
          riseSpeed: riseSpeed,
        );
    // Never let the effective reaction window collapse below the absolute
    // floor mandated by the fairness rules, regardless of speed swings.
    final double safeLeadSeconds =
        max(leadSeconds, GameConfig.absoluteMinReactionSeconds + fallDuration);

    // Measured from the player's exact world position (not the floored
    // row index) plus one full extra segment of margin, so the up-to-one-
    // segment rounding slop of `floor(worldY / segmentHeight)` can never
    // eat into the guaranteed reaction time.
    final double minTargetWorldY = playerWorldY +
        safeLeadSeconds * riseSpeed +
        GameConfig.segmentHeight;
    final int minTargetRow =
        (minTargetWorldY / GameConfig.segmentHeight).ceil();

    // The window has to be wide enough to still find a slot when the maximum
    // number of hazards is already in flight, each holding
    // [GameConfig.minHazardRowGap] rows of clearance around it - otherwise the
    // extra hazard slots would silently never be used.
    for (int offset = 0; offset < 14; offset++) {
      final int candidateRow = minTargetRow + offset;
      if (!_rangeIsClear(candidateRow, candidateRow)) continue;
      final Segment? segment = _world.segmentAt(candidateRow);
      if (segment == null) continue;

      Lane lane;
      bool bothLanesSafe = false;
      if (segment.left == LaneState.danger) {
        lane = Lane.left;
      } else if (segment.right == LaneState.danger) {
        lane = Lane.right;
      } else if (segment.left == LaneState.safe &&
          segment.right == LaneState.safe) {
        lane = _random.nextBool() ? Lane.left : Lane.right;
        bothLanesSafe = true;
      } else {
        // Row already resolved (e.g. platform) or in an unexpected state;
        // try the next candidate instead of forcing an unfair spawn.
        continue;
      }

      // A homing meteor is only fair when the target row has both lanes safe:
      // otherwise the player would have to jump into lava to dodge it.
      final double homingChance = lerpDouble(
        GameConfig.homingMeteorBaseChance,
        GameConfig.homingMeteorMaxChance,
        difficulty,
      )!;
      final bool isHoming = type == FallingObjectType.meteor &&
          bothLanesSafe &&
          _random.nextDouble() < homingChance;
      final double effectiveTelegraph = isHoming
          ? telegraphDuration + GameConfig.homingMeteorExtraTelegraph
          : telegraphDuration;

      final double targetWorldY = World.worldYForRow(candidateRow);
      final double fallStartWorldY = targetWorldY + viewportHeight * 0.95;

      final FallingObject obj = _pool.acquire();
      obj.reset(
        type: type,
        lane: lane,
        targetRow: candidateRow,
        telegraphDuration: effectiveTelegraph,
        fallDuration: fallDuration,
        fallStartWorldY: fallStartWorldY,
        targetWorldY: targetWorldY,
        spriteVariant: _random.nextInt(1 << 16),
        isHoming: isHoming,
      );
      active.add(obj);
      return;
    }
    // No fair candidate row found this cycle; simply skip the spawn and
    // let the next interval try again rather than forcing an unsafe one.
  }

  // --- Pickups (Embers currency) ------------------------------------------

  /// True if [row] is within the mandatory clearance distance of any
  /// active (non-landed) falling hazard - pickups must never nudge the
  /// player towards danger, so they simply skip these rows.
  bool _rowNearActiveHazard(int row) => active.any(
        (o) =>
            o.phase != FallingPhase.landed &&
            (o.targetRow - row).abs() <= GameConfig.pickupHazardClearanceRows,
      );

  void _updatePickupSpawning(double playerWorldY) {
    if (pickups.length >= GameConfig.maxActivePickups) return;
    // Only ever look at rows the world has already generated (and thus
    // already knows the lane states for), well ahead of the player so the
    // pickup is visible before it's reached rather than popping in.
    final int playerRow = (playerWorldY / GameConfig.segmentHeight).floor();
    if (_nextPickupRow > _world.highestGeneratedRow) return;
    if (_nextPickupRow < playerRow) {
      // The player skipped past without us placing one (e.g. right after a
      // restart); just re-target ahead instead of ever spawning behind.
      _nextPickupRow = playerRow +
          _randomRange(GameConfig.pickupMinRowGap, GameConfig.pickupMaxRowGap)
              .round();
      return;
    }

    final int row = _nextPickupRow;
    _nextPickupRow += _randomRange(
      GameConfig.pickupMinRowGap,
      GameConfig.pickupMaxRowGap,
    ).round();

    if (_rowNearActiveHazard(row)) return; // skip this slot, try the next
    final Segment? segment = _world.segmentAt(row);
    if (segment == null) return;

    // Only ever placed on a lane that is plainly safe (or an already
    // resolved platform) right now - never on magma/chasm, per the brief.
    final List<Lane> safeLanes = <Lane>[
      for (final lane in Lane.values)
        if (segment.stateOf(lane) == LaneState.safe ||
            segment.stateOf(lane) == LaneState.platform)
          lane,
    ];
    if (safeLanes.isEmpty) return;
    final Lane lane = safeLanes[_random.nextInt(safeLanes.length)];

    final PickupType type = _rollPickupType();
    final List<ItemCoord> spriteOptions = type.spriteOptions;
    final ItemCoord sprite = spriteOptions[_random.nextInt(spriteOptions.length)];

    final Pickup pickup = _pickupPool.acquire();
    pickup.reset(
      type: type,
      lane: lane,
      row: row,
      worldY: row * GameConfig.segmentHeight + GameConfig.segmentHeight * 0.5,
      sprite: sprite,
      bobPhase: _random.nextDouble() * pi * 2,
    );
    pickups.add(pickup);
  }

  PickupType _rollPickupType() {
    final double total = PickupType.values
        .fold(0.0, (sum, t) => sum + t.spawnWeight);
    double roll = _random.nextDouble() * total;
    for (final type in PickupType.values) {
      roll -= type.spawnWeight;
      if (roll <= 0) return type;
    }
    return PickupType.shard;
  }

  /// Removes and returns the pickup at [lane]/[worldY] if the player is
  /// close enough to collect it, or null otherwise. The caller
  /// ([GameController]) is responsible for turning this into Embers, a
  /// floating "+N" and a collect blip.
  ///
  /// [radiusBonus] widens the reach by that fraction of a segment's height,
  /// which is how the Magnet upgrade is applied.
  Pickup? tryCollectAt(Lane lane, double worldY, {double radiusBonus = 0}) {
    final double reach = GameConfig.segmentHeight * (0.5 + radiusBonus);
    for (final pickup in pickups) {
      if (pickup.lane != lane) continue;
      if ((pickup.worldY - worldY).abs() > reach) {
        continue;
      }
      pickups.remove(pickup);
      pickup.active = false;
      _pickupPool.release(pickup);
      return pickup;
    }
    return null;
  }

  double _randomRange(double min, double max) =>
      min + _random.nextDouble() * (max - min);
}
