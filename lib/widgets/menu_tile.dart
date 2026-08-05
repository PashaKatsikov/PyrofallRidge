import 'package:flutter/material.dart';

import '../rendering/item_sprites.dart';
import '../services/items_atlas_service.dart';
import 'atlas_icon.dart';
import 'progress_badges.dart';

/// One entry of the main menu grid: sprite icon, label, and an optional dot
/// telling the player something is waiting for them there.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.label,
    required this.icon,
    required this.fallbackIcon,
    required this.onTap,
    this.badge = false,
  });

  final String label;
  final ItemCoord icon;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kAccent.withValues(alpha: 0.28), width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AtlasIcon(
                    image: ItemsAtlasService.instance.cell(icon.row, icon.col),
                    size: 34,
                    fallback: fallbackIcon,
                    fallbackColor: kAccent,
                  ),
                  if (badge)
                    Positioned(
                      right: -4,
                      top: -2,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: kAccentHot,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black54, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one big call-to-action button, used for PLAY and for the primary
/// action of the pause / game over overlays.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.play_arrow_rounded,
    this.filled = true,
    this.width,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final bool filled;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final Color border = filled ? kAccent : Colors.white54;
    return Material(
      color: filled
          ? kAccentHot.withValues(alpha: 0.22)
          : Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: border.withValues(alpha: 0.75), width: 1.6),
          ),
          // A fixed [width] plus a long label or a large system font would
          // overflow the pill, so the content scales down inside it instead.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: filled ? kAccent : Colors.white70),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? kAccent : Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
