import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] for everything the app persists
/// locally and offline: the best height, the selected cosmetic skin, the
/// Embers collection, experience/level progression, daily-reward bookkeeping,
/// the local score table, claimed goals and the player's settings.
///
/// Every value has its own key, so none of them can ever conflict, and each
/// getter degrades to a sensible default on a fresh install.
class StorageService {
  static const String _bestHeightKey = 'pyrofall_ridge.best_height_meters';
  static const String _selectedSkinKey = 'pyrofall_ridge.selected_skin_id';
  static const String _totalEmbersKey = 'pyrofall_ridge.total_embers';
  static const String _embersFromRunsKey = 'pyrofall_ridge.embers_from_runs';
  static const String _bestRunEmbersKey = 'pyrofall_ridge.best_run_embers';
  static const String _totalXpKey = 'pyrofall_ridge.total_xp';
  static const String _runsPlayedKey = 'pyrofall_ridge.runs_played';
  static const String _dailyLastDayKey = 'pyrofall_ridge.daily_last_day';
  static const String _dailyStreakKey = 'pyrofall_ridge.daily_streak';
  static const String _scoresKey = 'pyrofall_ridge.scores';
  static const String _claimedGoalsKey = 'pyrofall_ridge.claimed_goals';
  static const String _upgradesKey = 'pyrofall_ridge.upgrades';
  static const String _effectsQualityKey = 'pyrofall_ridge.effects_quality';
  static const String _backgroundsKey = 'pyrofall_ridge.show_backgrounds';
  static const String _sfxVolumeKey = 'pyrofall_ridge.sfx_volume';
  static const String _musicVolumeKey = 'pyrofall_ridge.music_volume';
  static const String _hapticsKey = 'pyrofall_ridge.haptics_enabled';
  static const String _onboardedKey = 'pyrofall_ridge.onboarded';
  static const String _avatarPathKey = 'pyrofall_ridge.avatar_path';

  static const List<String> _progressKeys = <String>[
    _bestHeightKey,
    _selectedSkinKey,
    _totalEmbersKey,
    _embersFromRunsKey,
    _bestRunEmbersKey,
    _totalXpKey,
    _runsPlayedKey,
    _dailyLastDayKey,
    _dailyStreakKey,
    _scoresKey,
    _claimedGoalsKey,
    _upgradesKey,
  ];

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<int> loadBestHeight() async => (await _prefs).getInt(_bestHeightKey) ?? 0;

  Future<void> saveBestHeight(int meters) async =>
      (await _prefs).setInt(_bestHeightKey, meters);

  Future<int> loadSelectedSkinId() async =>
      (await _prefs).getInt(_selectedSkinKey) ?? 0;

  Future<void> saveSelectedSkinId(int id) async =>
      (await _prefs).setInt(_selectedSkinKey, id);

  Future<int> loadTotalEmbers() async =>
      (await _prefs).getInt(_totalEmbersKey) ?? 0;

  Future<void> saveTotalEmbers(int amount) async =>
      (await _prefs).setInt(_totalEmbersKey, amount);

  /// Embers earned by actually picking them up during runs. Kept apart from
  /// the spendable/displayed total so goal rewards can grant Embers without
  /// making "collect N Embers" goals complete themselves.
  Future<int> loadEmbersFromRuns() async =>
      (await _prefs).getInt(_embersFromRunsKey) ?? 0;

  Future<void> saveEmbersFromRuns(int amount) async =>
      (await _prefs).setInt(_embersFromRunsKey, amount);

  Future<int> loadBestRunEmbers() async =>
      (await _prefs).getInt(_bestRunEmbersKey) ?? 0;

  Future<void> saveBestRunEmbers(int amount) async =>
      (await _prefs).setInt(_bestRunEmbersKey, amount);

  Future<int> loadTotalXp() async => (await _prefs).getInt(_totalXpKey) ?? 0;

  Future<void> saveTotalXp(int xp) async =>
      (await _prefs).setInt(_totalXpKey, xp);

  Future<int> loadRunsPlayed() async =>
      (await _prefs).getInt(_runsPlayedKey) ?? 0;

