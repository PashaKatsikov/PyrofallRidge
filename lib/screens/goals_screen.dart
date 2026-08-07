import 'package:flutter/material.dart';

import '../models/goal.dart';
import '../rendering/item_sprites.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/items_atlas_service.dart';
import '../services/progress_service.dart';
import '../widgets/atlas_icon.dart';
import '../widgets/menu_scaffold.dart';
import '../widgets/progress_badges.dart';

/// The long-term objectives that give the climb a point beyond the score:
/// each one tracks a statistic the game already records and pays out Embers
/// once, when the player claims it.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      title: 'GOALS',
      trailing: const EmbersBadge(),
      child: AnimatedBuilder(
        animation: ProgressService.instance,
        builder: (context, _) {
          final ProgressService progress = ProgressService.instance;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            itemCount: GoalCatalog.all.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final GoalDefinition goal = GoalCatalog.all[index];
              return _GoalCard(
                goal: goal,
                current: progress.progressFor(goal),
                claimed: progress.isGoalClaimed(goal),
                claimable: progress.canClaimGoal(goal),
                onClaim: () {
                  final int reward = progress.claimGoal(goal);
                  if (reward > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Claimed $reward Embers'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.current,
    required this.claimed,
    required this.claimable,
    required this.onClaim,
  });

  final GoalDefinition goal;
  final int current;
  final bool claimed;
  final bool claimable;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final int shown = current > goal.target ? goal.target : current;
    final double ratio = goal.target == 0 ? 1 : shown / goal.target;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: claimable
              ? kAccent.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.12),
          width: claimable ? 1.8 : 1.2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: TextStyle(
                    color: claimed
                        ? Colors.white.withValues(alpha: 0.55)
                        : Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    decoration: claimed ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                XpBar(progress: ratio, width: double.infinity),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$shown / ${goal.target}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    AtlasIcon(
                      image: ItemsAtlasService.instance.cell(
                          ItemSprites.uiCurrency.row,
                          ItemSprites.uiCurrency.col),
                      size: 13,
                      fallback: Icons.local_fire_department,
                      fallbackColor: kAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${goal.rewardEmbers}',
                      style: const TextStyle(
                        color: kAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ClaimSlot(claimed: claimed, claimable: claimable, onClaim: onClaim),
        ],
      ),
    );
  }
}

class _ClaimSlot extends StatelessWidget {
  const _ClaimSlot({
    required this.claimed,
    required this.claimable,
    required this.onClaim,
  });

  final bool claimed;
  final bool claimable;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    if (claimed) {
      return const Icon(Icons.check_circle, color: Color(0xFF7BC96F), size: 26);
    }
    if (!claimable) {
      return Icon(Icons.lock_outline,
          color: Colors.white.withValues(alpha: 0.35), size: 22);
    }
    return Material(
      color: kAccentHot.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          AudioService.instance.play(Sfx.reward);
          HapticService.instance.heavy();
          onClaim();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kAccent, width: 1.4),
          ),
          child: const Text(
            'CLAIM',
            style: TextStyle(
              color: kAccent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
