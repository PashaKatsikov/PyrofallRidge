import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// Every sound the game can play, mapped to its bundled asset.
///
/// Kept as an enum rather than raw paths so a typo can't silently produce a
/// run with no audio, and so the mixer below can attach per-cue defaults
/// (mix level, retrigger throttle) in one place.
enum Sfx {
  buttonTap('button_tap_asset.mp3', volume: 0.55),
  menuOpen('menu_open_asset.mp3', volume: 0.5),
  menuClose('menu_close_asset.mp3', volume: 0.45),
  popupAppear('popup_appear_asset.mp3', volume: 0.55),
  popupClose('popup_close_asset.mp3', volume: 0.5),
  loadingComplete('loading_complete_asset.mp3', volume: 0.6),
  levelStart('level_start_asset.mp3', volume: 0.7),
  levelComplete('level_complete_asset.mp3', volume: 0.75),
  failure('failure_asset.mp3', volume: 0.85),
  pickup('collectible_pickup_asset.mp3', volume: 0.5, minGapMs: 45),
  comboChain('combo_chain_asset.mp3', volume: 0.6),
  laneSwipe('lane_swipe_asset.wav', volume: 0.55, minGapMs: 90),
  meteorImpact('meteor_impact_asset.mp3', volume: 0.7, minGapMs: 60),
  stonePlatform('stone_platform_created_asset.mp3', volume: 0.55, minGapMs: 60),
  updraftBoost('updraft_boost_asset.mp3', volume: 0.7),
  updraftCharging('crystal_charging_asset.mp3', volume: 0.5),
  bigPickup('crystal_explosion_asset.mp3', volume: 0.65),
  shield('ancient_mechanism_activated_asset.mp3', volume: 0.8),
  reward('notification_asset.mp3', volume: 0.6),
  select('button_hover_asset.mp3', volume: 0.5);

  const Sfx(this.asset, {this.volume = 1.0, this.minGapMs = 0});

  final String asset;

  /// Per-cue mix level, applied on top of the user's SFX volume.
  final double volume;

  /// Minimum time between two plays of this cue. Rapid-fire cues (a burst of
  /// Ember pickups) would otherwise stack into a wall of identical transients.
  final int minGapMs;

  String get path => 'audio/$asset';
}

/// The game's mixer: a small pool of reusable [AudioPlayer]s for one-shot
/// effects plus one dedicated looping player for the volcanic ambience.
///
/// Everything is fire-and-forget and failure-tolerant: audio is a polish
/// layer, so a device that refuses to open an audio session (a simulator, a
/// locked-down profile, a test harness) must degrade to silence and never
/// throw into the game loop.
class AudioService extends ChangeNotifier {
  AudioService._();

  static final AudioService instance = AudioService._();

  static const String _ambienceAsset = 'audio/lava_flow_loop_asset.mp3';

  /// Enough voices that a pickup, an impact and a UI blip can overlap without
  /// cutting each other off, but few enough that the OS audio session stays
  /// cheap on older iPhones.
  static const int _voiceCount = 6;

  final StorageService _storage = StorageService();
  final List<AudioPlayer> _voices = <AudioPlayer>[];
  int _nextVoice = 0;

  AudioPlayer? _ambiencePlayer;

  /// Last time each cue was actually played, for [Sfx.minGapMs] throttling.
  final Map<Sfx, int> _lastPlayedMs = HashMap<Sfx, int>();

  bool _initialized = false;
  bool _available = false;

  double _sfxVolume = 0.8;
  double _musicVolume = 0.5;

  /// Set while the app is backgrounded, so ambience doesn't keep rumbling
  /// under the lock screen.
  bool _suspended = false;

  /// True once the ambience is *meant* to be playing; combined with
  /// [_suspended] and [_musicVolume] to decide the actual player state.
  bool _ambienceRequested = false;

  double get sfxVolume => _sfxVolume;
  double get musicVolume => _musicVolume;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _sfxVolume = await _storage.loadSfxVolume();
    _musicVolume = await _storage.loadMusicVolume();

    try {
      // Ambient category + mixWithOthers: the climb stays playable while the
      // player listens to their own music, which is table stakes for a mobile
      // game and something App Store reviewers do check.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: <AVAudioSessionOptions>{
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );

