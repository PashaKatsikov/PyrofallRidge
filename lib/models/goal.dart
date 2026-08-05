/// Which tracked statistic a goal measures.
enum GoalMetric {
  bestHeight,
  embersCollected,
  runsPlayed,
  level,
  bestRunEmbers,
}

/// A single long-term objective: what to do, how far along the player is and
/// what claiming it pays out in Embers.
class GoalDefinition {
  const GoalDefinition({
    required this.id,
    required this.title,
    required this.metric,
    required this.target,
    required this.rewardEmbers,
  });

  final String id;
  final String title;
  final GoalMetric metric;
  final int target;
  final int rewardEmbers;
}

class GoalCatalog {
  GoalCatalog._();

  static const List<GoalDefinition> all = <GoalDefinition>[
    GoalDefinition(
      id: 'height_100',
      title: 'Climb 100 m',
      metric: GoalMetric.bestHeight,
      target: 100,
      rewardEmbers: 25,
    ),
    GoalDefinition(
      id: 'height_300',
      title: 'Climb 300 m',
      metric: GoalMetric.bestHeight,
      target: 300,
      rewardEmbers: 60,
    ),
    GoalDefinition(
      id: 'height_600',
      title: 'Climb 600 m',
      metric: GoalMetric.bestHeight,
      target: 600,
      rewardEmbers: 120,
    ),
    GoalDefinition(
      id: 'height_1000',
      title: 'Climb 1000 m',
      metric: GoalMetric.bestHeight,
      target: 1000,
      rewardEmbers: 250,
    ),
    GoalDefinition(
      id: 'embers_100',
      title: 'Collect 100 Embers',
      metric: GoalMetric.embersCollected,
      target: 100,
      rewardEmbers: 40,
    ),
    GoalDefinition(
      id: 'embers_500',
      title: 'Collect 500 Embers',
      metric: GoalMetric.embersCollected,
      target: 500,
      rewardEmbers: 100,
    ),
    GoalDefinition(
      id: 'embers_2000',
      title: 'Collect 2000 Embers',
      metric: GoalMetric.embersCollected,
      target: 2000,
      rewardEmbers: 300,
    ),
    GoalDefinition(
      id: 'run_embers_60',
      title: 'Collect 60 Embers in one climb',
      metric: GoalMetric.bestRunEmbers,
      target: 60,
      rewardEmbers: 120,
    ),
    GoalDefinition(
      id: 'runs_10',
      title: 'Finish 10 climbs',
      metric: GoalMetric.runsPlayed,
      target: 10,
      rewardEmbers: 50,
    ),
    GoalDefinition(
      id: 'runs_50',
      title: 'Finish 50 climbs',
      metric: GoalMetric.runsPlayed,
      target: 50,
      rewardEmbers: 150,
    ),
    GoalDefinition(
      id: 'level_5',
      title: 'Reach level 5',
      metric: GoalMetric.level,
      target: 5,
      rewardEmbers: 80,
    ),
    GoalDefinition(
      id: 'level_15',
      title: 'Reach level 15',
      metric: GoalMetric.level,
      target: 15,
      rewardEmbers: 200,
    ),
  ];
}
