/// Named (row, column) coordinates into the items atlas (4 rows x 10
/// columns, 1-indexed).
class ItemCoord {
  const ItemCoord(this.row, this.col);
  final int row;
  final int col;
}

class ItemSprites {
  ItemSprites._();

  // --- Collectibles ---------------------------------------------------------
  static const List<ItemCoord> shard = <ItemCoord>[
    ItemCoord(1, 9), // glowing lava nugget
    ItemCoord(3, 6), // small molten stone
  ];
  static const List<ItemCoord> gem = <ItemCoord>[
    ItemCoord(1, 2), // faceted red gem
    ItemCoord(3, 10), // teardrop gem
    ItemCoord(4, 3), // fire orb
  ];
  static const List<ItemCoord> crystal = <ItemCoord>[
    ItemCoord(1, 1), // red crystal cluster
    ItemCoord(1, 3), // dark crystal cluster
    ItemCoord(3, 5), // violet crystal cluster
  ];
  static const ItemCoord chest = ItemCoord(2, 8);
  static const ItemCoord heart = ItemCoord(2, 3);

  // Note: the pickup "collect blip" flash reuses VfxSprites.impactFireBurst
  // ((1,9)/(5,3) in the VFX atlas) - not a separate items sprite.

  // --- UI icons -------------------------------------------------------------
  static const ItemCoord uiCurrency = ItemCoord(1, 10); // flame coin
  static const ItemCoord uiSkinsButton = ItemCoord(3, 4); // gold mask
  static const ItemCoord uiGoals = ItemCoord(2, 7); // compass
  static const ItemCoord uiLeaderboard = ItemCoord(4, 9); // winged emblem
  static const ItemCoord uiDaily = ItemCoord(2, 8); // chest
  static const ItemCoord uiHowToPlay = ItemCoord(2, 9); // rune stone
  static const ItemCoord uiSettings = ItemCoord(2, 2); // mechanical disc
  static const ItemCoord uiLevel = ItemCoord(4, 5); // crowned helm
  static const ItemCoord uiSkull = ItemCoord(4, 7); // Game Over / danger
  static const ItemCoord uiTitleEmblem = ItemCoord(1, 6); // star amulet
  static const ItemCoord uiHeight = ItemCoord(3, 8); // molten sphere
  static const ItemCoord uiShop = ItemCoord(4, 10); // gilded cog

  // --- Upgrade tracks -------------------------------------------------------
  static const ItemCoord upgradeShield = ItemCoord(4, 1); // domed stone shell
  static const ItemCoord upgradeMagnet = ItemCoord(2, 5); // spiral fossil
  static const ItemCoord upgradeCombo = ItemCoord(4, 2); // labyrinth tablet
  static const ItemCoord upgradeEmber = ItemCoord(1, 7); // glowing ore egg
  static const ItemCoord upgradeXp = ItemCoord(3, 7); // eruption medallion
}
