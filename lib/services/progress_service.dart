import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/goal.dart';
import '../models/progression.dart';
import '../models/upgrade.dart';
import 'storage_service.dart';

/// Single source of truth for everything the player keeps between runs:
/// best height, Embers, experience/level, how many climbs they've finished,
/// their local score table, daily-reward streak and claimed goals.
///
/// A [ChangeNotifier] singleton so the menu, the Skins screen and the Game
/// Over overlay all observe the same numbers without any DI plumbing, and so
/// the gameplay layer only has to hand it one [recordRun] call.
class ProgressService extends ChangeNotifier {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  static const int maxScoreEntries = 10;

  /// Embers paid out for each day of the weekly daily-reward cycle.
  static const List<int> dailyRewards = <int>[10, 15, 25, 40, 60, 90, 150];

  final StorageService _storage = StorageService();

  int _bestHeightMeters = 0;
  int _totalEmbers = 0;
  int _embersFromRuns = 0;
  int _bestRunEmbers = 0;
  int _totalXp = 0;
  int _runsPlayed = 0;
  int _dailyLastDay = -1;
  int _dailyStreak = 0;
  List<ScoreEntry> _scores = const <ScoreEntry>[];
  Set<String> _claimedGoals = <String>{};
  Map<UpgradeId, int> _upgradeLevels = <UpgradeId, int>{};

  bool _initialized = false;

  int get bestHeightMeters => _bestHeightMeters;
  int get totalEmbers => _totalEmbers;
  int get embersFromRuns => _embersFromRuns;
  int get bestRunEmbers => _bestRunEmbers;
  int get totalXp => _totalXp;
  int get runsPlayed => _runsPlayed;
  int get dailyStreak => _dailyStreak;
  List<ScoreEntry> get scores => _scores;

  int get level => LevelCurve.levelForXp(_totalXp);
  bool get isMaxLevel => level >= LevelCurve.maxLevel;

  /// XP accumulated inside the current level, and how much that level needs.
  int get xpIntoLevel => _totalXp - LevelCurve.totalXpForLevel(level);
  int get xpForLevelUp => isMaxLevel
      ? 0
      : LevelCurve.totalXpForLevel(level + 1) -
          LevelCurve.totalXpForLevel(level);

  double get levelProgress {
    if (isMaxLevel || xpForLevelUp <= 0) return 1;
    return (xpIntoLevel / xpForLevelUp).clamp(0.0, 1.0).toDouble();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _bestHeightMeters = await _storage.loadBestHeight();
    _totalEmbers = await _storage.loadTotalEmbers();
    _embersFromRuns = await _storage.loadEmbersFromRuns();
    _bestRunEmbers = await _storage.loadBestRunEmbers();
    _totalXp = await _storage.loadTotalXp();
    _runsPlayed = await _storage.loadRunsPlayed();
    _dailyLastDay = await _storage.loadDailyLastDay();
    _dailyStreak = await _storage.loadDailyStreak();
    _scores = _decodeScores(await _storage.loadScores());
    _claimedGoals = (await _storage.loadClaimedGoals()).toSet();
    _upgradeLevels = _decodeUpgrades(await _storage.loadUpgrades());
    notifyListeners();
  }

  /// Discards the in-memory profile and reads it back from storage, so a test
  /// can prove a value genuinely round-trips instead of only checking the
  /// field it just assigned.
  @visibleForTesting
  Future<void> reload() async {
    _initialized = false;
    await initialize();
  }

  // --- Runs -----------------------------------------------------------------

