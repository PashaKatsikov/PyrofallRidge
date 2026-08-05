import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridgegame/models/hud_snapshot.dart';
import 'package:ridgegame/models/progression.dart';
import 'package:ridgegame/models/upgrade.dart';
import 'package:ridgegame/screens/daily_reward_screen.dart';
import 'package:ridgegame/screens/game_screen.dart';
import 'package:ridgegame/screens/goals_screen.dart';
import 'package:ridgegame/screens/how_to_play_screen.dart';
import 'package:ridgegame/screens/leaderboard_screen.dart';
import 'package:ridgegame/screens/main_menu_screen.dart';
import 'package:ridgegame/screens/settings_screen.dart';
import 'package:ridgegame/screens/shop_screen.dart';
import 'package:ridgegame/screens/skins_screen.dart';
import 'package:ridgegame/services/progress_service.dart';
import 'package:ridgegame/widgets/game_over_overlay.dart';
import 'package:ridgegame/widgets/hud_overlay.dart';
import 'package:ridgegame/widgets/pause_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests for every screen at a small phone size: they must lay out
/// without overflowing (an overflow throws in tests) and without exceptions,
/// even before any sprite atlas has loaded - every sprite has to degrade to
/// its fallback icon.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: screen,
      ),
    );
    await tester.pump();
  }

  testWidgets('main menu lays out', (tester) async {
    await pumpScreen(tester, const MainMenuScreen());
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('SKINS'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('skins screen lays out with level gating', (tester) async {
    await pumpScreen(tester, const SkinsScreen());
    // At level 1 most skins are still locked and show their level tag.
    expect(find.textContaining('Lv '), findsWidgets);
  });

  testWidgets('goals screen lays out', (tester) async {
    await pumpScreen(tester, const GoalsScreen());
    expect(find.text('Climb 100 m'), findsOneWidget);
  });

  testWidgets('daily reward screen lays out', (tester) async {
    await pumpScreen(tester, const DailyRewardScreen());
    expect(find.text('DAY 1'), findsOneWidget);
  });

  testWidgets('leaderboard shows the empty hint before any run',
      (tester) async {
    await ProgressService.instance.resetProgress();
    await pumpScreen(tester, const LeaderboardScreen());
    expect(find.text('Finish a climb to open your table.'), findsOneWidget);
    // The player row sits inside the rivals table further down the list.
    await tester.scrollUntilVisible(find.text('YOU'), 120);
    expect(find.text('YOU'), findsOneWidget);
  });

  testWidgets('how to play screen lays out', (tester) async {
    await pumpScreen(tester, const HowToPlayScreen());
    expect(find.text('YOUR GOAL'), findsOneWidget);
  });

  testWidgets('settings screen lays out', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    expect(find.text('RESET PROGRESS'), findsOneWidget);
    expect(find.text('FULL'), findsOneWidget);
  });

  testWidgets('shop screen lays out with every track locked at zero',
      (tester) async {
    await ProgressService.instance.resetProgress();
    await pumpScreen(tester, const ShopScreen());
    // The list is taller than the test viewport, so each card has to be
    // scrolled into view before it can be asserted on.
    for (final UpgradeDefinition upgrade in UpgradeCatalog.all) {
      final Finder name = find.text(upgrade.name);
      await tester.scrollUntilVisible(name, 120);
      expect(name, findsOneWidget);
      expect(find.text('Level 0 / ${upgrade.maxLevel}'), findsWidgets,
          reason: '${upgrade.name} should start unbought');
      expect(find.text('MAX'), findsNothing,
          reason: 'nothing is maxed on a fresh profile');
    }
  });

  testWidgets('shop screen shows a bought track as upgraded', (tester) async {
    await ProgressService.instance.resetProgress();
    ProgressService.instance.recordRun(heightMeters: 0, embers: 5000);
    final UpgradeDefinition magnet = UpgradeCatalog.byId(UpgradeId.magnet);
    expect(ProgressService.instance.buyUpgrade(magnet), isTrue);

    await pumpScreen(tester, const ShopScreen());
    final Finder level = find.text('Level 1 / ${magnet.maxLevel}');
    await tester.scrollUntilVisible(level, 120);
    expect(level, findsOneWidget);
  });

  testWidgets('game screen opens on the ready state', (tester) async {
    await pumpScreen(tester, const GameScreen());
    expect(find.text('TAP TO START'), findsOneWidget);
  });

  testWidgets('pause overlay lays out', (tester) async {
    await pumpScreen(
      tester,
      PauseOverlay(
        onResume: () {},
        onRestart: () {},
        onExit: () {},
      ),
    );
    expect(find.text('RESUME'), findsOneWidget);
    expect(find.text('MAIN MENU'), findsOneWidget);
  });

  testWidgets('game over overlay lays out with a five digit run', (tester) async {
    const HudSnapshot snapshot = HudSnapshot(
      heightMeters: 18450,
      bestHeightMeters: 18450,
      ridgeNumber: 19,
      embersThisRun: 1284,
      totalEmbers: 99999,
    );
    await pumpScreen(
      tester,
      Stack(
        children: [
          HudOverlay(hud: ValueNotifier(snapshot), onPause: () {}),
          GameOverOverlay(
            hud: ValueNotifier(snapshot),
            result: const RunResult(
              heightMeters: 18450,
              embers: 1284,
              xpGained: 2130,
              levelBefore: 7,
              levelAfter: 9,
              isNewBest: true,
            ),
            onRestart: () {},
            onExit: () {},
          ),
        ],
      ),
    );
    expect(find.text('CLIMB AGAIN'), findsOneWidget);
    expect(find.textContaining('LEVEL UP!'), findsOneWidget);
  });
}
