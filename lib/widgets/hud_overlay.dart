import 'package:flutter/material.dart';

import '../core/layout_config.dart';
import '../models/hud_snapshot.dart';
import '../rendering/item_sprites.dart';
import '../services/haptic_service.dart';
import '../services/items_atlas_service.dart';
import 'atlas_icon.dart';

/// Minimal top HUD: a pause button, current height and Ridge milestone,
/// Embers collected this run and the best height. Rebuilds only when the
/// underlying [HudSnapshot] actually changes (see [HudSnapshot.==]), never
/// once per frame.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.hud, required this.onPause});

  final ValueNotifier<HudSnapshot> hud;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return SafeArea(
      // Top-centered, not centered: a [Center] here would float the whole bar
      // down into the middle of the playfield, on top of the lanes the player
      // is trying to read.
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: LayoutConfig.contentWidth(size),
          ),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: LayoutConfig.textScaler(context, size)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: ValueListenableBuilder<HudSnapshot>(
                valueListenable: hud,
                builder: (context, snapshot, _) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PauseButton(onTap: onPause),
                      const SizedBox(width: 10),
                      // Flexible on both stacks: five-digit heights or a large
                      // system font must shrink the chips, never overflow the
                      // top bar.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _StatChip(
                                label: 'HEIGHT',
                                value: '${snapshot.heightMeters} m',
                                primary: true,
                              ),
                              const SizedBox(height: 4),
                              _RidgeLabel(ridgeNumber: snapshot.ridgeNumber),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _EmbersChip(amount: snapshot.embersThisRun),
                              if (snapshot.comboMultiplier > 1) ...[
                                const SizedBox(height: 4),
                                _ComboBadge(
                                  multiplier: snapshot.comboMultiplier,
                                  streak: snapshot.comboCount,
                                ),
                              ],
                              if (snapshot.shieldCharges > 0) ...[
                                const SizedBox(height: 4),
                                _ShieldBadge(charges: snapshot.shieldCharges),
                              ],
                              const SizedBox(height: 6),
                              _StatChip(
                                label: 'BEST',
                                value: '${snapshot.bestHeightMeters} m',
                                primary: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.38),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          HapticService.instance.light();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: Container(
          // Comfortably above the 44pt minimum touch target, because this is
          // the only button on screen during a run and it is pressed under
          // pressure.
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: const Icon(Icons.pause_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Small chip that appears next to the run's Ember count while the player is
/// on an Ember streak. Reads at a glance ("x2 STREAK 5") and disappears again
/// as soon as the streak breaks, so no permanent HUD real estate is spent on
/// something the player isn't actively earning.
///
/// It punches when the multiplier steps up: that is the moment the streak
/// actually became worth more, and it is easy to miss while watching the lane
/// ahead.
class _ComboBadge extends StatefulWidget {
  const _ComboBadge({required this.multiplier, required this.streak});

  final int multiplier;
  final int streak;

  @override
  State<_ComboBadge> createState() => _ComboBadgeState();
}

class _ComboBadgeState extends State<_ComboBadge>
    with SingleTickerProviderStateMixin {
  static const Color _accent = Color(0xFFFF9640);

  late final AnimationController _punch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void didUpdateWidget(_ComboBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.multiplier != oldWidget.multiplier) {
      _punch.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _punch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _punch, curve: Curves.easeOutBack)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _accent.withValues(alpha: 0.75),
            width: 1.3,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _accent.withValues(alpha: 0.35 * (1 - _punch.value)),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'x${widget.multiplier}',
              style: const TextStyle(
                color: _accent,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'STREAK ${widget.streak}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unspent Stone Shield charges, shown only to players who bought the upgrade.
/// Knowing whether a mistake is still survivable changes how aggressively the
/// player takes a gap, so the count has to be visible rather than remembered.
class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge({required this.charges});

  final int charges;

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFF8FC7FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, color: accent, size: 13),
          const SizedBox(width: 5),
          Text(
            'x$charges',
            style: const TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbersChip extends StatelessWidget {
  const _EmbersChip({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AtlasIcon(
            image: ItemsAtlasService.instance.cell(
              ItemSprites.uiCurrency.row,
              ItemSprites.uiCurrency.col,
            ),
            size: 16,
            fallback: Icons.local_fire_department,
            fallbackColor: const Color(0xFFFFC66B),
          ),
          const SizedBox(width: 6),
          Text(
            '$amount',
            style: const TextStyle(
              color: Color(0xFFFFC66B),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.primary,
  });

  final String label;
  final String value;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: primary ? const Color(0xFFFFC66B) : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RidgeLabel extends StatelessWidget {
  const _RidgeLabel({required this.ridgeNumber});

  final int ridgeNumber;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        'Ridge $ridgeNumber',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
