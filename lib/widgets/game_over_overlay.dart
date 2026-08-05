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
class GameOverOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ValueListenableBuilder<HudSnapshot>(
              valueListenable: hud,
              builder: (context, snapshot, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
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
                    const SizedBox(height: 14),
                    Text(
                      '${snapshot.heightMeters} m',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'Best: ${snapshot.bestHeightMeters} m',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (result.isNewBest) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'NEW BEST!',
                        style: TextStyle(
                          color: kAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _EmbersRow(
                      earned: snapshot.embersThisRun,
                      total: snapshot.totalEmbers,
                    ),
                    const SizedBox(height: 12),
                    _XpPanel(result: result),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: 'CLIMB AGAIN',
                      icon: Icons.refresh,
                      width: 210,
                      onTap: onRestart,
                    ),
                    const SizedBox(height: 11),
                    PrimaryButton(
                      label: 'MAIN MENU',
                      icon: Icons.home_rounded,
                      filled: false,
                      width: 210,
                      onTap: onExit,
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
