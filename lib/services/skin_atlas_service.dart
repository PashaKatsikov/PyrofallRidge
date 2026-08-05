import 'dart:ui' as ui;

import 'sprite_atlas.dart';

/// Skin sprite atlas service.
///
/// Maintains two separate atlases for the same 20 skins:
///  * [_uiAtlas]     — front-facing art used on the Skins selection screen.
///  * [_inGameAtlas] — back/side-facing art rendered on the player character
///                     during a run (the climber "walking away" into the ridge).
///
/// Both share the same 2-row × 10-column grid layout and the same [SpriteAtlas]
/// slicing pipeline; callers pick which view they need via [imageForSkin] (UI)
/// or [imageForSkinInGame] (painter).
class SkinAtlasService {
  SkinAtlasService._();
  static final SkinAtlasService instance = SkinAtlasService._();

  static const int columns = 10;
  static const int rows = 2;
  static const int skinCount = columns * rows;

  /// Front-facing sprites shown in the Skins screen.
  final SpriteAtlas _uiAtlas = SpriteAtlas(
    assetPath: 'assets/skins/skins_atlas.png',
    columns: columns,
    rows: rows,
    mirrorX: false,
    maxCellSize: 256,
  );

  /// Back/side-facing sprites rendered on the in-game player character.
  final SpriteAtlas _inGameAtlas = SpriteAtlas(
    assetPath: 'assets/skins/skins_ingame_atlas.png',
    columns: columns,
    rows: rows,
    mirrorX: false,
    maxCellSize: 256,
  );

  bool get isLoaded => _uiAtlas.isLoaded && _inGameAtlas.isLoaded;

  Future<void> preload() async {
    await Future.wait(<Future<void>>[
      _uiAtlas.preload(),
      _inGameAtlas.preload(),
    ]);
  }

  /// Front-facing sprite for [skinId] — used by the Skins screen.
  ui.Image? imageForSkin(int skinId) {
    if (skinId < 0 || skinId >= skinCount) return null;
    final int row = skinId ~/ columns + 1;
    final int col = skinId % columns + 1;
    return _uiAtlas.cell(row, col);
  }

  /// Back/side-facing sprite for [skinId] — used by the in-game painter.
  ui.Image? imageForSkinInGame(int skinId) {
    if (skinId < 0 || skinId >= skinCount) return null;
    final int row = skinId ~/ columns + 1;
    final int col = skinId % columns + 1;
    return _inGameAtlas.cell(row, col);
  }
}