  /// Folds a finished run into the persistent profile and returns everything
  /// the Game Over screen wants to show about it.
  RunResult recordRun({required int heightMeters, required int embers}) {
    final int levelBefore = level;
    final int xpGained =
        (LevelCurve.xpForRun(heightMeters: heightMeters, embers: embers) *
                xpMultiplier)
            .round();

    final bool isNewBest = heightMeters > _bestHeightMeters;
    if (isNewBest) {
      _bestHeightMeters = heightMeters;
      unawaited(_storage.saveBestHeight(_bestHeightMeters));
    }
    if (embers > 0) {
      _totalEmbers += embers;
      _embersFromRuns += embers;
      unawaited(_storage.saveTotalEmbers(_totalEmbers));
      unawaited(_storage.saveEmbersFromRuns(_embersFromRuns));
    }
    if (embers > _bestRunEmbers) {
      _bestRunEmbers = embers;
      unawaited(_storage.saveBestRunEmbers(_bestRunEmbers));
    }
    _totalXp += xpGained;
    unawaited(_storage.saveTotalXp(_totalXp));
    _runsPlayed++;
    unawaited(_storage.saveRunsPlayed(_runsPlayed));

    if (heightMeters > 0) {
      _insertScore(ScoreEntry(meters: heightMeters, achievedAt: DateTime.now()));
    }

    notifyListeners();
    return RunResult(
      heightMeters: heightMeters,
      embers: embers,
      xpGained: xpGained,
      levelBefore: levelBefore,
      levelAfter: level,
      isNewBest: isNewBest,
    );
  }

  void _insertScore(ScoreEntry entry) {
    final List<ScoreEntry> next = <ScoreEntry>[..._scores, entry]
      ..sort((a, b) => b.meters.compareTo(a.meters));
    _scores = next.length > maxScoreEntries
        ? next.sublist(0, maxScoreEntries)
        : next;
    unawaited(
      _storage.saveScores(_scores.map((ScoreEntry e) => e.encode()).toList()),
    );
  }

  // --- Goals ----------------------------------------------------------------

  int progressFor(GoalDefinition goal) {
    switch (goal.metric) {
      case GoalMetric.bestHeight:
        return _bestHeightMeters;
      case GoalMetric.embersCollected:
        return _embersFromRuns;
      case GoalMetric.runsPlayed:
        return _runsPlayed;
      case GoalMetric.level:
        return level;
      case GoalMetric.bestRunEmbers:
        return _bestRunEmbers;
    }
  }

  bool isGoalComplete(GoalDefinition goal) =>
      progressFor(goal) >= goal.target;

  bool isGoalClaimed(GoalDefinition goal) => _claimedGoals.contains(goal.id);

  bool canClaimGoal(GoalDefinition goal) =>
      isGoalComplete(goal) && !isGoalClaimed(goal);

  int get claimableGoalCount =>
      GoalCatalog.all.where(canClaimGoal).length;

  /// Pays out a completed goal exactly once. Returns the Embers granted.
  int claimGoal(GoalDefinition goal) {
    if (!canClaimGoal(goal)) return 0;
    _claimedGoals.add(goal.id);
    _totalEmbers += goal.rewardEmbers;
    unawaited(_storage.saveClaimedGoals(_claimedGoals.toList()));
    unawaited(_storage.saveTotalEmbers(_totalEmbers));
    notifyListeners();
    return goal.rewardEmbers;
  }

  // --- Upgrade shop ---------------------------------------------------------

  /// How many steps of [definition] the player already owns (0 = none).
  int upgradeLevel(UpgradeDefinition definition) =>
      _upgradeLevels[definition.id] ?? 0;

  bool isUpgradeMaxed(UpgradeDefinition definition) =>
      upgradeLevel(definition) >= definition.maxLevel;

  /// Ember price of the next step, or null when the track is maxed out.
  int? upgradeCost(UpgradeDefinition definition) =>
      definition.costToUpgrade(upgradeLevel(definition));

  bool canBuyUpgrade(UpgradeDefinition definition) {
    final int? cost = upgradeCost(definition);
    return cost != null && cost <= _totalEmbers;
  }

  /// Buys one step of [definition], spending its Ember cost. Returns false
  /// (changing nothing) when the track is maxed or the player can't afford it.
  bool buyUpgrade(UpgradeDefinition definition) {
    final int? cost = upgradeCost(definition);
    if (cost == null || cost > _totalEmbers) return false;
    _totalEmbers -= cost;
    _upgradeLevels[definition.id] = upgradeLevel(definition) + 1;
    unawaited(_storage.saveTotalEmbers(_totalEmbers));
    unawaited(_storage.saveUpgrades(_encodeUpgrades()));
    notifyListeners();
    return true;
  }

  // Gameplay-facing effects. Each is derived from a level so the gameplay
  // layer never has to know what the shop sells or how it is stored.

