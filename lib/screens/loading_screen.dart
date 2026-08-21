import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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
import '../emberlink/core/relay_models.dart';
import '../emberlink/pages/nudge_screen.dart';
import '../emberlink/pages/offline_screen.dart';
import '../emberlink/pages/portal_view.dart';
import '../emberlink/relay_coordinator.dart';
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
  const LoadingScreen({super.key, this.coordinator});

  final RelayCoordinator? coordinator;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _displayProgress = ValueNotifier<double>(0);
  double _targetProgress = 0;
  bool _allTasksDone = false;
  bool _navigated = false;

  // Online routing decision, resolved in parallel with the asset warm-up. When
  // there is no coordinator or the gray flow is disabled this settles to
  // [HomeStop] immediately, so the loading experience is unchanged.
  RelayStop? _stop;
  bool _decisionReady = false;

  late final Ticker _ticker;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runLoadTasks();
      _resolveRoute();
    });
  }

  Future<void> _resolveRoute() async {
    final coordinator = widget.coordinator;
    if (coordinator == null) {
      _stop = const HomeStop();
      _decisionReady = true;
      return;
    }
    try {
      _stop = await coordinator.decide(onProgress: (_) {});
    } catch (_) {
      _stop = const HomeStop();
    }
    _decisionReady = true;
  }

  Future<void> _runLoadTasks() async {
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
    // While the online routing decision is still pending, hold the bar just
    // short of full so it never parks at 100% waiting on the network.
    final double ceiling = _decisionReady ? _targetProgress : 0.9;
    const double catchUpPerSecond = 1.6;
    final double next =
        _displayProgress.value +
            catchUpPerSecond * dt.clamp(0.0, 0.05).toDouble();
    _displayProgress.value = next < ceiling ? next : ceiling;

    if (_allTasksDone &&
        _decisionReady &&
        _displayProgress.value >= _targetProgress - 0.001) {
      _displayProgress.value = 1;
      _finish();
    }
  }

  void _finish() {
    if (_navigated) return;
    _navigated = true;
    _ticker.stop();
    _route();
  }

  Future<void> _route() async {
    final coordinator = widget.coordinator;
    final stop = _stop ?? const HomeStop();

    // Online paths — the gray screens manage their own orientation.
    if (coordinator != null && stop is OfflineStop) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OfflineScreen(
            probe: coordinator.probe,
            retryBuilder: (_) =>
                LoadingScreen(coordinator: coordinator),
          ),
        ),
      );
      return;
    }

    if (coordinator != null && stop is PortalStop) {
      Widget portalBuilder(BuildContext _) => PortalView(
        url: stop.url,
        coldLaunch: stop.coldLaunch,
        vault: coordinator.vault,
        probe: coordinator.probe,
        pulse: coordinator.pulse,
        agent: coordinator.agent,
      );
      if (coordinator.vault.shouldShowPushInvite &&
          await coordinator.pulse.canOfferPermission()) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => NudgeScreen(
              vault: coordinator.vault,
              pulse: coordinator.pulse,
              nextBuilder: portalBuilder,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute<void>(builder: portalBuilder));
      }
      return;
    }

    // Offline game — original behaviour, unchanged.
    if (!mounted) return;
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
