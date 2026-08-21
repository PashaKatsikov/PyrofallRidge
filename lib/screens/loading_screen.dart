import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/attribution_service.dart';
import '../services/audio_service.dart';
import '../services/background_service.dart';
import '../services/haptic_service.dart';
import '../services/items_atlas_service.dart';
import '../services/lava_atlas_service.dart';
import '../services/profile_service.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../services/skin_atlas_service.dart';
import '../services/skin_manager.dart';
import '../services/terrain_atlas_service.dart';
import '../services/vfx_atlas_service.dart';
import '../widgets/loading_progress_bar.dart';
import 'main_menu_screen.dart';

/// First screen shown on launch.
///
/// Orientation is intentionally left unlocked here so the background can
/// match either the portrait or landscape artwork depending on how the
/// device is held; the moment loading finishes and we hand off to the
/// [GameScreen], the app locks to portrait for the rest of its lifetime.
///
/// The progress bar is driven by real asset/pref initialization tasks - it
/// is mathematically impossible for it to reach 100% before the app has
/// actually finished preparing everything it needs.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _displayProgress = ValueNotifier<double>(0);
  double _targetProgress = 0;
  bool _allTasksDone = false;
  bool _navigated = false;

  late final Ticker _ticker;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runLoadTasks());
  }

  Future<void> _runLoadTasks() async {
    // Fire-and-forget: install attribution is pure measurement, and the ATT
    // permission prompt it may trigger waits on a user tap, so it must never
    // hold up the loading bar.
    unawaited(AttributionService.instance.initialize());

    final List<Future<void> Function()> tasks = <Future<void> Function()>[
      () => precacheImage(const AssetImage('assets/Game_Name.webp'), context),
      () => precacheImage(const AssetImage('assets/Icon.png'), context),
      () => precacheImage(
          const AssetImage('assets/Vertical_Loading_Screen.webp'), context),
      () => precacheImage(
          const AssetImage('assets/Horizontal_Loading_Screen.webp'), context),
      () => precacheImage(
          const AssetImage('assets/bg_location_3_asset.webp'), context),
      () => SettingsService.instance.initialize(),
      () => ProgressService.instance.initialize(),
      () => ProfileService.instance.initialize(),
      () => SkinManager.instance.initialize(),
      () => HapticService.instance.initialize(),
      // Opening the audio session and pre-decoding the first cues happens
      // here so the very first button press already clicks.
      () => AudioService.instance.initialize(),
      // Slicing every sprite atlas down to tightly cropped cells happens
      // once, here, and never again during actual gameplay.
      () => SkinAtlasService.instance.preload(),
      () => VfxAtlasService.instance.preload(),
      () => ItemsAtlasService.instance.preload(),
      () => TerrainAtlasService.instance.preload(),
      () => LavaAtlasService.instance.preload(),
      () => BackgroundService.instance.preload(),
    ];

    for (int i = 0; i < tasks.length; i++) {
      await tasks[i]();
      if (!mounted) return;
      _targetProgress = (i + 1) / tasks.length;
    }
    _allTasksDone = true;
  }

  void _onTick(Duration elapsed) {
    final Duration? last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final double dt = (elapsed - last).inMicroseconds / 1000000.0;

    // Ease the visible bar towards the real progress, but it can never
    // pass it - only genuine completion of the load tasks can finish it.
    const double catchUpPerSecond = 1.6;
    final double next =
        _displayProgress.value +
            catchUpPerSecond * dt.clamp(0.0, 0.05).toDouble();
    _displayProgress.value =
        next < _targetProgress ? next : _targetProgress;

    if (_allTasksDone && _displayProgress.value >= _targetProgress - 0.001) {
      _displayProgress.value = 1;
      _finish();
    }
  }

  void _finish() {
    if (_navigated) return;
    _navigated = true;
    _ticker.stop();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    AudioService.instance.play(Sfx.loadingComplete);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainMenuScreen()),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _displayProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1420),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final String backgroundAsset = orientation == Orientation.portrait
              ? 'assets/Vertical_Loading_Screen.webp'
              : 'assets/Horizontal_Loading_Screen.webp';
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(backgroundAsset, fit: BoxFit.cover),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC0D0608)],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const LoadingDotsText(),
                      const SizedBox(height: 12),
                      LoadingProgressBar(progress: _displayProgress),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
