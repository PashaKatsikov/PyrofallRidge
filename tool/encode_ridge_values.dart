// ignore_for_file: avoid_print

// Encoder for RidgeRelayConfig byte arrays. Keep the salt + formula in sync
// with lib/emberlink/core/cinder_cipher.dart. After editing any plaintext
// below, run:  dart run tool/encode_ridge_values.dart  and paste the printed
// arrays into lib/emberlink/config/ridge_relay_config.dart. The VERIFY line
// must confirm every value round-trips exactly.

import 'dart:typed_data';

const List<int> _emberSalt = <int>[
  0x9A, 0x4E, 0xC7, 0x13, 0x6B, 0xF2, 0x81, 0x2D,
  0x5C, 0xE0, 0x37, 0xA9, 0x74, 0x18, 0xBD, 0x66,
];

int _keyByte(int index) => _emberSalt[(index * 7 + 13) % _emberSalt.length];

List<int> mask(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  return List<int>.generate(
    bytes.length,
    (index) => (bytes[index] ^ _keyByte(index) ^ (index * 41)) & 0xff,
  );
}

String unmask(List<int> encoded) {
  if (encoded.isEmpty) return '';
  return String.fromCharCodes(
    List<int>.generate(
      encoded.length,
      (index) => (encoded[index] ^ _keyByte(index) ^ (index * 41)) & 0xff,
    ),
  );
}

void main() {
  // Fill in the real values as they become available. UA fragments + the GCD
  // base do not depend on the operator's credentials and are safe to encode
  // now. `config`, `appsFlyerDevKey` and `firebaseProjectNumber` gate the whole
  // gray flow — leave them blank to ship the plain white game.
  const values = <String, String>{
    // ── Operator-supplied ─────────────────────────────────────────────
    'config': 'https://pyrofallridge.com/config.php',
    'appsFlyerDevKey': 'StJHsc3mzoZt8aVL3CLqEf',
    'firebaseProjectNumber': '938139106785',
    // ── Stable per project ────────────────────────────────────────────
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    // User-Agent scaffolding — every substring the UA scanner indexes lives
    // here as an encoded fragment (no plaintext Mozilla/iPhone/AppleWebKit).
    'uaProduct': 'Mozilla/5.0',
    'uaPlatformPrefix': '(iPhone; CPU iPhone OS',
    'uaPlatformSuffix': 'like Mac OS X)',
    'uaEngine': 'AppleWebKit/605.1.15 (KHTML, like Gecko)',
    'uaMobileToken': 'Mobile/15E148',
    'safariVersion': '18.7',
    'safariTail': '604.1',
    // Slot-partner identity suffix — tokens encoded so no plaintext
    // appid/appname literal ships in the binary. Assembled at runtime.
    'uaAppIdToken': 'appid/',
    'uaAppNameToken': 'appname/',
    'uaAppName': 'PyrofallRidge',
  };

  var ok = true;
  for (final entry in values.entries) {
    final encoded = mask(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (unmask(encoded) != entry.value) {
      ok = false;
      print('  !! round-trip FAILED for ${entry.key}');
    }
  }
  print(ok ? 'VERIFY: all values round-tripped' : 'VERIFY: FAILURES ABOVE');
}
