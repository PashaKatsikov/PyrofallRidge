import 'dart:typed_data';

/// Project-unique obfuscation key. This is NOT content-protection encryption —
/// it only keeps a handful of endpoint/credential strings out of the plain
/// binary. The scheme is a single position-keyed XOR pass (one node in the
/// data-flow graph), deliberately unlike the RC4-style KSA/PRGA stream cipher
/// used by sibling projects.
const List<int> _emberSalt = <int>[
  0x9A, 0x4E, 0xC7, 0x13, 0x6B, 0xF2, 0x81, 0x2D,
  0x5C, 0xE0, 0x37, 0xA9, 0x74, 0x18, 0xBD, 0x66,
];

int _keyByte(int index) => _emberSalt[(index * 7 + 13) % _emberSalt.length];

/// Reverses [maskCinder]. XOR is symmetric, so the same transform both hides
/// and reveals a value.
String unmaskCinder(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final plain = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    plain[index] = (encoded[index] ^ _keyByte(index) ^ (index * 41)) & 0xff;
  }
  return String.fromCharCodes(plain);
}
