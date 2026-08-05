/// Purely cosmetic rarity tiers. They only affect the card border color on
/// the Skins screen - never gameplay, collisions or difficulty.
enum SkinRarity { common, rare, epic, legendary }

/// Static definition of a single skin. The 20 entries mirror the 2x10 atlas
/// grid exactly: [id] 0..19, row-major (top row left-to-right first).
class SkinDefinition {
  const SkinDefinition({
    required this.id,
    required this.name,
    required this.rarity,
    required this.unlockLevel,
  });

  final int id;
  final String name;
  final SkinRarity rarity;

  /// Climber level required to wear this skin. Levels are earned purely by
  /// playing (height + Embers), so this is the game's only progression gate.
  final int unlockLevel;
}

/// The full, fixed skin roster.
class SkinCatalog {
  SkinCatalog._();

  static const List<SkinDefinition> all = <SkinDefinition>[
    // Row 1 — top, left to right
    SkinDefinition(
        id: 0,
        name: 'Jungle Guard',
        rarity: SkinRarity.common,
        unlockLevel: 1),
    SkinDefinition(
        id: 1,
        name: 'Frost Walker',
        rarity: SkinRarity.common,
        unlockLevel: 1),
    SkinDefinition(
        id: 2,
        name: 'Magma Blazer',
        rarity: SkinRarity.rare,
        unlockLevel: 8),
    SkinDefinition(
        id: 3,
        name: 'Shadow Shade',
        rarity: SkinRarity.epic,
        unlockLevel: 21),
    SkinDefinition(
        id: 4,
        name: 'Ember Monk',
        rarity: SkinRarity.common,
        unlockLevel: 2),
    SkinDefinition(
        id: 5,
        name: 'Iron Sentinel',
        rarity: SkinRarity.common,
        unlockLevel: 3),
    SkinDefinition(
        id: 6,
        name: 'Flame Forge',
        rarity: SkinRarity.rare,
        unlockLevel: 10),
    SkinDefinition(
        id: 7,
        name: 'Frost Sage',
        rarity: SkinRarity.rare,
        unlockLevel: 12),
    SkinDefinition(
        id: 8,
        name: 'Stone Warden',
        rarity: SkinRarity.common,
        unlockLevel: 4),
    SkinDefinition(
        id: 9,
        name: 'Pyro Scout',
        rarity: SkinRarity.common,
        unlockLevel: 5),
    // Row 2 — bottom, left to right
    SkinDefinition(
        id: 10,
        name: 'Ridge Keeper',
        rarity: SkinRarity.common,
        unlockLevel: 6),
    SkinDefinition(
        id: 11,
        name: 'Deep Scout',
        rarity: SkinRarity.common,
        unlockLevel: 7),
    SkinDefinition(
        id: 12,
        name: 'Specter',
        rarity: SkinRarity.epic,
        unlockLevel: 24),
    SkinDefinition(
        id: 13,
        name: 'Inferno Lord',
        rarity: SkinRarity.epic,
        unlockLevel: 27),
    SkinDefinition(
        id: 14,
        name: 'Iron Golem',
        rarity: SkinRarity.rare,
        unlockLevel: 14),
    SkinDefinition(
        id: 15,
        name: 'Bone Warden',
        rarity: SkinRarity.epic,
        unlockLevel: 30),
    SkinDefinition(
        id: 16,
        name: 'Lava Brawler',
        rarity: SkinRarity.rare,
        unlockLevel: 16),
    SkinDefinition(
        id: 17,
        name: 'Silver Knight',
        rarity: SkinRarity.rare,
        unlockLevel: 18),
    SkinDefinition(
        id: 18,
        name: 'Ridge Wanderer',
        rarity: SkinRarity.common,
        unlockLevel: 8),
    SkinDefinition(
        id: 19,
        name: 'Pyro Lord',
        rarity: SkinRarity.legendary,
        unlockLevel: 40),
  ];

  static SkinDefinition byId(int id) =>
      all[id.clamp(0, all.length - 1).toInt()];

  static bool isUnlocked(SkinDefinition skin, int level) =>
      level >= skin.unlockLevel;
}
