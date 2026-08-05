import 'package:flutter/material.dart';

import 'app.dart';

/// Orientation is intentionally NOT locked here: the loading screen is
/// allowed to render in either portrait or landscape (it picks the matching
/// artwork). Portrait is enforced once gameplay actually starts, see
/// `LoadingScreen._finish()`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PyrofallRidgeApp());
}
