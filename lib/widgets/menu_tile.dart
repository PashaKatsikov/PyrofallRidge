import 'package:flutter/material.dart';

import '../core/layout_config.dart';
import '../rendering/item_sprites.dart';
import '../services/audio_service.dart';
import '../services/items_atlas_service.dart';
import 'atlas_icon.dart';
import 'pressable.dart';
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
    final double scale = LayoutConfig.uiScale(MediaQuery.sizeOf(context));
    return Pressable(
      onTap: onTap,
      sfx: Sfx.menuOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(16 * scale),
          border: Border.all(color: kAccent.withValues(alpha: 0.28), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AtlasIcon(
                    image: ItemsAtlasService.instance.cell(icon.row, icon.col),
                    size: 34 * scale,
                    fallback: fallbackIcon,
                    fallbackColor: kAccent,
                  ),
                  if (badge)
                    Positioned(
                      right: -4,
                      top: -2,
                      child: _BadgeDot(size: 11 * scale),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8 * scale),
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
    );
  }
}

/// The "something is waiting for you here" dot, pulsing so it catches the eye
/// on a menu the player has seen a hundred times.
class _BadgeDot extends StatefulWidget {
  const _BadgeDot({required this.size});

  final double size;

  @override
  State<_BadgeDot> createState() => _BadgeDotState();
}

class _BadgeDotState extends State<_BadgeDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: kAccentHot,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black54, width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: kAccentHot.withValues(alpha: 0.6),
              blurRadius: widget.size * 0.6,
            ),
          ],
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
    final double scale = LayoutConfig.uiScale(MediaQuery.sizeOf(context));
    return Pressable(
      onTap: onTap,
      child: Container(
        width: width == null ? null : width! * scale,
        padding: EdgeInsets.symmetric(
          horizontal: 26 * scale,
          vertical: 13 * scale,
        ),
        decoration: BoxDecoration(
          color: filled
              ? kAccentHot.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(26 * scale),
          border: Border.all(color: border.withValues(alpha: 0.75), width: 1.6),
          // Only the primary action glows, so it always reads as *the* button
          // on a screen even next to two or three secondary ones.
          boxShadow: filled
              ? <BoxShadow>[
                  BoxShadow(
                    color: kAccentHot.withValues(alpha: 0.28),
                    blurRadius: 22 * scale,
                    spreadRadius: -4,
                  ),
                ]
              : null,
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
    );
  }
}