  Future<void> saveRunsPlayed(int runs) async =>
      (await _prefs).setInt(_runsPlayedKey, runs);

  /// Days since epoch of the last claimed daily reward, or -1 if never.
  Future<int> loadDailyLastDay() async =>
      (await _prefs).getInt(_dailyLastDayKey) ?? -1;

  Future<void> saveDailyLastDay(int epochDay) async =>
      (await _prefs).setInt(_dailyLastDayKey, epochDay);

  Future<int> loadDailyStreak() async =>
      (await _prefs).getInt(_dailyStreakKey) ?? 0;

  Future<void> saveDailyStreak(int streak) async =>
      (await _prefs).setInt(_dailyStreakKey, streak);

  /// Local score table, newest-best first, encoded as "meters:epochMillis".
  Future<List<String>> loadScores() async =>
      (await _prefs).getStringList(_scoresKey) ?? const <String>[];

  Future<void> saveScores(List<String> encoded) async =>
      (await _prefs).setStringList(_scoresKey, encoded);

  Future<List<String>> loadClaimedGoals() async =>
      (await _prefs).getStringList(_claimedGoalsKey) ?? const <String>[];

  Future<void> saveClaimedGoals(List<String> ids) async =>
      (await _prefs).setStringList(_claimedGoalsKey, ids);

  /// Purchased upgrade levels, encoded as "upgradeName:level". Only non-zero
  /// levels are stored, so an untouched profile costs nothing to keep.
  Future<List<String>> loadUpgrades() async =>
      (await _prefs).getStringList(_upgradesKey) ?? const <String>[];

  Future<void> saveUpgrades(List<String> encoded) async =>
      (await _prefs).setStringList(_upgradesKey, encoded);

  Future<int> loadEffectsQuality() async =>
      (await _prefs).getInt(_effectsQualityKey) ?? 0;

  Future<void> saveEffectsQuality(int index) async =>
      (await _prefs).setInt(_effectsQualityKey, index);

  Future<bool> loadShowBackgrounds() async =>
      (await _prefs).getBool(_backgroundsKey) ?? true;

  Future<void> saveShowBackgrounds(bool value) async =>
      (await _prefs).setBool(_backgroundsKey, value);

  Future<double> loadSfxVolume() async =>
      (await _prefs).getDouble(_sfxVolumeKey) ?? 0.8;

  Future<void> saveSfxVolume(double value) async =>
      (await _prefs).setDouble(_sfxVolumeKey, value);

  Future<double> loadMusicVolume() async =>
      (await _prefs).getDouble(_musicVolumeKey) ?? 0.5;

  Future<void> saveMusicVolume(double value) async =>
      (await _prefs).setDouble(_musicVolumeKey, value);

  Future<bool> loadHapticsEnabled() async =>
      (await _prefs).getBool(_hapticsKey) ?? true;

  Future<void> saveHapticsEnabled(bool value) async =>
      (await _prefs).setBool(_hapticsKey, value);

  /// Whether the player has already been shown the first-run swipe tutorial.
  Future<bool> loadOnboarded() async =>
      (await _prefs).getBool(_onboardedKey) ?? false;

  Future<void> saveOnboarded(bool value) async =>
      (await _prefs).setBool(_onboardedKey, value);

  /// Absolute path to the locally saved profile photo, or null if the player
  /// never set one (or removed it). The photo itself lives in the app's own
  /// documents directory - only the path is kept here.
  Future<String?> loadAvatarPath() async =>
      (await _prefs).getString(_avatarPathKey);

  Future<void> saveAvatarPath(String? path) async {
    final SharedPreferences prefs = await _prefs;
    if (path == null) {
      await prefs.remove(_avatarPathKey);
    } else {
      await prefs.setString(_avatarPathKey, path);
    }
  }

  /// Wipes progression only - the player's settings survive a reset.
  Future<void> clearProgress() async {
    final SharedPreferences prefs = await _prefs;
    for (final String key in _progressKeys) {
      await prefs.remove(key);
    }
  }
}
