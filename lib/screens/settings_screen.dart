import 'package:flutter/material.dart';

import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../services/skin_manager.dart';
import '../widgets/legal_links_row.dart';
import '../widgets/menu_scaffold.dart';
import '../widgets/progress_badges.dart';

/// Player-facing options. Both toggles are purely visual/performance related -
/// nothing here changes difficulty, hitboxes or spawn fairness.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      title: 'SETTINGS',
      child: AnimatedBuilder(
        animation: SettingsService.instance,
        builder: (context, _) {
          final SettingsService settings = SettingsService.instance;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
            children: [
              _Card(
                title: 'EFFECTS',
                subtitle: 'How much smoke, fire and debris is drawn.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final EffectsQuality quality in EffectsQuality.values)
                      _Choice(
                        label: quality.label,
                        selected: settings.effects == quality,
                        onTap: () => settings.setEffects(quality),
                      ),
                  ],
                ),
              ),
              _Card(
                title: 'LOCATION ART',
                subtitle:
                    'Painted backgrounds behind the climb. Turn off on a slow '
                    'device for a plain gradient.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Choice(
                      label: 'ON',
                      selected: settings.showBackgrounds,
                      onTap: () => settings.setShowBackgrounds(true),
                    ),
                    _Choice(
                      label: 'OFF',
                      selected: !settings.showBackgrounds,
                      onTap: () => settings.setShowBackgrounds(false),
                    ),
                  ],
                ),
              ),
              _Card(
                title: 'PROGRESS',
                subtitle:
                    'Level, Embers, records, goals and the daily streak are '
                    'stored only on this device.',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _DangerButton(
                    label: 'RESET PROGRESS',
                    onTap: () => _confirmReset(context),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const LegalLinksRow(),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Pyrofall Ridge 1.0.0 - plays fully offline',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1118),
        title: const Text('Reset progress?'),
        content: const Text(
          'Level, Embers, best height, score table, goals and the daily '
          'streak will all be erased. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('RESET', style: TextStyle(color: kAccentHot)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ProgressService.instance.resetProgress();
    // Level 1 only unlocks the starter skins, so drop back to the first one
    // rather than leaving the player wearing something now locked.
    await SkinManager.instance.selectSkin(0);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progress reset'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kAccent,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? kAccent
                  : Colors.white.withValues(alpha: 0.18),
              width: selected ? 1.6 : 1.1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? kAccent : Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: kAccentHot.withValues(alpha: 0.7), width: 1.3),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: kAccentHot,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
        ),
      ),
    );
  }
}
