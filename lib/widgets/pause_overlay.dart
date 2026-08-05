import 'package:flutter/material.dart';

import 'menu_tile.dart';
import 'progress_badges.dart';

/// Shown while [GamePhase.paused]: the simulation is frozen and the player
/// can resume, start over, or leave for the main menu.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.62),
      child: SafeArea(
        child: Center(
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
              const SizedBox(height: 26),
              PrimaryButton(label: 'RESUME', width: 210, onTap: onResume),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'RESTART',
                icon: Icons.refresh,
                filled: false,
                width: 210,
                onTap: onRestart,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'MAIN MENU',
                icon: Icons.home_rounded,
                filled: false,
                width: 210,
                onTap: onExit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
