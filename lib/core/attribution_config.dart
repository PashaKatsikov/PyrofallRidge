/// Credentials for the AppsFlyer install-attribution integration.
///
/// This is purely measurement: it tells the AppsFlyer dashboard, and the
/// [AttributionService] getters, whether a given install came from a paid
/// OneLink/ad click ("Non-organic") or was found and downloaded directly
/// from the App Store ("Organic"). Nothing in the app's behavior, screens or
/// content ever branches on this value.
class AttributionConfig {
  AttributionConfig._();

  /// AppsFlyer dashboard -> App settings -> Dev key.
  ///
  /// An empty key makes [AttributionService] skip initialization entirely
  /// rather than crash or send bad data.
  static const String devKey = 'StJHsc3mzoZt8aVL3CLqEf';

  /// Numeric App Store id (e.g. "1234567890"), once the app is created in
  /// App Store Connect. Only used on iOS.
  static const String iosAppId = '6792835699';

  static bool get isConfigured => devKey.isNotEmpty;
}
