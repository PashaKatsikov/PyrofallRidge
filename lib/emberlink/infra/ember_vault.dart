import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/relay_models.dart';

/// Persistence for the gray flow: route mode, saved/pending destinations, push
/// consent flags and the invite cooldown. Prefix `ridge.relay.*` is unique to
/// this project.
class EmberVault {
  static const String _routeKey = 'ridge.relay.route';
  static const String _expiryKey = 'ridge.relay.expiry';
  static const String _inviteKey = 'ridge.relay.invite.after';
  static const String _permissionKey = 'ridge.relay.push.allowed';
  static const String _osDeniedKey = 'ridge.relay.push.os_denied';
  static const String _savedUrlKey = 'ridge.relay.secure.destination';
  static const String _pendingUrlKey = 'ridge.relay.secure.pending';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  RelayRoute get route => RelayRoute.parse(_preferences.getString(_routeKey));

  Future<void> saveRoute(RelayRoute route) =>
      _preferences.setString(_routeKey, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _savedUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _savedUrlKey, value: url);
      // Fall back to the configured lifetime when the backend omits `expires`
      // so a saved URL never lives forever in secure storage.
      final ttl = expiresAt ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000 +
              const Duration(days: 7).inSeconds;
      await _preferences.setInt(_expiryKey, ttl);
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_expiryKey);
    return expiry == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      await _secure.write(key: _pendingUrlKey, value: url.trim());
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _pendingUrlKey);
      if (value != null) await _secure.delete(key: _pendingUrlKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get pushAllowed => _preferences.getBool(_permissionKey) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_osDeniedKey) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_permissionKey, value);

  Future<void> markPushDeniedByOs() => _preferences.setBool(_osDeniedKey, true);

  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    final after = _preferences.getInt(_inviteKey);
    return after == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_inviteKey, epochSeconds);
}
