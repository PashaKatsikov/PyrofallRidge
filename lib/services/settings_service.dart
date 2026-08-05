import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// How much cosmetic VFX the game is allowed to spawn. Purely visual - it
/// never changes hitboxes, spawn fairness or difficulty.
enum EffectsQuality { full, reduced, off }

extension EffectsQualityX on EffectsQuality {
  String get label {
    switch (this) {
      case EffectsQuality.full:
        return 'FULL';
      case EffectsQuality.reduced:
        return 'REDUCED';
      case EffectsQuality.off:
        return 'OFF';
    }
  }

  /// Multiplier applied to the VFX budget.
  double get vfxBudgetFactor {
    switch (this) {
      case EffectsQuality.full:
        return 1.0;
      case EffectsQuality.reduced:
        return 0.5;
      case EffectsQuality.off:
        return 0.0;
    }
  }
}

/// App-wide player preferences, kept as a single observable instance so the
/// menus, the [VfxManager] and the [GamePainter] all read the same values.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  final StorageService _storage = StorageService();

  EffectsQuality _effects = EffectsQuality.full;
  EffectsQuality get effects => _effects;

  bool _showBackgrounds = true;
  bool get showBackgrounds => _showBackgrounds;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final int index = await _storage.loadEffectsQuality();
    _effects = EffectsQuality
        .values[index.clamp(0, EffectsQuality.values.length - 1).toInt()];
    _showBackgrounds = await _storage.loadShowBackgrounds();
    notifyListeners();
  }

  Future<void> setEffects(EffectsQuality value) async {
    if (value == _effects) return;
    _effects = value;
    notifyListeners();
    await _storage.saveEffectsQuality(value.index);
  }

  Future<void> setShowBackgrounds(bool value) async {
    if (value == _showBackgrounds) return;
    _showBackgrounds = value;
    notifyListeners();
    await _storage.saveShowBackgrounds(value);
  }
}
