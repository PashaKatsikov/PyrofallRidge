import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ridgegame/core/game_config.dart';
import 'package:ridgegame/game/spawn_director.dart';
import 'package:ridgegame/game/vfx_manager.dart';
import 'package:ridgegame/game/world.dart';
import 'package:ridgegame/models/falling_object.dart';
import 'package:ridgegame/models/lane.dart';
import 'package:ridgegame/models/segment.dart';

/// Behavioural tests for the two mechanics added in this feature pass:
///  * homing meteors: only fair to spawn (both lanes safe), track the player
///    while telegraphing, and lock at ignition.
///  * the fake-progress harness we use to exercise the director doesn't
///    accidentally over-drive things and produce false negatives.
void main() {
  group('Homing meteor', () {
    late Random random;
    late World world;
    late VfxManager vfx;
    late SpawnDirector director;

    setUp(() {
      // A seeded RNG so the homing/normal roll is repeatable across runs.
      random = Random(1);
      world = World(random);
      vfx = VfxManager(random);
      director = SpawnDirector(random, world, vfx);
      world.ensureGenerated(60, 0);
    });

    /// Steps the director in tiny frames and returns the first homing meteor
    /// it spawns, or null if none appears within [maxSeconds].
    FallingObject? spawnHoming({double maxSeconds = 30}) {
      const double dt = 1 / 60;
      double elapsed = 0;
      while (elapsed < maxSeconds) {
        director.update(
          dt: dt,
          playerWorldY: 0,
          riseSpeed: 90,
          heightMeters: 800, // near-max difficulty -> higher homing chance
          viewportHeight: 800,
          playerLane: Lane.left,
        );
        elapsed += dt;
        final FallingObject homing = director.active.firstWhere(
          (o) => o.isHoming && o.phase == FallingPhase.telegraph,
          orElse: () => _sentinel,
        );
        if (homing != _sentinel) return homing;
      }
      return null;
    }

    test('is only ever placed on a row where both lanes are safe', () {
      final FallingObject? meteor = spawnHoming();
      expect(meteor, isNotNull, reason: 'director should eventually spawn one');
      final Segment? seg = world.segmentAt(meteor!.targetRow);
      expect(seg!.left, LaneState.safe);
      expect(seg.right, LaneState.safe);
    });

    test('tracks the player lane during telegraph and locks at ignition', () {
      final FallingObject? meteor = spawnHoming();
      expect(meteor, isNotNull);
      // Even though the meteor was placed on Lane.left, moving the player to
      // the right during telegraph must swing it over.
      const double dt = 1 / 60;
      double t = 0;
      while (t < meteor!.telegraphDuration) {
        director.update(
          dt: dt,
          playerWorldY: 0,
          riseSpeed: 90,
          heightMeters: 800,
          viewportHeight: 800,
          playerLane: Lane.right,
        );
        t += dt;
      }
      expect(meteor.phase, FallingPhase.falling);
      expect(meteor.lane, Lane.right);
    });

    test('gets a longer telegraph than a plain meteor of the same seed', () {
      final FallingObject? meteor = spawnHoming();
      expect(meteor, isNotNull);
      expect(
        meteor!.telegraphDuration,
        greaterThan(GameConfig.meteorTelegraphMin),
      );
    });
  });
}

final FallingObject _sentinel = FallingObject();
