import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/hud_snapshot.dart';
import '../rendering/item_sprites.dart';
import '../services/items_atlas_service.dart';
import 'atlas_icon.dart';
import 'menu_tile.dart';
import 'progress_badges.dart';

/// Shown while [GamePhase.paused]: the simulation is frozen and the player
/// can resume, start over, or leave for the main menu.
///
/// The frozen world stays visible but is blurred and dimmed, so the pause reads
/// as "the climb is waiting for you" rather than as a separate screen the run
/// was thrown away for.
class PauseOverlay extends StatefulWidget {
  const PauseOverlay({
    super.key,
    required this.hud,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  final ValueNotifier<HudSnapshot> hud;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<PauseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation eased =
        CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: eased,
      builder: (context, child) => BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 6 * eased.value,
          sigmaY: 6 * eased.value,
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.62 * eased.value),
          child: child,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: eased,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(eased),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'PAUSED',
                    style: TextStyle(
                      color: kAccent,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ValueListenableBuilder<HudSnapshot>(
                    valueListenable: widget.hud,
                    builder: (context, snapshot, _) =>
                        _PauseStatsRow(snapshot: snapshot),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(label: 'RESUME', width: 210, onTap: widget.onResume),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'RESTART',
                    icon: Icons.refresh,
                    filled: false,
                    width: 210,
                    onTap: widget.onRestart,
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'MAIN MENU',
                    icon: Icons.home_rounded,
                    filled: false,
                    width: 210,
                    onTap: widget.onExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Current-run height and Embers, plus the standing best height, shown while
/// paused so the decision to resume or bail is made with the run's actual
/// stakes in view rather than from memory.
class _PauseStatsRow extends StatelessWidget {
  const _PauseStatsRow({required this.snapshot});

  final HudSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Stat(label: 'HEIGHT', value: '${snapshot.heightMeters} m'),
            _Divider(),
            _Stat.icon(
              label: 'EMBERS',
              value: '${snapshot.embersThisRun}',
              icon: ItemsAtlasService.instance.cell(
                  ItemSprites.uiCurrency.row, ItemSprites.uiCurrency.col),
            ),
            _Divider(),
            _Stat(label: 'BEST', value: '${snapshot.bestHeightMeters} m'),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.white.withValues(alpha: 0.15),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value}) : icon = null;

  const _Stat.icon({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final ui.Image? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AtlasIcon(
                image: icon,
                size: 14,
                fallback: Icons.local_fire_department,
                fallbackColor: kAccent,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
