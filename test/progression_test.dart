import 'package:flutter_test/flutter_test.dart';
import 'package:ridgegame/models/goal.dart';
import 'package:ridgegame/models/progression.dart';
import 'package:ridgegame/models/skin.dart';
import 'package:ridgegame/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LevelCurve', () {
    test('level 1 needs no experience and thresholds grow', () {
      expect(LevelCurve.totalXpForLevel(1), 0);
      expect(LevelCurve.totalXpForLevel(2), greaterThan(0));
      for (int level = 2; level <= LevelCurve.maxLevel; level++) {
        expect(
          LevelCurve.totalXpForLevel(level),
          greaterThan(LevelCurve.totalXpForLevel(level - 1)),
        );
      }
    });

    test('levelForXp is the inverse of the thresholds', () {
      for (int level = 1; level <= LevelCurve.maxLevel; level++) {
        expect(LevelCurve.levelForXp(LevelCurve.totalXpForLevel(level)), level);
      }
    });

    test('level is capped at the maximum', () {
      expect(LevelCurve.levelForXp(99999999), LevelCurve.maxLevel);
    });

    test('height and Embers both contribute experience', () {
      expect(LevelCurve.xpForRun(heightMeters: 100, embers: 0), 100);
      expect(LevelCurve.xpForRun(heightMeters: 100, embers: 10), 130);
    });
  });

  group('SkinCatalog', () {
    test('every skin has a reachable unlock level', () {
      for (final SkinDefinition skin in SkinCatalog.all) {
        expect(skin.unlockLevel, inInclusiveRange(1, LevelCurve.maxLevel));
      }
    });

    test('at least one skin is wearable at level 1', () {
      expect(
        SkinCatalog.all.any((s) => SkinCatalog.isUnlocked(s, 1)),
        isTrue,
      );
    });
  });

  group('ProgressService', () {
    late ProgressService progress;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      progress = ProgressService.instance;
      await progress.resetProgress();
    });

    test('a run folds into best height, Embers, XP and the score table', () {
      final RunResult result =
          progress.recordRun(heightMeters: 250, embers: 12);

      expect(result.isNewBest, isTrue);
      expect(result.xpGained, LevelCurve.xpForRun(heightMeters: 250, embers: 12));
      expect(progress.bestHeightMeters, 250);
      expect(progress.totalEmbers, 12);
      expect(progress.embersFromRuns, 12);
      expect(progress.bestRunEmbers, 12);
      expect(progress.runsPlayed, 1);
      expect(progress.scores.single.meters, 250);
    });

    test('a weaker run does not lower the records', () {
      progress.recordRun(heightMeters: 400, embers: 20);
      final RunResult second =
          progress.recordRun(heightMeters: 90, embers: 3);

      expect(second.isNewBest, isFalse);
      expect(progress.bestHeightMeters, 400);
      expect(progress.bestRunEmbers, 20);
      expect(progress.totalEmbers, 23);
    });

    test('the score table keeps only the best entries, highest first', () {
      for (int i = 1; i <= ProgressService.maxScoreEntries + 5; i++) {
        progress.recordRun(heightMeters: i * 10, embers: 0);
      }
      expect(progress.scores.length, ProgressService.maxScoreEntries);
      expect(progress.scores.first.meters, greaterThan(progress.scores.last.meters));
    });

    test('goal rewards pay out once and do not feed collection goals', () {
      const GoalDefinition goal = GoalDefinition(
        id: 'test_goal',
        title: 'test',
        metric: GoalMetric.runsPlayed,
        target: 1,
        rewardEmbers: 100,
      );

      progress.recordRun(heightMeters: 10, embers: 5);
      expect(progress.canClaimGoal(goal), isTrue);

      expect(progress.claimGoal(goal), 100);
      expect(progress.totalEmbers, 105);
      // Rewarded Embers must not count towards "collect N Embers" goals.
      expect(progress.embersFromRuns, 5);

      expect(progress.claimGoal(goal), 0);
      expect(progress.totalEmbers, 105);
    });

    test('the daily reward can only be taken once per day', () {
      expect(progress.canClaimDaily, isTrue);
      final int first = progress.claimDaily();

      expect(first, ProgressService.dailyRewards.first);
      expect(progress.dailyStreak, 1);
      expect(progress.canClaimDaily, isFalse);
      expect(progress.claimDaily(), 0);
      expect(progress.totalEmbers, first);
    });

    test('resetting wipes every progression value', () async {
      progress.recordRun(heightMeters: 500, embers: 50);
      progress.claimDaily();
      await progress.resetProgress();

      expect(progress.bestHeightMeters, 0);
      expect(progress.totalEmbers, 0);
      expect(progress.totalXp, 0);
      expect(progress.runsPlayed, 0);
      expect(progress.level, 1);
      expect(progress.scores, isEmpty);
      expect(progress.canClaimDaily, isTrue);
    });
  });
}
