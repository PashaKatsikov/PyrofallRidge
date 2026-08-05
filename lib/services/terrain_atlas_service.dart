import 'dart:ui' as ui;

import '../rendering/terrain_sprites.dart';
import 'sprite_atlas.dart';

/// Carved stone terrain: safe floors, landed platforms and boulder bodies.
///
/// Only the cells [TerrainSprites] actually names are materialized - the
/// sheet holds 65 of them and the game uses a fraction.
class TerrainAtlasService {
  TerrainAtlasService._();
  static final TerrainAtlasService instance = TerrainAtlasService._();

  static const int columns = 13;
  static const int rows = 5;

  final SpriteAtlas _atlas = SpriteAtlas(
    assetPath: 'assets/volcanic_solid_objects_asset.webp',
    columns: columns,
    rows: rows,
    onlyCells: TerrainSprites.flatIndices(columns),
  );

  bool get isLoaded => _atlas.isLoaded;

  Future<void> preload() => _atlas.preload();

  ui.Image? sprite(SheetCoord coord) => _atlas.cell(coord.row, coord.col);
}
