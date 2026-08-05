import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// Holds the currently selected skin id and persists it.
///
/// A single app-wide instance (mirroring how [SkinAtlasService] is a
/// singleton too) so the Skins screen, the Ready overlay and the in-game
/// [GamePainter] all observe the exact same selection without any extra
/// dependency-injection package.
class SkinManager extends ChangeNotifier {
  SkinManager._();
  static final SkinManager instance = SkinManager._();

  final StorageService _storage = StorageService();

  int _selectedSkinId = 0;
  int get selectedSkinId => _selectedSkinId;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _selectedSkinId = await _storage.loadSelectedSkinId();
  }

  Future<void> selectSkin(int id) async {
    if (id == _selectedSkinId) return;
    _selectedSkinId = id;
    notifyListeners();
    await _storage.saveSelectedSkinId(id);
  }
}
