import 'package:flutter/material.dart';

import '../rendering/item_sprites.dart';
import '../services/items_atlas_service.dart';
import '../services/progress_service.dart';
import '../widgets/atlas_icon.dart';
import '../widgets/menu_scaffold.dart';
import '../widgets/menu_tile.dart';
import '../widgets/progress_badges.dart';

/// A seven-day Embers cycle claimable once per calendar day. Entirely local:
/// the streak is tracked against the device's own date, nothing is verified
/// against a server and nothing is ever purchasable.
class DailyRewardScreen extends StatelessWidget {
  const DailyRewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      title: 'DAILY REWARD',
      trailing: const EmbersBadge(),
      child: AnimatedBuilder(
        animation: ProgressService.instance,
        builder: (context, _) {
          final ProgressService progress = ProgressService.instance;
          final int nextIndex = progress.nextDailyIndex;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                Text(
                  progress.canClaimDaily
                      ? 'Today\'s reward is waiting'
                      : 'Come back tomorrow for day ${nextIndex + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Streak: ${progress.dailyStreak} day${progress.dailyStreak == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.86,
                  children: [
                    for (int i = 0; i < ProgressService.dailyRewards.length; i++)
                      _DaySlot(
                        day: i + 1,
                        amount: ProgressService.dailyRewards[i],
                        isNext: i == nextIndex,
                        isPast: _isAlreadyEarned(progress, i, nextIndex),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                if (progress.canClaimDaily)
                  PrimaryButton(
                    label: 'CLAIM ${progress.nextDailyReward}',
                    icon: Icons.card_giftcard,
                    onTap: () {
                      final int reward = progress.claimDaily();
                      if (reward > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('+$reward Embers'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  )
                else
                  Text(
                    'Already claimed today',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Miss a day and the streak restarts from day 1.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Slots before the next one in the current cycle have already been paid
  /// out - unless the streak has just reset, in which case none have.
  bool _isAlreadyEarned(ProgressService progress, int index, int nextIndex) {
    if (progress.canClaimDaily) return index < nextIndex;
    return index <= nextIndex;
  }
}

class _DaySlot extends StatelessWidget {
  const _DaySlot({
    required this.day,
    required this.amount,
    required this.isNext,
    required this.isPast,
  });

  final int day;
  final int amount;
  final bool isNext;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: isNext ? 0.5 : 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNext
              ? kAccent
              : Colors.white.withValues(alpha: isPast ? 0.28 : 0.12),
          width: isNext ? 2 : 1.2,
        ),
      ),
      // The slot is a fixed grid cell, so scale the stack down rather than
      // letting a wider system font push the check mark out of the card.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'DAY $day',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Opacity(
              opacity: isPast ? 0.45 : 1,
              child: AtlasIcon(
                image: ItemsAtlasService.instance.cell(
                    ItemSprites.uiCurrency.row, ItemSprites.uiCurrency.col),
                size: 24,
                fallback: Icons.local_fire_department,
                fallbackColor: kAccent,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$amount',
              style: TextStyle(
                color: isPast ? Colors.white54 : kAccent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isPast)
              const Icon(Icons.check, size: 13, color: Color(0xFF7BC96F)),
          ],
        ),
      ),
    );
  }
}
