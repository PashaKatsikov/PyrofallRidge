/// 1-indexed (row, column) coordinate into a sprite sheet grid.
class SheetCoord {
  const SheetCoord(this.row, this.col);
  final int row;
  final int col;
}

/// Cells used from the solid-objects sheet (13 columns x 5 rows).
///
/// The two floor entries are *tiles*: they are repeated across a lane at their
/// own aspect ratio (see `GamePainter._drawTiled`), never stretched to fit a
/// cell, so the ground reads as one continuous surface however tall the run of
/// cells happens to be. Everything else is a free-standing object drawn
/// aspect-fit.
class TerrainSprites {
  TerrainSprites._();

  /// The basalt brickwork every safe lane is paved with. Deliberately the
  /// coolest, flattest stone on the sheet: safe ground must never read as hot,
  /// and a busy tile would fight the player silhouette on top of it.
  static const SheetCoord floorTile = SheetCoord(2, 3);

  /// Worked stone of a platform left behind by a landed hazard - visibly
  /// different masonry from [floorTile] so a bridge over lava is obvious.
  static const SheetCoord platformTile = SheetCoord(2, 7);

  /// Plain grey boulders: rockfall in flight, and the rock left resting on the
  /// platform it created.
  static const List<SheetCoord> rockfallBody = <SheetCoord>[
    SheetCoord(1, 6),
    SheetCoord(1, 11),
    SheetCoord(1, 12),
  ];

  /// Lava-veined boulders for meteors, hot enough to read as the deadlier of
  /// the two hazards at a glance.
  static const List<SheetCoord> meteorBody = <SheetCoord>[
    SheetCoord(1, 1),
    SheetCoord(1, 2),
    SheetCoord(1, 4),
    SheetCoord(1, 5),
  ];

  static const List<SheetCoord> _singles = <SheetCoord>[
    floorTile,
    platformTile,
  ];

  static const List<List<SheetCoord>> _groups = <List<SheetCoord>>[
    rockfallBody,
    meteorBody,
  ];

  static Set<int> flatIndices(int columns) => <int>{
        for (final c in _singles) (c.row - 1) * columns + (c.col - 1),
        for (final group in _groups)
          for (final c in group) (c.row - 1) * columns + (c.col - 1),
      };
}

/// Cells used from the liquid-elements sheet (11 columns x 4 rows): the lava
/// that fills every dangerous lane.
class LavaSprites {
  LavaSprites._();

  /// Crust-and-magma tile repeated across a dangerous lane.
  static const SheetCoord lavaTile = SheetCoord(2, 1);

  static Set<int> flatIndices(int columns) => <int>{
        (lavaTile.row - 1) * columns + (lavaTile.col - 1),
      };
}
