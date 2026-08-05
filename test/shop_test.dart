import 'package:flutter_test/flutter_test.dart';
import 'package:ridgegame/models/upgrade.dart';
import 'package:ridgegame/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final ProgressService progress = ProgressService.instance;
  final UpgradeDefinition shield = UpgradeCatalog.byId(UpgradeId.shield);
  final UpgradeDefinition magnet = UpgradeCatalog.byId(UpgradeId.magnet);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await progress.resetProgress();
  });

  group('upgrade catalog', () {
    test('every track has priced, ascending steps', () {
      for (final UpgradeDefinition u in UpgradeCatalog.all) {
        expect(u.costs, isNotEmpty, reason: '${u.id.name} has no steps');
        for (int i = 1; i < u.costs.length; i++) {
          expect(u.costs[i], greaterThan(u.costs[i - 1]),
              reason: '${u.id.name} step $i is not more expensive than the last');
        }
        expect(u.maxLevel, u.costs.length);
        expect(u.costToUpgrade(u.maxLevel), isNull);
      }
    });

    test('ids are unique', () {
      final Set<UpgradeId> ids =
          UpgradeCatalog.all.map((UpgradeDefinition u) => u.id).toSet();
      expect(ids.length, UpgradeCatalog.all.length);
    });
  });

  group('buying', () {
    test('an upgrade cannot be bought without enough Embers', () {
      expect(progress.totalEmbers, 0);
      expect(progress.canBuyUpgrade(magnet), isFalse);
      expect(progress.buyUpgrade(magnet), isFalse);
      expect(progress.upgradeLevel(magnet), 0);
    });

    test('buying spends exactly the listed cost and raises the level', () {
      progress.recordRun(heightMeters: 0, embers: 500);
      final int before = progress.totalEmbers;
      final int cost = progress.upgradeCost(magnet)!;

      expect(progress.buyUpgrade(magnet), isTrue);
      expect(progress.upgradeLevel(magnet), 1);
      expect(progress.totalEmbers, before - cost);
    });

    test('a maxed track refuses further purchases', () {
      progress.recordRun(heightMeters: 0, embers: 100000);
      for (int i = 0; i < shield.maxLevel; i++) {
        expect(progress.buyUpgrade(shield), isTrue);
      }
      expect(progress.upgradeLevel(shield), shield.maxLevel);
      expect(progress.isUpgradeMaxed(shield), isTrue);
      expect(progress.upgradeCost(shield), isNull);
      expect(progress.canBuyUpgrade(shield), isFalse);

      final int before = progress.totalEmbers;
      expect(progress.buyUpgrade(shield), isFalse);
      expect(progress.totalEmbers, before);
    });

    test('Embers spent in the shop do not count towards collection goals', () {
      progress.recordRun(heightMeters: 0, embers: 500);
      final int collected = progress.embersFromRuns;
      progress.buyUpgrade(magnet);
      expect(progress.embersFromRuns, collected);
    });
  });

  group('effects', () {
    test('are neutral on a fresh profile', () {
      expect(progress.shieldCharges, 0);
      expect(progress.pickupRadiusBonus, 0);
      expect(progress.comboWindowBonusSeconds, 0);
      expect(progress.emberValueMultiplier, 1);
      expect(progress.xpMultiplier, 1);
    });

    test('scale with the purchased level', () {
      progress.recordRun(heightMeters: 0, embers: 100000);
      progress.buyUpgrade(shield);
      progress.buyUpgrade(shield);
      expect(progress.shieldCharges, 2);

      progress.buyUpgrade(magnet);
      expect(progress.pickupRadiusBonus, closeTo(0.12, 1e-9));
    });

    test('the XP bonus is applied to a recorded run', () {
      progress.recordRun(heightMeters: 0, embers: 100000);
      final int baseline =
          progress.recordRun(heightMeters: 100, embers: 0).xpGained;
      // Buy every step of the XP track, then compare the same run again.
      final UpgradeDefinition xp = UpgradeCatalog.byId(UpgradeId.xpBoost);
      while (progress.buyUpgrade(xp)) {}
      expect(progress.upgradeLevel(xp), xp.maxLevel);
      final int boosted =
          progress.recordRun(heightMeters: 100, embers: 0).xpGained;
      expect(boosted, greaterThan(baseline));
    });
  });

  test('purchases survive a reload and are wiped by a reset', () async {
    progress.recordRun(heightMeters: 0, embers: 100000);
    progress.buyUpgrade(shield);
    progress.buyUpgrade(magnet);
    progress.buyUpgrade(magnet);

    await progress.reload();
    expect(progress.upgradeLevel(shield), 1);
    expect(progress.upgradeLevel(magnet), 2);

    await progress.resetProgress();
    expect(progress.upgradeLevel(shield), 0);
    expect(progress.upgradeLevel(magnet), 0);
    await progress.reload();
    expect(progress.upgradeLevel(magnet), 0);
  });
}
