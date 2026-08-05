import 'package:flutter/material.dart';

import '../core/game_config.dart';
import '../game/game_controller.dart';
import '../models/game_phase.dart';
import '../models/lane.dart';
import '../rendering/game_painter.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/hud_overlay.dart';
import '../widgets/pause_overlay.dart';
import '../widgets/ready_overlay.dart';

/// Hosts the whole gameplay loop: the always-mounted [CustomPaint] canvas,
/// the full-screen swipe/tap gesture surface, and the thin state-dependent
/// overlays (ready / HUD / pause / game over).
///
/// Pushed from the main menu and popped when the player leaves, so quitting a
/// run always lands back on the menu with fresh progression numbers.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameController _controller = GameController(vsync: this);
  // Built once and reused: the painter owns caches (tile shaders, viewport
  // gradients, text painters) that would be thrown away on every rebuild if it
  // were constructed inline in [build].
  late final GamePainter _painter = GamePainter(_controller);

  double _dragAccumulator = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Losing focus mid-climb would otherwise mean dying to a hazard the
    // player never saw, so back-grounding the app pauses the run.
    if (state != AppLifecycleState.resumed) {
      _controller.pause();
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragAccumulator = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _dragAccumulator += details.delta.dx;
    if (_dragAccumulator > GameConfig.swipeThreshold) {
      _controller.requestLaneChange(Lane.right);
      _dragAccumulator = 0;
    } else if (_dragAccumulator < -GameConfig.swipeThreshold) {
      _controller.requestLaneChange(Lane.left);
      _dragAccumulator = 0;
    }
  }

  void _exitToMenu() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    // The gate has to be rebuilt on every phase change, otherwise a stale
    // `canPop` would let the hardware back button abandon an active run
    // instead of opening the pause menu.
    return ValueListenableBuilder<GamePhase>(
      valueListenable: _controller.phase,
      builder: (context, phase, child) => PopScope(
        canPop: phase != GamePhase.playing,
        onPopInvokedWithResult: (bool didPop, void result) {
          if (!didPop) _controller.pause();
        },
        child: child!,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF120A10),
        body: LayoutBuilder(
          builder: (context, constraints) {
            _controller.setViewportSize(constraints.biggest);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _controller.handlePrimaryTap,
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _painter,
                    size: constraints.biggest,
                  ),
                  ValueListenableBuilder<GamePhase>(
                    valueListenable: _controller.phase,
                    builder: (context, phase, _) {
                      if (phase == GamePhase.ready) {
                        return const SizedBox.shrink();
                      }
                      return HudOverlay(
                        hud: _controller.hud,
                        onPause: _controller.pause,
                      );
                    },
                  ),
                  ValueListenableBuilder<GamePhase>(
                    valueListenable: _controller.phase,
                    builder: (context, phase, _) {
                      switch (phase) {
                        case GamePhase.ready:
                          return ReadyOverlay(onExit: _exitToMenu);
                        case GamePhase.paused:
                          return PauseOverlay(
                            onResume: _controller.resume,
                            onRestart: _controller.start,
                            onExit: _exitToMenu,
                          );
                        case GamePhase.gameOver:
                          return GameOverOverlay(
                            hud: _controller.hud,
                            result: _controller.lastRunResult,
                            onRestart: _controller.start,
                            onExit: _exitToMenu,
                          );
                        case GamePhase.playing:
                          return const SizedBox.shrink();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
