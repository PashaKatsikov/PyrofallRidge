import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import 'storage_service.dart';

/// The player's optional local profile photo, shown only on the Settings
/// screen. Purely cosmetic - it is never uploaded anywhere, never affects
/// gameplay, and lives entirely on this device.
///
/// The picked image is copied into the app's own documents directory under a
/// fixed filename rather than keeping whatever path `image_picker` handed
/// back: that source path is a temporary cache entry the OS can clear at any
/// time, while a file the app itself owns survives restarts.
class ProfileService extends ChangeNotifier {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final StorageService _storage = StorageService();

  static const String _fileName = 'profile_photo.jpg';

  String? _photoPath;

  /// Bumped on every change (including overwriting the same path with new
  /// bytes) so widgets keying off it know to actually reload the file
  /// instead of trusting an image cache keyed only by path.
  int version = 0;

  bool _initialized = false;

  String? get photoPath => _photoPath;
  bool get hasPhoto => _photoPath != null;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final String? saved = await _storage.loadAvatarPath();
    if (saved != null && File(saved).existsSync()) {
      _photoPath = saved;
    }
    notifyListeners();
  }

  /// Copies the image at [sourcePath] (as returned by the image picker) into
  /// permanent local storage and makes it the active profile photo.
  Future<void> setPhotoFromFile(String sourcePath) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String destPath = '${dir.path}/$_fileName';
    await File(sourcePath).copy(destPath);
    // The destination filename is always the same, so Flutter's image cache
    // would otherwise keep serving the previous photo's decoded bytes for a
    // FileImage that looks identical (same path) but points at new content.
    await FileImage(File(destPath)).evict();
    _photoPath = destPath;
    version++;
    notifyListeners();
    await _storage.saveAvatarPath(destPath);
  }

  Future<void> removePhoto() async {
    final String? path = _photoPath;
    if (path == null) return;
    _photoPath = null;
    version++;
    notifyListeners();
    await _storage.saveAvatarPath(null);
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
