import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/relay_models.dart';

/// Persistence for the gray flow: route mode, saved/pending destinations, push
/// consent flags and the invite cooldown.
///
/// Builds up to 1.0.3 wrote a `ridge.relay.*` namespace. [initialize] lifts
/// those values into the current `rdg_*` names once and deletes the originals,
/// so an updating player keeps their route instead of being sent back through
/// the first-launch decision. The legacy names can be deleted from this file
/// once the 1.0.3 install base is gone.
class EmberVault {
  static const String _modeKey = 'rdg_mode';
  static const String _destTtlKey = 'rdg_dest_ttl';
  static const String _nudgeResumeKey = 'rdg_nudge_resume';
  static const String _notifyOkKey = 'rdg_notify_ok';
  static const String _notifyBlockedKey = 'rdg_notify_blocked';
  static const String _destKey = 'rdg_dest';
  static const String _destQueuedKey = 'rdg_dest_queued';

  static const Map<String, String> _legacyPrefs = <String, String>{
    _modeKey: 'ridge.relay.route',
    _destTtlKey: 'ridge.relay.expiry',
    _nudgeResumeKey: 'ridge.relay.invite.after',
    _notifyOkKey: 'ridge.relay.push.allowed',
    _notifyBlockedKey: 'ridge.relay.push.os_denied',
  };

  static const Map<String, String> _legacySecure = <String, String>{
    _destKey: 'ridge.relay.secure.destination',
    _destQueuedKey: 'ridge.relay.secure.pending',
  };

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    await _adoptLegacyEntries();
  }

  /// Copies any pre-1.0.4 entry onto its current key. Never overwrites a value
  /// the app already wrote under the new name.
  Future<void> _adoptLegacyEntries() async {
    for (final entry in _legacyPrefs.entries) {
      if (_preferences.containsKey(entry.key)) continue;
      final Object? carried = _preferences.get(entry.value);
      if (carried == null) continue;
      if (carried is String) {
        await _preferences.setString(entry.key, carried);
      } else if (carried is int) {
        await _preferences.setInt(entry.key, carried);
      } else if (carried is bool) {
        await _preferences.setBool(entry.key, carried);
      }
      await _preferences.remove(entry.value);
    }

    for (final entry in _legacySecure.entries) {
      try {
        if (await _secure.read(key: entry.key) != null) continue;
        final carried = await _secure.read(key: entry.value);
        if (carried == null) continue;
        await _secure.write(key: entry.key, value: carried);
        await _secure.delete(key: entry.value);
      } catch (_) {
        // A locked keychain must never block the boot pipeline.
      }
    }
  }

  RelayRoute get route => RelayRoute.parse(_preferences.getString(_modeKey));

  Future<void> saveRoute(RelayRoute route) =>
      _preferences.setString(_modeKey, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _destKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _destKey, value: url);
      // Fall back to the configured lifetime when the backend omits `expires`
      // so a saved URL never lives forever in secure storage.
      final ttl = expiresAt ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000 +
              const Duration(days: 7).inSeconds;
      await _preferences.setInt(_destTtlKey, ttl);
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_destTtlKey);
    return expiry == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      await _secure.write(key: _destQueuedKey, value: url.trim());
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _destQueuedKey);
      if (value != null) await _secure.delete(key: _destQueuedKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get pushAllowed => _preferences.getBool(_notifyOkKey) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_notifyBlockedKey) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_notifyOkKey, value);

  Future<void> markPushDeniedByOs() =>
      _preferences.setBool(_notifyBlockedKey, true);

  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    final after = _preferences.getInt(_nudgeResumeKey);
    return after == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_nudgeResumeKey, epochSeconds);
}
