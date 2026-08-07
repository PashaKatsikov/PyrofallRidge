import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/hud_snapshot.dart';
import '../models/progression.dart';
import '../rendering/item_sprites.dart';
import '../services/items_atlas_service.dart';
import '../services/progress_service.dart';
import 'atlas_icon.dart';
import 'menu_tile.dart';
import 'progress_badges.dart';

/// Shown while [GamePhase.gameOver]: final height, best height, Embers earned,
/// the XP the run was worth and where that leaves the climber's level, plus
/// explicit buttons to climb again or go back to the menu.
///
/// The panel is staged rather than dumped on screen all at once: the verdict
/// lands first, the height counts up to its final value, then the rewards and
/// the buttons arrive. It costs half a second and it is the difference between
/// a results table and a payoff.
class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({
    super.key,
    required this.hud,
    required this.result,
    required this.onRestart,
    required this.onExit,
  });

  final ValueNotifier<HudSnapshot> hud;
  final RunResult result;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stage = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..forward();

  @override
  void dispose() {
    _stage.dispose();
    super.dispose();
  }

  /// A 0..1 ramp over the [start]..[end] slice of the staging timeline.
  Animation<double> _step(double start, double end) => CurvedAnimation(
        parent: _stage,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final RunResult result = widget.result;
    return AnimatedBuilder(
      animation: _stage,
      builder: (context, child) => BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 7 * _stage.value,
          sigmaY: 7 * _stage.value,
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55 * _stage.value),
          child: child,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ValueListenableBuilder<HudSnapshot>(
              valueListenable: widget.hud,
              builder: (context, snapshot, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Staged(
                      animation: _step(0.0, 0.35),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AtlasIcon(
                              image: ItemsAtlasService.instance.cell(
                                  ItemSprites.uiSkull.row,
                                  ItemSprites.uiSkull.col),
                              size: 26,
                              fallback: Icons.dangerous,
                              fallbackColor: kAccentHot,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'GAME OVER',
                              style: TextStyle(
                                color: kAccentHot,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CountUpMeters(
                      meters: snapshot.heightMeters,
                      animation: _step(0.15, 0.7),
                    ),
                    _Staged(
                      animation: _step(0.3, 0.6),
                      child: Text(
                        'Best: ${snapshot.bestHeightMeters} m',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (result.isNewBest) ...[
                      const SizedBox(height: 8),
                      _NewBestBanner(animation: _step(0.55, 0.85)),
                    ],
                    const SizedBox(height: 16),
                    _Staged(
                      animation: _step(0.5, 0.8),
                      child: _EmbersRow(
                        earned: snapshot.embersThisRun,
                        total: snapshot.totalEmbers,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Staged(
                      animation: _step(0.6, 0.9),
                      child: _XpPanel(result: result),
                    ),
                    const SizedBox(height: 22),
                    _Staged(
                      animation: _step(0.75, 1.0),
                      child: Column(
                        children: [
                          PrimaryButton(
                            label: 'CLIMB AGAIN',
                            icon: Icons.refresh,
                            width: 210,
                            onTap: widget.onRestart,
                          ),
                          const SizedBox(height: 11),
                          PrimaryButton(
                            label: 'MAIN MENU',
                            icon: Icons.home_rounded,
                            filled: false,
                            width: 210,
                            onTap: widget.onExit,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts [child] in over its slice of the staging timeline.
class _Staged extends StatelessWidget {
  const _Staged({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

/// The run's height, counting up to its real value.
///
/// Watching the number climb is a much better reward than reading it, and it
/// mirrors what the player just spent the run doing.
class _CountUpMeters extends StatelessWidget {
  const _CountUpMeters({required this.meters, required this.animation});

  final int meters;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final int shown = (meters * animation.value).round();
        return Opacity(
          opacity: animation.value == 0 ? 0 : 1,
          child: Text(
            '$shown m',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              height: 1.0,
              shadows: <Shadow>[
                Shadow(color: Colors.black87, blurRadius: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "NEW BEST!", arriving with a small overshoot and then glowing.
class _NewBestBanner extends StatelessWidget {
  const _NewBestBanner({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.4, end: 1).animate(
        CurvedAnimation(parent: animation, curve: Curves.elasticOut),
      ),
      child: FadeTransition(
        opacity: animation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: kAccentHot.withValues(alpha: 0.18),
            border: Border.all(color: kAccent.withValues(alpha: 0.7)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: kAccentHot.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: -2,
              ),
            ],
          ),
          child: const Text(
            'NEW BEST!',
            style: TextStyle(
              color: kAccent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmbersRow extends StatelessWidget {
  const _EmbersRow({required this.earned, required this.total});

  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AtlasIcon(
            image: ItemsAtlasService.instance
                .cell(ItemSprites.uiCurrency.row, ItemSprites.uiCurrency.col),
            size: 20,
            fallback: Icons.local_fire_department,
            fallbackColor: kAccent,
          ),
          const SizedBox(width: 8),
          Text(
            '+$earned',
            style: const TextStyle(
              color: kAccent,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 1,
            height: 14,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Total: $total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _XpPanel extends StatelessWidget {
  const _XpPanel({required this.result});

  final RunResult result;

  @override
  Widget build(BuildContext context) {
    final ProgressService progress = ProgressService.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: result.leveledUp
              ? kAccent.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.12),
          width: result.leveledUp ? 1.7 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            result.leveledUp
                ? 'LEVEL UP!  ${result.levelBefore} \u2192 ${result.levelAfter}'
                : '+${result.xpGained} XP',
            style: TextStyle(
              color: result.leveledUp ? kAccent : Colors.white,
              fontSize: result.leveledUp ? 16 : 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 9),
          XpBar(progress: progress.levelProgress, width: 200),
          const SizedBox(height: 6),
          Text(
            progress.isMaxLevel
                ? 'Max level reached'
                : 'Level ${progress.level} \u00b7 ${progress.xpForLevelUp - progress.xpIntoLevel} XP to next',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
