import '../rendering/item_sprites.dart';

/// The permanent upgrades the player can buy with Embers.
///
/// Everything here is bought with soft currency earned by playing; there is no
/// real-money purchase anywhere in the game.
enum UpgradeId { shield, magnet, comboWindow, emberValue, xpBoost }

/// A single purchasable upgrade track.
///
/// Levels are 0-based (0 = not bought yet) and [costs] holds the Ember price of
/// each individual step, so `costs.length` *is* the maximum level. Prices are
/// listed explicitly rather than derived from a formula because they are
/// balance numbers that get hand-tuned per track.
class UpgradeDefinition {
  const UpgradeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.effectPerLevel,
    required this.costs,
    required this.sprite,
  });

  final UpgradeId id;
  final String name;

  /// Player-facing explanation of what the track does overall.
  final String description;

  /// Human-readable size of one step, e.g. "+15% к номиналу".
  final String effectPerLevel;

  final List<int> costs;
  final ItemCoord sprite;

  int get maxLevel => costs.length;

  /// Ember price to go from [level] to `level + 1`, or null when maxed.
  int? costToUpgrade(int level) =>
      level >= maxLevel ? null : costs[level];
}

class UpgradeCatalog {
  const UpgradeCatalog._();

  static const List<UpgradeDefinition> all = <UpgradeDefinition>[
    UpgradeDefinition(
      id: UpgradeId.shield,
      name: 'STONE SHIELD',
      description: 'A lethal hit no longer ends the climb. One charge is spent '
          'and you get a second and a half of immunity to reach safe ground.',
      effectPerLevel: '+1 charge per run',
      costs: <int>[150, 400, 900],
      sprite: ItemSprites.upgradeShield,
    ),
    UpgradeDefinition(
      id: UpgradeId.magnet,
      name: 'HEAT MAGNET',
      description: 'Embers are picked up from further away, so keeping a '
          'collection streak alive costs you less of a detour.',
      effectPerLevel: 'wider pickup reach',
      costs: <int>[80, 180, 320, 520],
      sprite: ItemSprites.upgradeMagnet,
    ),
    UpgradeDefinition(
      id: UpgradeId.comboWindow,
      name: 'COMBO MEMORY',
      description: 'Your streak survives longer between Embers, so a bare '
          'stretch of ridge no longer wipes the multiplier.',
      effectPerLevel: '+0.4s streak window',
      costs: <int>[100, 220, 400, 640],
      sprite: ItemSprites.upgradeCombo,
    ),
    UpgradeDefinition(
      id: UpgradeId.emberValue,
      name: 'RICH VEIN',
      description: 'Every Ember you collect is worth more.',
      effectPerLevel: '+15% Ember value',
      costs: <int>[120, 260, 460, 720],
      sprite: ItemSprites.upgradeEmber,
    ),
    UpgradeDefinition(
      id: UpgradeId.xpBoost,
      name: 'SEASONED CLIMBER',
      description: 'Runs award more experience, so levels (and the skins they '
          'unlock) come faster.',
      effectPerLevel: '+10% run XP',
      costs: <int>[110, 240, 430, 680],
      sprite: ItemSprites.upgradeXp,
    ),
  ];

  static UpgradeDefinition byId(UpgradeId id) =>
      all.firstWhere((UpgradeDefinition u) => u.id == id);
}