  /// Lethal hits the player can shrug off per run.
  int get shieldCharges => _upgradeLevels[UpgradeId.shield] ?? 0;

  /// Extra pickup collection reach, as a fraction of one segment's height.
  double get pickupRadiusBonus =>
      0.12 * (_upgradeLevels[UpgradeId.magnet] ?? 0);

  /// Extra seconds the Ember combo survives between pickups.
  double get comboWindowBonusSeconds =>
      0.4 * (_upgradeLevels[UpgradeId.comboWindow] ?? 0);

  /// Multiplier applied to a pickup's face value.
  double get emberValueMultiplier =>
      1 + 0.15 * (_upgradeLevels[UpgradeId.emberValue] ?? 0);

  /// Multiplier applied to the XP a finished run awards.
  double get xpMultiplier => 1 + 0.10 * (_upgradeLevels[UpgradeId.xpBoost] ?? 0);

  Map<UpgradeId, int> _decodeUpgrades(List<String> raw) {
    final Map<UpgradeId, int> parsed = <UpgradeId, int>{};
    for (final String entry in raw) {
      final int separator = entry.lastIndexOf(':');
      if (separator <= 0) continue;
      final String name = entry.substring(0, separator);
      final int? value = int.tryParse(entry.substring(separator + 1));
      if (value == null || value <= 0) continue;
      for (final UpgradeDefinition definition in UpgradeCatalog.all) {
        if (definition.id.name != name) continue;
        // Clamped so a stored value from an older, longer track can never
        // report a level the current balance doesn't define.
        parsed[definition.id] = value.clamp(0, definition.maxLevel);
        break;
      }
    }
    return parsed;
  }

  List<String> _encodeUpgrades() => <String>[
        for (final MapEntry<UpgradeId, int> e in _upgradeLevels.entries)
          if (e.value > 0) '${e.key.name}:${e.value}',
      ];

  // --- Daily reward ---------------------------------------------------------

  static int _epochDayOf(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day)
              .millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;

  bool get canClaimDaily => _dailyLastDay != _epochDayOf(DateTime.now());

  /// Which slot of the weekly cycle the next claim will pay out (0-based).
  int get nextDailyIndex {
    final int nextStreak = _streakAfterClaim();
    return (nextStreak - 1) % dailyRewards.length;
  }

  int get nextDailyReward => dailyRewards[nextDailyIndex];

  int _streakAfterClaim() {
    final int today = _epochDayOf(DateTime.now());
    if (_dailyLastDay == today - 1) return _dailyStreak + 1;
    return 1;
  }

  /// Grants today's reward, advancing (or restarting) the streak. Returns the
  /// Embers granted, or 0 if today's reward was already taken.
  int claimDaily() {
    if (!canClaimDaily) return 0;
    _dailyStreak = _streakAfterClaim();
    _dailyLastDay = _epochDayOf(DateTime.now());
    final int reward = dailyRewards[(_dailyStreak - 1) % dailyRewards.length];
    _totalEmbers += reward;
    unawaited(_storage.saveDailyStreak(_dailyStreak));
    unawaited(_storage.saveDailyLastDay(_dailyLastDay));
    unawaited(_storage.saveTotalEmbers(_totalEmbers));
    notifyListeners();
    return reward;
  }

  // --- Reset ----------------------------------------------------------------

  Future<void> resetProgress() async {
    await _storage.clearProgress();
    _bestHeightMeters = 0;
    _totalEmbers = 0;
    _embersFromRuns = 0;
    _bestRunEmbers = 0;
    _totalXp = 0;
    _runsPlayed = 0;
    _dailyLastDay = -1;
    _dailyStreak = 0;
    _scores = const <ScoreEntry>[];
    _claimedGoals = <String>{};
    _upgradeLevels = <UpgradeId, int>{};
    notifyListeners();
  }

  List<ScoreEntry> _decodeScores(List<String> raw) {
    final List<ScoreEntry> parsed = <ScoreEntry>[];
    for (final String value in raw) {
      final ScoreEntry? entry = ScoreEntry.decode(value);
      if (entry != null) parsed.add(entry);
    }
    parsed.sort((a, b) => b.meters.compareTo(a.meters));
    return parsed;
  }
}
