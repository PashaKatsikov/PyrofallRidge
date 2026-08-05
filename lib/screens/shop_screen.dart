import 'package:flutter/material.dart';

import '../models/upgrade.dart';
import '../rendering/item_sprites.dart';
import '../services/items_atlas_service.dart';
import '../services/progress_service.dart';
import '../widgets/atlas_icon.dart';
import '../widgets/menu_scaffold.dart';
import '../widgets/progress_badges.dart';

/// Spends Embers on permanent upgrades.
///
/// Everything here is bought with the soft currency earned by climbing; there
/// is no real-money purchase anywhere in the game.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      title: 'UPGRADES',
      trailing: const EmbersBadge(),
      child: AnimatedBuilder(
        animation: ProgressService.instance,
        builder: (context, _) {
          final ProgressService progress = ProgressService.instance;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            itemCount: UpgradeCatalog.all.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final UpgradeDefinition upgrade = UpgradeCatalog.all[index];
              return _UpgradeCard(
                upgrade: upgrade,
                level: progress.upgradeLevel(upgrade),
                cost: progress.upgradeCost(upgrade),
                affordable: progress.canBuyUpgrade(upgrade),
                onBuy: () {
                  if (!progress.buyUpgrade(upgrade)) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${upgrade.name} improved'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.upgrade,
    required this.level,
    required this.cost,
    required this.affordable,
    required this.onBuy,
  });

  final UpgradeDefinition upgrade;
  final int level;

  /// Price of the next step, or null when the track is fully bought.
  final int? cost;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final bool maxed = cost == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: affordable
              ? kAccent.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.12),
          width: affordable ? 1.8 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AtlasIcon(
                image: ItemsAtlasService.instance
                    .cell(upgrade.sprite.row, upgrade.sprite.col),
                size: 34,
                fallback: Icons.upgrade,
                fallbackColor: kAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      upgrade.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      maxed
                          ? 'Fully upgraded'
                          : '${upgrade.effectPerLevel} per step',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: kAccent.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LevelPips(level: level, maxLevel: upgrade.maxLevel),
          const SizedBox(height: 8),
          Text(
            upgrade.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Level $level / ${upgrade.maxLevel}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _BuySlot(cost: cost, affordable: affordable, onBuy: onBuy),
            ],
          ),
        ],
      ),
    );
  }
}

/// One filled pip per purchased step, so the track's state reads at a glance
/// without having to parse the "Level x / y" line.
class _LevelPips extends StatelessWidget {
  const _LevelPips({required this.level, required this.maxLevel});

  final int level;
  final int maxLevel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < maxLevel; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i < level
                    ? kAccent
                    : Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BuySlot extends StatelessWidget {
  const _BuySlot({
    required this.cost,
    required this.affordable,
    required this.onBuy,
  });

  final int? cost;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final int? price = cost;
    if (price == null) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle, color: Color(0xFF7BC96F), size: 20),
          SizedBox(width: 6),
          Text(
            'MAX',
            style: TextStyle(
              color: Color(0xFF7BC96F),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
    }

    final Color tint = affordable
        ? kAccent
        : Colors.white.withValues(alpha: 0.32);
    final Widget label = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AtlasIcon(
          image: ItemsAtlasService.instance
              .cell(ItemSprites.uiCurrency.row, ItemSprites.uiCurrency.col),
          size: 14,
          fallback: Icons.local_fire_department,
          fallbackColor: tint,
        ),
        const SizedBox(width: 5),
        Text(
          '$price',
          style: TextStyle(
            color: tint,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );

    if (!affordable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tint, width: 1.2),
        ),
        child: label,
      );
    }

    return Material(
      color: kAccentHot.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onBuy,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kAccent, width: 1.4),
          ),
          child: label,
        ),
      ),
    );
  }
}
