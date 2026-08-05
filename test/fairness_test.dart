import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ridgegame/core/game_config.dart';
import 'package:ridgegame/game/spawn_director.dart';
import 'package:ridgegame/game/vfx_manager.dart';
import 'package:ridgegame/game/world.dart';
import 'package:ridgegame/models/falling_object.dart';
import 'package:ridgegame/models/lane.dart';
import 'package:ridgegame/models/segment.dart';

/// The climb has to stay survivable for a player who reads the ridge perfectly.
///
/// The interesting failure this guards against: two consecutive rows holding
/// danger on *opposite* lanes. Standing still walks into the danger one row up,
/// and stepping across walks into the danger on the row currently underfoot -
/// so the run ends no matter what the player does. It shipped once, is
/// invisible in a short play session, and only bites a few hundred metres in.
void main() {
  group('world generation fairness', () {
    /// Walks the generated ridge and returns a description of the first row a
    /// perfectly-playing climber could not get past, or null if there is none.
    String? findTrap(int seed, {int rows = 4000}) {
      final World world = World(Random(seed));
      world.ensureGenerated(rows, GameConfig.maxDangerChance);

      bool safe(int row, Lane lane) {
        final Segment? s = world.segmentAt(row);
        if (s == null) return true;
        final LaneState state = s.stateOf(lane);
        return state == LaneState.safe || state == LaneState.platform;
      }

      // Track every lane the climber could still be standing in at each row.
      // A lane is reachable if it is safe here and was either reachable on the
      // row below (walked straight up) or crossed into from the other lane -
      // and crossing is only legal when this row is safe on both sides.
      Set<Lane> reachable = <Lane>{
        for (final lane in Lane.values)
          if (safe(0, lane)) lane,
      };
      for (int row = 1; row <= rows; row++) {
        final Set<Lane> next = <Lane>{};
        for (final lane in Lane.values) {
          if (!safe(row, lane)) continue;
          final Lane other = lane == Lane.left ? Lane.right : Lane.left;
          final bool walkedUp = reachable.contains(lane);
          final bool crossedOver =
              reachable.contains(other) && safe(row, other);
          if (walkedUp || crossedOver) next.add(lane);
        }
        if (next.isEmpty) {
          final Segment? below = world.segmentAt(row - 1);
          final Segment? here = world.segmentAt(row);
          return 'seed $seed is impassable at row $row: '
              'below[${below?.left.name}/${below?.right.name}] '
              'here[${here?.left.name}/${here?.right.name}]';
        }
        reachable = next;
      }
      return null;
    }

    test('a perfect climber can always get through', () {
      final List<String> traps = <String>[];
      for (int seed = 0; seed < 200; seed++) {
        final String? trap = findTrap(seed);
        if (trap != null) traps.add(trap);
      }
      expect(traps, isEmpty, reason: traps.join('\n'));
    });

    test('danger only changes lane after a crossable run of safe rows', () {
      for (int seed = 0; seed < 50; seed++) {
        final World world = World(Random(seed));
        world.ensureGenerated(2000, GameConfig.maxDangerChance);

        int? lastDangerRow;
        Lane? lastDangerLane;
        for (int row = 0; row <= 2000; row++) {
          final Segment s = world.segmentAt(row)!;
          expect(
            s.left == LaneState.danger && s.right == LaneState.danger,
            isFalse,
            reason: 'row $row of seed $seed blocks both lanes at once',
          );
          final Lane? danger = s.left == LaneState.danger
              ? Lane.left
              : (s.right == LaneState.danger ? Lane.right : null);
          if (danger == null) continue;
          if (lastDangerLane != null && danger != lastDangerLane) {
            expect(
              row - lastDangerRow! - 1,
              greaterThanOrEqualTo(World.minSafeRowsBeforeLaneSwitch),
              reason: 'seed $seed flips danger from ${lastDangerLane.name} to '
                  '${danger.name} at row $row without room to cross',
            );
          }
          lastDangerRow = row;
          lastDangerLane = danger;
        }
      }
    });

    test('a hazard always lands before the player can reach its row', () {
      // A hazard is only lethal while it is in the air, and it falls from
      // above its target row down onto it. So if it is still falling once the
      // player has climbed level with that row, it comes down *through* them
      // and no amount of reading the ridge saves the run. Placement has to
      // beat the fastest the player could possibly get there - which is not
      // the plain climb speed, because riding an updraft is several times
      // faster than that.
      const double dt = 1 / 60;
      const double viewportHeight = 844;
      final List<String> failures = <String>[];

      for (int seed = 0; seed < 12; seed++) {
        final Random random = Random(seed);
        final World world = World(Random(seed));
        final SpawnDirector director =
            SpawnDirector(random, world, VfxManager(random));
        double worldY = 0;

        for (int frame = 0; frame < 60 * 120; frame++) {
          final double heightMeters = worldY / GameConfig.pixelsPerMeter;
          final double riseSpeed = GameConfig.baseRiseSpeed +
              min(GameConfig.maxRiseSpeedBonus,
                  heightMeters * GameConfig.riseSpeedGrowthPerMeter);
          worldY += riseSpeed * dt;
          world.ensureGenerated(
            (worldY / GameConfig.segmentHeight).floor() +
                GameConfig.lookAheadSegments,
            GameConfig.maxDangerChance,
          );
          director.update(
            dt: dt,
            playerWorldY: worldY,
            riseSpeed: riseSpeed,
            heightMeters: heightMeters,
            viewportHeight: viewportHeight,
            playerLane: Lane.left,
          );

          final double boostedSpeed =
              riseSpeed + GameConfig.updraftBoostSpeedBonus;

          // Re-checked every frame rather than once at spawn, so a column
          // that appears while a hazard is already in the air is covered too.
          for (final obj in director.active) {
            // Whether a meteor homes is decided only after its row is chosen,
            // and a homing one burns longer before dropping - so the row has
            // to survive the version of this meteor that does home, not just
            // the roll that actually came up.
            final double couldStillHome =
                obj.type == FallingObjectType.meteor && !obj.isHoming
                    ? GameConfig.homingMeteorExtraTelegraph
                    : 0;
            final double landsIn = switch (obj.phase) {
              FallingPhase.telegraph => (obj.telegraphDuration - obj.phaseTime) +
                  couldStillHome +
                  obj.fallDuration,
              FallingPhase.falling => obj.fallDuration - obj.phaseTime,
              FallingPhase.impact || FallingPhase.landed => -1,
            };
            if (landsIn < 0) continue; // already solid ground, harmless

            double saving = 0;
            for (final column in director.updrafts) {
              final double from = max(column.bottomWorldY, worldY);
              final double to = min(column.topWorldY, obj.targetWorldY);
              if (to <= from) continue;
              saving += (to - from) * (1 / riseSpeed - 1 / boostedSpeed);
            }
            final double arrivesIn =
                (obj.targetWorldY - worldY) / riseSpeed - saving;
            if (arrivesIn <= landsIn) {
              failures.add('seed $seed: a '
                  '${obj.isHoming ? "homing " : ""}${obj.type.name} at '
                  '${heightMeters.toStringAsFixed(0)}m lands in '
                  '${landsIn.toStringAsFixed(2)}s but the player can be there '
                  'in ${arrivesIn.toStringAsFixed(2)}s');
            }
          }
        }
      }
      expect(failures, isEmpty, reason: failures.take(5).join('\n'));
    });

    test('a lava river never traps the player in one lane forever', () {
      for (int seed = 0; seed < 50; seed++) {
        final World world = World(Random(seed));
        world.ensureGenerated(2000, GameConfig.maxDangerChance);
        int run = 0;
        for (int row = 0; row <= 2000; row++) {
          final Segment s = world.segmentAt(row)!;
          final bool danger =
              s.left == LaneState.danger || s.right == LaneState.danger;
          run = danger ? run + 1 : 0;
          expect(run, lessThanOrEqualTo(World.maxDangerRunRows),
              reason: 'seed $seed has a $run-row lava river ending at $row');
        }
      }
    });
  });
}