      for (int i = 0; i < _voiceCount; i++) {
        final AudioPlayer player = AudioPlayer(playerId: 'pyrofall_sfx_$i');
        await player.setReleaseMode(ReleaseMode.stop);
        _voices.add(player);
      }
      _available = true;
    } catch (error) {
      // Silence rather than a crash - see the class doc.
      _available = false;
      debugPrint('AudioService unavailable: $error');
    }
  }

  // --- One-shots -------------------------------------------------------

  /// Plays [cue] on the next voice in the pool. Safe to call from the game
  /// loop: it never awaits and never throws.
  void play(Sfx cue, {double volumeScale = 1.0, double? rate}) {
    if (!_available || _suspended || _sfxVolume <= 0) return;
    if (_voices.isEmpty) return;

    if (cue.minGapMs > 0) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int? last = _lastPlayedMs[cue];
      if (last != null && now - last < cue.minGapMs) return;
      _lastPlayedMs[cue] = now;
    }

    final AudioPlayer voice = _voices[_nextVoice];
    _nextVoice = (_nextVoice + 1) % _voices.length;

    final double volume =
        (_sfxVolume * cue.volume * volumeScale).clamp(0.0, 1.0).toDouble();
    unawaited(_playOn(voice, cue, volume, rate));
  }

  Future<void> _playOn(
    AudioPlayer voice,
    Sfx cue,
    double volume,
    double? rate,
  ) async {
    try {
      await voice.stop();
      // Pitch variation is what keeps a cue that fires dozens of times a run
      // (every Ember, every impact) from turning into a machine gun.
      await voice.setPlaybackRate(rate == null
          ? 1.0
          : rate.clamp(0.5, 2.0).toDouble());
      await voice.play(AssetSource(cue.path), volume: volume);
    } catch (_) {
      // A dropped one-shot is never worth interrupting the run for.
    }
  }

  // --- Ambience --------------------------------------------------------

  /// Starts (or resumes) the looping volcanic ambience.
  void startAmbience() {
    _ambienceRequested = true;
    unawaited(_syncAmbience());
  }

  void stopAmbience() {
    _ambienceRequested = false;
    unawaited(_syncAmbience());
  }

  Future<void> _syncAmbience() async {
    if (!_available) return;
    final bool shouldPlay =
        _ambienceRequested && !_suspended && _musicVolume > 0;
    try {
      AudioPlayer? player = _ambiencePlayer;
      if (!shouldPlay) {
        await player?.pause();
        return;
      }
      if (player == null) {
        player = AudioPlayer(playerId: 'pyrofall_ambience');
        _ambiencePlayer = player;
        await player.setReleaseMode(ReleaseMode.loop);
        await player.play(
          AssetSource(_ambienceAsset),
          volume: _ambienceMix,
        );
        return;
      }
      await player.setVolume(_ambienceMix);
      await player.resume();
    } catch (_) {
      // Ambience is the most disposable layer of all.
    }
  }

  /// The loop is a bed, not a track: it sits well under the effects even at
  /// full "music" volume.
  double get _ambienceMix => (_musicVolume * 0.55).clamp(0.0, 1.0).toDouble();

  /// Called when the app is backgrounded: everything goes quiet without
  /// tearing the players down.
  void suspend() {
    if (_suspended) return;
    _suspended = true;
    unawaited(_syncAmbience());
  }

  void resumeFromSuspend() {
    if (!_suspended) return;
    _suspended = false;
    unawaited(_syncAmbience());
  }

  // --- Settings --------------------------------------------------------

  Future<void> setSfxVolume(double value) async {
    final double next = value.clamp(0.0, 1.0).toDouble();
    if (next == _sfxVolume) return;
    _sfxVolume = next;
    notifyListeners();
    await _storage.saveSfxVolume(next);
  }

  Future<void> setMusicVolume(double value) async {
    final double next = value.clamp(0.0, 1.0).toDouble();
    if (next == _musicVolume) return;
    _musicVolume = next;
    notifyListeners();
    await _syncAmbience();
    await _storage.saveMusicVolume(next);
  }

  @override
  void dispose() {
    for (final AudioPlayer voice in _voices) {
      unawaited(voice.dispose());
    }
    _voices.clear();
    unawaited(_ambiencePlayer?.dispose());
    _ambiencePlayer = null;
    super.dispose();
  }
}
