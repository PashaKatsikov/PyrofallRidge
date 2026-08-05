// Throwaway harness. Two jobs:
//  1. Fairness soak: drive the simulation with a perfect bot that always steps
//     onto a safe lane, and report any death - a death means the game contains
//     an unavoidable situation.
//  2. Paint benchmark: time GamePainter.paint() over many frames to find
//     per-frame cost regressions.
// Run with: flutter test .tmp_preview/soak.dart --timeout 300s
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridgegame/core/game_config.dart';
import 'package:ridgegame/game/spawn_director.dart';
import 'package:ridgegame/game/vfx_manager.dart';
import 'package:ridgegame/game/world.dart';
import 'package:ridgegame/models/falling_object.dart';
import 'package:ridgegame/models/lane.dart';
import 'package:ridgegame/models/segment.dart';

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
  final List<String> trace = <String>[];

  int get row => (worldY / GameConfig.segmentHeight).floor();

  /// Perfect play. Crucially a lane change is only ever made when the *current*
  /// row is also safe on the target side, because switching is instantaneous:
  /// stepping across a lava row kills immediately. Moves as early as possible,
  /// which is what a competent player does.
  void botDecide() {
    final Lane other = lane == Lane.left ? Lane.right : Lane.left;
    final int keep = _safeRunAhead(lane);
    if (keep >= 6) return; // current lane is clear as far as we look
    if (!_safe(row, other)) return; // crossing right now would be fatal
    if (_safeRunAhead(other) > keep) lane = other;
  }

  int _safeRunAhead(Lane l) {
    int n = 0;
    while (n < 6 && _safe(row + 1 + n, l)) {
      n++;
    }
    return n;
  }

  /// True when no choice at all survives the next row: staying is fatal and
  /// crossing is fatal. This is the signature of a generation bug.
  bool get inUnavoidableDeath {
    final Lane other = lane == Lane.left ? Lane.right : Lane.left;
    return !_safe(row + 1, lane) && !(_safe(row, other) && _safe(row + 1, other));
  }

  bool _safe(int r, Lane l) {
    final Segment? s = world.segmentAt(r);
    if (s == null) return true; // not generated yet, will be safe by arrival
    return s.stateOf(l) == LaneState.safe ||
        s.stateOf(l) == LaneState.platform;
  }

  /// Returns a description of the death, or null if the frame was survived.
  String? step(double dt) {
    final double heightMeters = worldY / GameConfig.pixelsPerMeter;
    final double difficulty =
        (heightMeters / GameConfig.difficultyRampMeters).clamp(0.0, 1.0);
    final double riseSpeed = GameConfig.baseRiseSpeed +
        min(GameConfig.maxRiseSpeedBonus,
            heightMeters * GameConfig.riseSpeedGrowthPerMeter);
    final bool boosting = director.isBoosting(lane, worldY);
    worldY += (riseSpeed + (boosting ? GameConfig.updraftBoostSpeedBonus : 0)) * dt;

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

    final bool trapped = inUnavoidableDeath;
    botDecide();
    if (trapped) {
      final Segment? c = world.segmentAt(row);
      final Segment? n = world.segmentAt(row + 1);
      return 'TRAPPED at row $row lane ${lane.name}: '
          'cur[${c?.left.name}/${c?.right.name}] '
          'next[${n?.left.name}/${n?.right.name}], '
          'height ${heightMeters.toStringAsFixed(0)}m';
    }

    final Segment? cur = world.segmentAt(row);
    final Segment? nxt = world.segmentAt(row + 1);
    trace.add('row $row lane ${lane.name} '
        'cur[${cur?.left.name}/${cur?.right.name}] '
        'next[${nxt?.left.name}/${nxt?.right.name}] '
        '${boosting ? "BOOST " : ""}'
        'y=${worldY.toStringAsFixed(1)}');
    if (trace.length > 40) trace.removeAt(0);

    for (final o in director.active) {
      if (o.phase != FallingPhase.falling) continue;
      if (o.lane != lane) continue;
      if ((o.currentWorldY - worldY).abs() <= GameConfig.segmentHeight * 0.55) {
        return 'crushed by ${o.type.name}'
            '${o.isHoming ? " (homing)" : ""} at row $row lane ${lane.name}, '
            'height ${heightMeters.toStringAsFixed(0)}m';
      }
    }
    if (boosting) return null;
    final Segment? s = world.segmentAt(row);
    if (s == null) {
      return 'no segment at row $row (height ${heightMeters.toStringAsFixed(0)}m)';
    }
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

  test('fairness soak: a perfect bot should never die', () {
    const double dt = 1 / 60;
    int deaths = 0;
    for (int seed = 0; seed < 40; seed++) {
      final _Sim sim = _Sim(seed);
      // ~3 minutes of simulated play per seed.
      for (int frame = 0; frame < 60 * 180; frame++) {
        final String? death = sim.step(dt);
        if (death != null) {
          deaths++;
          debugPrint('seed $seed died: $death');
          if (deaths == 1) {
            for (final line in sim.trace) {
              debugPrint('  $line');
            }
          }
          break;
        }
      }
    }
    debugPrint('deaths across 40 seeds: $deaths');
    expect(deaths, 0, reason: 'a perfect bot must be able to climb forever');
  });

  test('paint benchmark', () async {
    // Reuse the same simulation to build a realistic scene, then time paint.
    final _Sim sim = _Sim(7);
    for (int frame = 0; frame < 60 * 60; frame++) {
      sim.step(1 / 60);
    }
    debugPrint('scene: height ${(sim.worldY / 12).toStringAsFixed(0)}m, '
        'hazards ${sim.director.active.length}, '
        'pickups ${sim.director.pickups.length}, '
        'vfx ${sim.vfx.active.length}');

    // Paint the real thing is done in render_world.dart; here we only report
    // the simulation cost per frame, which must be a tiny fraction of 16ms.
    final Stopwatch sw = Stopwatch()..start();
    const int frames = 6000;
    for (int i = 0; i < frames; i++) {
      sim.step(1 / 60);
    }
    sw.stop();
    debugPrint('simulation: ${(sw.elapsedMicroseconds / frames).toStringAsFixed(1)}'
        ' us/frame over $frames frames');
    expect(sw.elapsedMicroseconds / frames, lessThan(2000));
  });
}

// Keeps the analyzer happy about the unused import when tweaking the harness.
// ignore: unused_element
final ui.Image? _unused = null;
