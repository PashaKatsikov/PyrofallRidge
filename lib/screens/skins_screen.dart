import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/skin.dart';
import '../services/progress_service.dart';
import '../services/skin_atlas_service.dart';
import '../services/skin_manager.dart';
import '../widgets/menu_scaffold.dart';
import '../widgets/progress_badges.dart';

/// Cosmetic-only skin picker. A skin becomes wearable at its unlock level and
/// selecting it saves instantly; nothing here touches gameplay, collisions or
/// difficulty in any way.
class SkinsScreen extends StatelessWidget {
  const SkinsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      title: 'SKINS',
      trailing: const EmbersBadge(),
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          SkinManager.instance,
          ProgressService.instance,
        ]),
        builder: (context, _) {
          final int level = ProgressService.instance.level;
          final int selectedId = SkinManager.instance.selectedSkinId;
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: LevelPanel(),
              ),
              const SizedBox(height: 10),
              _SelectedPreview(selectedId: selectedId, level: level),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: SkinCatalog.all.length,
                  itemBuilder: (context, index) {
                    final SkinDefinition skin = SkinCatalog.all[index];
                    final bool unlocked = SkinCatalog.isUnlocked(skin, level);
                    return _SkinCard(
                      skin: skin,
                      unlocked: unlocked,
                      selected: selectedId == skin.id,
                      onTap: unlocked
                          ? () => SkinManager.instance.selectSkin(skin.id)
                          : null,
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

class _SelectedPreview extends StatelessWidget {
  const _SelectedPreview({required this.selectedId, required this.level});

  final int selectedId;
  final int level;

  @override
  Widget build(BuildContext context) {
    final SkinDefinition skin = SkinCatalog.byId(selectedId);
    final ui.Image? image = SkinAtlasService.instance.imageForSkin(selectedId);
    final int lockedCount = SkinCatalog.all
        .where((SkinDefinition s) => !SkinCatalog.isUnlocked(s, level))
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Container(
            width: 124,
            height: 124,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: rarityColor(skin.rarity).withValues(alpha: 0.9),
                width: 2.5,
              ),
            ),
            child: image != null
                ? RawImage(image: image, fit: BoxFit.contain)
                : const Icon(Icons.person, color: Colors.white54, size: 48),
          ),
          const SizedBox(height: 8),
          Text(
            skin.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            rarityLabel(skin.rarity),
            style: TextStyle(
              color: rarityColor(skin.rarity),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          if (lockedCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '$lockedCount more unlock as you level up',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final SkinDefinition skin;
  final bool unlocked;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color rarity = rarityColor(skin.rarity);
    final ui.Image? image = SkinAtlasService.instance.imageForSkin(skin.id);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: selected ? 0.5 : 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? kAccent
                : rarity.withValues(alpha: unlocked ? 0.85 : 0.35),
            width: selected ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Opacity(
                  opacity: unlocked ? 1 : 0.32,
                  child: image != null
                      ? RawImage(image: image, fit: BoxFit.contain)
                      : const Icon(Icons.person,
                          color: Colors.white38, size: 30),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5, left: 4, right: 4),
              child: unlocked
                  ? Text(
                      skin.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock, color: Colors.white54, size: 11),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            'Lv ${skin.unlockLevel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Color rarityColor(SkinRarity rarity) {
  switch (rarity) {
    case SkinRarity.common:
      return const Color(0xFFB9B0AA);
    case SkinRarity.rare:
      return const Color(0xFF4FA8FF);
    case SkinRarity.epic:
      return const Color(0xFFB15CFF);
    case SkinRarity.legendary:
      return const Color(0xFFFFC24C);
  }
}

String rarityLabel(SkinRarity rarity) {
  switch (rarity) {
    case SkinRarity.common:
      return 'COMMON';
    case SkinRarity.rare:
      return 'RARE';
    case SkinRarity.epic:
      return 'EPIC';
    case SkinRarity.legendary:
      return 'LEGENDARY';
  }
}
