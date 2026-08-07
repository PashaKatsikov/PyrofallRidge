import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'storage_service.dart';

/// Taptic feedback, centralised so it can be switched off in Settings and
/// rate-limited as a whole.
///
/// On iOS the Taptic Engine ignores requests that arrive too close together,
/// but issuing them still costs a platform channel round trip - and a climb
/// can easily produce a dozen candidate events a second - so every call goes
/// through one throttle.
class HapticService extends ChangeNotifier {
  HapticService._();

  static final HapticService instance = HapticService._();

  /// Below this gap the engine would either coalesce or drop the second tap
  /// anyway, so we save the channel hop.
  static const int _minGapMs = 55;

  final StorageService _storage = StorageService();

  bool _enabled = true;
  bool get enabled => _enabled;

  int _lastFiredMs = 0;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _enabled = await _storage.loadHapticsEnabled();
  }

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    if (value) selection();
    await _storage.saveHapticsEnabled(value);
  }

  /// A lane change, a menu selection: the lightest tick available.
  void selection() => _fire(HapticFeedback.selectionClick);

  /// Collecting an Ember, tapping a button.
  void light() => _fire(HapticFeedback.lightImpact);

  /// A combo step, a platform forming under the player.
  void medium() => _fire(HapticFeedback.mediumImpact);

  /// A meteor landing, a shield absorbing a hit.
  void heavy() => _fire(HapticFeedback.heavyImpact);

  /// Death. Bypasses the throttle - it is the single most important piece of
  /// feedback in the game and always fires alone.
  void death() {
    if (!_enabled) return;
    _lastFiredMs = DateTime.now().millisecondsSinceEpoch;
    HapticFeedback.heavyImpact();
  }

  void _fire(Future<void> Function() effect) {
    if (!_enabled) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFiredMs < _minGapMs) return;
    _lastFiredMs = now;
    effect();
  }
}
