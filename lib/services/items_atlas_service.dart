import 'dart:ui' as ui;

import 'sprite_atlas.dart';

/// Items sprite atlas: crystals, coins, amulets, chest, heart etc. on a
/// 4-row x 10-column grid. Cells are addressed directly by (row, column),
/// 1-indexed, matching the art-direction sheet.
class ItemsAtlasService {
  ItemsAtlasService._();
  static final ItemsAtlasService instance = ItemsAtlasService._();

  static const int columns = 10;
  static const int rows = 4;

  final SpriteAtlas _atlas = SpriteAtlas(
    assetPath: 'assets/items/items_atlas.png',
    columns: columns,
    rows: rows,
    maxCellSize: 144,
  );

  bool get isLoaded => _atlas.isLoaded;

  Future<void> preload() => _atlas.preload();

  /// [row]/[col] are 1-indexed. Returns null if not loaded yet/failed -
  /// callers must fall back to a primitive shape in that case.
  ui.Image? cell(int row, int col) => _atlas.cell(row, col);
}
