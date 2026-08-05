// Throwaway harness: like soak.dart, but the bot deliberately rides every
// updraft it can reach. Riding a column is the one thing that lets the player
// arrive somewhere earlier than the plain climb speed predicts, so this is the
// case that actually stresses the hazard-scheduling guarantees.
// Run with: flutter test .tmp_preview/updraft_soak.dart --timeout 900s
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridgegame/core/game_config.dart';
import 'package:ridgegame/game/spawn_director.dart';
import 'package:ridgegame/game/vfx_manager.dart';
import 'package:ridgegame/game/world.dart';
import 'package:ridgegame/models/falling_object.dart';
import 'package:ridgegame/models/lane.dart';
import 'package:ridgegame/models/segment.dart';
import 'package:ridgegame/models/updraft.dart';

class _Sim {
  _Sim(int seed)
      : random = Random(seed),
        world = World(Random(seed)) {
    vfx = VfxManager(random);
    director = SpawnDirector(random, world, vfx);
  }

  final Random random;
  final World world;
  late final VfxManager vfx;
  late final SpawnDirector director;

  double worldY = 0;
  Lane lane = Lane.left;
  double viewportHeight = 844;
  int boostFrames = 0;
  int ridesTaken = 0;
  bool _wasBoosting = false;

  int get row => (worldY / GameConfig.segmentHeight).floor();

  bool _safe(int r, Lane l) {
    final Segment? s = world.segmentAt(r);
    if (s == null) return true;
    return s.stateOf(l) == LaneState.safe || s.stateOf(l) == LaneState.platform;
  }

  int _safeRunAhead(Lane l) {
    int n = 0;
    while (n < 6 && _safe(row + 1 + n, l)) {
      n++;
    }
    return n;
  }

  /// True if switching to [l] right now is not immediately fatal.
  bool _canCrossTo(Lane l) => _safe(row, l) && _safe(row + 1, l);

  /// A column the player could still ride, if any is close enough above.
  Updraft? _reachableColumn() {
    Updraft? best;
    for (final u in director.updrafts) {
      if (u.phase == UpdraftPhase.expired) continue;
      if (u.topWorldY <= worldY) continue;
      final double rowsAway =
          (u.bottomWorldY - worldY) / GameConfig.segmentHeight;
      if (rowsAway > 8) continue;
      if (best == null || u.bottomWorldY < best.bottomWorldY) best = u;
    }
    return best;
  }

  void botDecide() {
    final Lane other = lane == Lane.left ? Lane.right : Lane.left;
    // Survival always wins: if staying is fatal, cross while it is still legal.
    if (!_safe(row + 1, lane)) {
      if (_canCrossTo(other)) lane = other;
      return;
    }
    // Otherwise chase the nearest column, but only if the whole way there is
    // safe in that lane.
    final Updraft? column = _reachableColumn();
    if (column != null && column.lane != lane && _canCrossTo(column.lane)) {
      final int rowsToClimb =
          ((column.bottomWorldY - worldY) / GameConfig.segmentHeight).ceil();
      bool clear = true;
      for (int i = 0; i <= rowsToClimb + GameConfig.updraftSpanRows; i++) {
        if (!_safe(row + i, column.lane)) {
          clear = false;
          break;
        }
      }
      if (clear) {
        lane = column.lane;
        return;
      }
    }
    final int keep = _safeRunAhead(lane);
    if (keep >= 6) return;
    if (!_canCrossTo(other)) return;
    if (_safeRunAhead(other) > keep) lane = other;
  }

  String? step(double dt) {
    final double heightMeters = worldY / GameConfig.pixelsPerMeter;
    final double difficulty =
        (heightMeters / GameConfig.difficultyRampMeters).clamp(0.0, 1.0);
    final double riseSpeed = GameConfig.baseRiseSpeed +
        min(GameConfig.maxRiseSpeedBonus,
            heightMeters * GameConfig.riseSpeedGrowthPerMeter);
    final bool boosting = director.isBoosting(lane, worldY);
    if (boosting) {
      boostFrames++;
      if (!_wasBoosting) ridesTaken++;
    }
    _wasBoosting = boosting;
    worldY +=
        (riseSpeed + (boosting ? GameConfig.updraftBoostSpeedBonus : 0)) * dt;

    world.ensureGenerated(
      row + GameConfig.lookAheadSegments,
      GameConfig.minDangerChance +
          (GameConfig.maxDangerChance - GameConfig.minDangerChance) * difficulty,
    );
    world.cleanup(worldY - viewportHeight * 0.34);
    world.updateGlow(dt);
    director.update(
      dt: dt,
      playerWorldY: worldY,
      riseSpeed: riseSpeed,
      heightMeters: heightMeters,
      viewportHeight: viewportHeight,
      playerLane: lane,
    );
    vfx.update(dt: dt, playerWorldY: worldY, viewportHeight: viewportHeight);
    botDecide();

    for (final o in director.active) {
      if (o.phase != FallingPhase.falling) continue;
      if (o.lane != lane) continue;
      if ((o.currentWorldY - worldY).abs() <= GameConfig.segmentHeight * 0.55) {
        return 'crushed by ${o.type.name}${o.isHoming ? " (homing)" : ""} '
            'at row $row lane ${lane.name}, '
            'target row ${o.targetRow}, '
            'objY ${o.currentWorldY.toStringAsFixed(0)} vs '
            'playerY ${worldY.toStringAsFixed(0)}, '
            '${boosting ? "WHILE BOOSTING, " : ""}'
            'height ${heightMeters.toStringAsFixed(0)}m';
      }
    }
    if (boosting) return null;
    final Segment? s = world.segmentAt(row);
    if (s == null) return 'no segment at row $row';
    final LaneState st = s.stateOf(lane);
    if (st != LaneState.safe && st != LaneState.platform) {
      final Lane other = lane == Lane.left ? Lane.right : Lane.left;
      return 'stood in ${st.name} at row $row lane ${lane.name} '
          '(other lane: ${s.stateOf(other).name}), '
          'height ${heightMeters.toStringAsFixed(0)}m';
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('updraft-riding bot should never die', () {
    const double dt = 1 / 60;
    const int seeds = 120;
    int deaths = 0;
    int rides = 0;
    double totalHeight = 0;
    for (int seed = 0; seed < seeds; seed++) {
      final _Sim sim = _Sim(seed);
      for (int frame = 0; frame < 60 * 240; frame++) {
        final String? death = sim.step(dt);
        if (death != null) {
          deaths++;
          debugPrint('seed $seed died: $death');
          break;
        }
      }
      rides += sim.ridesTaken;
      totalHeight += sim.worldY / GameConfig.pixelsPerMeter;
    }
    debugPrint('deaths: $deaths / $seeds seeds, '
        'updraft rides taken: $rides, '
        'avg height reached ${(totalHeight / seeds).toStringAsFixed(0)}m');
    expect(deaths, 0);
  });
}
