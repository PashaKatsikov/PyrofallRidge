import 'dart:ui' as ui;

import 'sprite_atlas.dart';

/// VFX sprite atlas: rocks, explosions, smoke, lava splashes and shockwave
/// rings on a 5-row x 12-column grid. Cells are addressed directly by
/// (row, column), 1-indexed, matching the art-direction sheet.
class VfxAtlasService {
  VfxAtlasService._();
  static final VfxAtlasService instance = VfxAtlasService._();

  static const int columns = 12;
  static const int rows = 5;

  final SpriteAtlas _atlas = SpriteAtlas(
    assetPath: 'assets/vfx/vfx_atlas.png',
    columns: columns,
    rows: rows,
  );

  bool get isLoaded => _atlas.isLoaded;

  Future<void> preload() => _atlas.preload();

  /// [row]/[col] are 1-indexed. Returns null if not loaded yet/failed -
  /// callers must fall back to a primitive shape in that case.
  ui.Image? cell(int row, int col) => _atlas.cell(row, col);
}
