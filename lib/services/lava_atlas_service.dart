import 'dart:ui' as ui;

import '../rendering/terrain_sprites.dart';
import 'sprite_atlas.dart';

/// Molten lava used to fill dangerous lanes, from the liquid-elements sheet.
class LavaAtlasService {
  LavaAtlasService._();
  static final LavaAtlasService instance = LavaAtlasService._();

  static const int columns = 11;
  static const int rows = 4;

  final SpriteAtlas _atlas = SpriteAtlas(
    assetPath: 'assets/volcanic_liquid_elements_asset.webp',
    columns: columns,
    rows: rows,
    onlyCells: LavaSprites.flatIndices(columns),
  );

  bool get isLoaded => _atlas.isLoaded;

  Future<void> preload() => _atlas.preload();

  ui.Image? sprite(SheetCoord coord) => _atlas.cell(coord.row, coord.col);
}
