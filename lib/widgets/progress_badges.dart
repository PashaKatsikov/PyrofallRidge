import 'package:flutter/material.dart';

import '../rendering/item_sprites.dart';
import '../services/items_atlas_service.dart';
import '../services/progress_service.dart';
import 'atlas_icon.dart';

const Color kAccent = Color(0xFFFFC66B);
const Color kAccentHot = Color(0xFFFF7A3C);

/// Total Embers the player owns. Rebuilds itself whenever the balance moves.
class EmbersBadge extends StatelessWidget {
  const EmbersBadge({super.key, this.iconSize = 16, this.fontSize = 15});

  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ProgressService.instance,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAccent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AtlasIcon(
              image: ItemsAtlasService.instance.cell(
                  ItemSprites.uiCurrency.row, ItemSprites.uiCurrency.col),
              size: iconSize,
              fallback: Icons.local_fire_department,
              fallbackColor: kAccent,
            ),
            const SizedBox(width: 6),
            Text(
              '${ProgressService.instance.totalEmbers}',
              style: TextStyle(
                color: kAccent,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Climber level plus the XP bar towards the next one - the single thing that
/// gates skin unlocks, so it is shown prominently in the menu and after every
/// run.
class LevelPanel extends StatelessWidget {
  const LevelPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ProgressService.instance,
      builder: (context, _) {
        final ProgressService progress = ProgressService.instance;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kAccent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AtlasIcon(
                    image: ItemsAtlasService.instance.cell(
                        ItemSprites.uiLevel.row, ItemSprites.uiLevel.col),
                    size: compact ? 16 : 20,
                    fallback: Icons.military_tech,
                    fallbackColor: kAccent,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'LEVEL ${progress.level}',
                    style: TextStyle(
                      color: kAccent,
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Flexible so a large system font scale ellipsizes the XP
                  // figure instead of overflowing the panel.
                  Flexible(
                    child: Text(
                      progress.isMaxLevel
                          ? 'MAX'
                          : '${progress.xpIntoLevel} / ${progress.xpForLevelUp} XP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              XpBar(progress: progress.levelProgress, width: double.infinity),
            ],
          ),
        );
      },
    );
  }
}

class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.progress, required this.width});

  final double progress;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 7,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0).toDouble(),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: <Color>[kAccentHot, kAccent],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
