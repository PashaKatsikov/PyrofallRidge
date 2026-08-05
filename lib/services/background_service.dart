import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// The seven painted volcanic locations the climb travels through - one per
/// "Ridge" milestone, cycling afterwards.
///
/// Each sheet is decoded once at a reduced width: they only ever sit behind
/// gameplay under a dark gradient, so full resolution would cost several
/// megabytes of texture memory for no visible gain.
class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  static const int locationCount = 7;
  /// Deliberately well below the source art's 768 px: the location always
  /// sits behind gameplay under a heavy darkening veil, so decoding at full
  /// size would cost megabytes of texture memory per location for a
  /// difference nobody can see.
  static const int _decodeWidth = 512;

  final List<ui.Image?> _images = List<ui.Image?>.filled(locationCount, null);
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> preload() async {
    if (_isLoaded) return;
    for (int i = 0; i < locationCount; i++) {
      _images[i] = await _decode('assets/bg_location_${i + 1}_asset.webp');
    }
    _isLoaded = true;
  }

  /// Location art for a 1-based ridge number, cycling through the set.
  ui.Image? forRidge(int ridgeNumber) {
    if (ridgeNumber < 1) ridgeNumber = 1;
    return _images[(ridgeNumber - 1) % locationCount];
  }

  Future<ui.Image?> _decode(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: _decodeWidth,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      // A missing background just means the painter keeps its gradient sky.
      return null;
    }
  }
}
