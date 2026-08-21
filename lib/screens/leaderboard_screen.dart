import 'package:flutter/material.dart';

import '../models/progression.dart';
import '../services/progress_service.dart';
import '../widgets/menu_scaffold.dart';
import '../widgets/progress_badges.dart';

/// A fixed roster of rival climbers the player is ranked against. These are
/// part of the offline content, not real players - the screen says so out
/// loud rather than pretending to be an online service.
const List<_Rival> _rivals = <_Rival>[
  _Rival('Vareth the Ashborn', 3120),
  _Rival('Kel Ironstep', 2705),
  _Rival('Sunna Emberwake', 2340),
  _Rival('Torvin Cragg', 1980),
  _Rival('Mira of the Vents', 1655),
  _Rival('Hadd Coalhand', 1390),
  _Rival('Oskar Slagfoot', 1120),
  _Rival('Nim Cinderpaw', 880),
  _Rival('Brann Two-Ropes', 640),
  _Rival('Ysolde Fume', 430),
  _Rival('Pell the Unsteady', 260),
  _Rival('Doro Firstfall', 120),
];

class _Rival {
  const _Rival(this.name, this.meters);
  final String name;
  final int meters;
}

/// Two rankings: the player's own best climbs, and where their record would
/// place them among the mountain's legendary climbers.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      title: 'RANKING',
      trailing: const EmbersBadge(),
      child: AnimatedBuilder(
        animation: ProgressService.instance,
        builder: (context, _) {
          final ProgressService progress = ProgressService.instance;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              const _SectionTitle('YOUR BEST CLIMBS'),
              const SizedBox(height: 8),
              if (progress.scores.isEmpty)
                const _EmptyHint()
              else
                for (int i = 0; i < progress.scores.length; i++)
                  _Row(
                    rank: i + 1,
                    name: _dateLabel(progress.scores[i]),
                    meters: progress.scores[i].meters,
                    highlight: i == 0,
                  ),
              const SizedBox(height: 22),
              const _SectionTitle('RIDGE LEGENDS'),
              const SizedBox(height: 4),
              Text(
                'Offline roster - your record is placed among them.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 8),
              _NextRivalHint(
                rival: _nextRival(progress.bestHeightMeters),
                playerBest: progress.bestHeightMeters,
              ),
              const SizedBox(height: 10),
              ..._buildRivalRows(progress.bestHeightMeters),
            ],
          );
        },
      ),
    );
  }

  /// The closest rival still ahead of [playerBest], or null once the player
  /// has climbed past every name on the roster.
  static _Rival? _nextRival(int playerBest) {
    final List<_Rival> ahead =
        _rivals.where((rival) => rival.meters > playerBest).toList()
          ..sort((a, b) => a.meters.compareTo(b.meters));
    return ahead.isEmpty ? null : ahead.first;
  }

  List<Widget> _buildRivalRows(int playerBest) {
    final List<_Rival> combined = <_Rival>[
      ..._rivals,
      _Rival('YOU', playerBest),
    ]..sort((a, b) => b.meters.compareTo(a.meters));

    return <Widget>[
      for (int i = 0; i < combined.length; i++)
        _Row(
          rank: i + 1,
          name: combined[i].name,
          meters: combined[i].meters,
          highlight: combined[i].name == 'YOU',
        ),
    ];
  }

  static String _dateLabel(ScoreEntry entry) {
    final DateTime d = entry.achievedAt;
    final String day = d.day.toString().padLeft(2, '0');
    final String month = d.month.toString().padLeft(2, '0');
    return '$day.$month.${d.year}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: kAccent,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// "N m to pass NAME" - or a leading banner once nobody on the roster is
/// left ahead. Gives the ranking a next concrete target instead of just a
/// static list to glance at.
class _NextRivalHint extends StatelessWidget {
  const _NextRivalHint({required this.rival, required this.playerBest});

  final _Rival? rival;
  final int playerBest;

  @override
  Widget build(BuildContext context) {
    final _Rival? r = rival;
    final String label = r == null
        ? 'You lead the ridge - nobody left to pass.'
        : '${r.meters - playerBest} m to pass ${r.name}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: kAccentHot.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(
            r == null ? Icons.emoji_events : Icons.arrow_upward_rounded,
            color: kAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        'Finish a climb to open your table.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.name,
    required this.meters,
    required this.highlight,
  });

  final int rank;
  final String name;
  final int meters;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: highlight ? 0.5 : 0.3),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: highlight
              ? kAccent.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.1),
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              style: TextStyle(
                color: highlight ? kAccent : Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: highlight ? Colors.white : Colors.white70,
                fontSize: 13.5,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$meters m',
            style: TextStyle(
              color: highlight ? kAccent : Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
