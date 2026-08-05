/// Experience curve for the climber's level.
///
/// Levels are the single gate for unlocking skins, so the curve is tuned so a
/// decent early run (~400 m with a handful of Embers) is worth roughly one
/// level, while the last few legendary unlocks take real dedication.
class LevelCurve {
  LevelCurve._();

  static const int maxLevel = 40;

  /// Total XP required to have reached [level].
  static int totalXpForLevel(int level) {
    if (level <= 1) return 0;
    final int capped = level > maxLevel ? maxLevel : level;
    return (capped - 1) * (capped + 4) * 60;
  }

  static int levelForXp(int totalXp) {
    int level = 1;
    while (level < maxLevel && totalXp >= totalXpForLevel(level + 1)) {
      level++;
    }
    return level;
  }

  /// XP a run is worth: height is the main driver, Embers a solid bonus.
  static int xpForRun({required int heightMeters, required int embers}) =>
      heightMeters + embers * 3;
}

/// One entry of the local score table.
class ScoreEntry {
  const ScoreEntry({required this.meters, required this.achievedAt});

  final int meters;
  final DateTime achievedAt;

  String encode() => '$meters:${achievedAt.millisecondsSinceEpoch}';

  static ScoreEntry? decode(String raw) {
    final List<String> parts = raw.split(':');
    if (parts.length != 2) return null;
    final int? meters = int.tryParse(parts[0]);
    final int? millis = int.tryParse(parts[1]);
    if (meters == null || millis == null) return null;
    return ScoreEntry(
      meters: meters,
      achievedAt: DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }
}

/// Everything the Game Over screen needs to report about the run that just
/// ended, computed once when the run is recorded.
class RunResult {
  const RunResult({
    required this.heightMeters,
    required this.embers,
    required this.xpGained,
    required this.levelBefore,
    required this.levelAfter,
    required this.isNewBest,
  });

  static const RunResult none = RunResult(
    heightMeters: 0,
    embers: 0,
    xpGained: 0,
    levelBefore: 1,
    levelAfter: 1,
    isNewBest: false,
  );

  final int heightMeters;
  final int embers;
  final int xpGained;
  final int levelBefore;
  final int levelAfter;
  final bool isNewBest;

  bool get leveledUp => levelAfter > levelBefore;
}
