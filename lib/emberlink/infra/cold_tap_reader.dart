import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads (and clears) the cold-start push URL that `SceneDelegate` wrote to
/// UserDefaults when the app was launched by a notification tap. The key must
/// stay in sync with `SceneDelegate.launchRouteKey` (`flutter.` prefix bridges
/// UserDefaults ↔ SharedPreferences).
class ColdTapReader {
  static const String _key = 'ridge_launch_route';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_key)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(_key);
      return value;
    } catch (_) {
      return null;
    }
  }
}
