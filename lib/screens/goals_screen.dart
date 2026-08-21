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

/// Which subset of [GoalCatalog.all] the player wants to see.
enum _GoalFilter {
  all('ALL'),
  inProgress('IN PROGRESS'),
  completed('COMPLETED');

  const _GoalFilter(this.label);

  final String label;

  bool matches(bool claimed) => switch (this) {
        _GoalFilter.all => true,
        _GoalFilter.inProgress => !claimed,
        _GoalFilter.completed => claimed,
      };
}

/// The long-term objectives that give the climb a point beyond the score:
/// each one tracks a statistic the game already records and pays out Embers
/// once, when the player claims it.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  _GoalFilter _filter = _GoalFilter.all;

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      title: 'GOALS',
      trailing: const EmbersBadge(),
      child: AnimatedBuilder(
        animation: ProgressService.instance,
        builder: (context, _) {
          final ProgressService progress = ProgressService.instance;
          final List<GoalDefinition> filtered = GoalCatalog.all
              .where((goal) => _filter.matches(progress.isGoalClaimed(goal)))
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Row(
                  children: [
                    for (int i = 0; i < _GoalFilter.values.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          label: _GoalFilter.values[i].label,
                          selected: _filter == _GoalFilter.values[i],
                          onTap: () => setState(
                              () => _filter = _GoalFilter.values[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyFilterHint(filter: _filter)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final GoalDefinition goal = filtered[index];
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One "ALL / IN PROGRESS / COMPLETED" pill. Matches the look of the choice
/// chips on the Settings screen so filtering reads as the same kind of
/// control everywhere in the game.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? kAccentHot.withValues(alpha: 0.24)
          : Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: () {
          HapticService.instance.light();
          AudioService.instance.play(Sfx.select);
          onTap();
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color:
                  selected ? kAccent : Colors.white.withValues(alpha: 0.18),
              width: selected ? 1.6 : 1.1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? kAccent : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the list when the active filter matches nothing yet -
/// e.g. "COMPLETED" before the player has claimed a single goal.
class _EmptyFilterHint extends StatelessWidget {
  const _EmptyFilterHint({required this.filter});

  final _GoalFilter filter;

  @override
  Widget build(BuildContext context) {
    final String message = switch (filter) {
      _GoalFilter.completed => 'No goals claimed yet.',
      _GoalFilter.inProgress => 'Every goal is already claimed!',
      _GoalFilter.all => 'No goals yet.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13.5,
          ),
        ),
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
