// Throwaway harness: writes every skin cell out as its own PNG, tightly
// cropped and unmirrored, to use as an art reference. Run with:
//   flutter test .tmp_preview/export_skin_cells.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ridgegame/services/sprite_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export skin cells', () async {
    const int columns = 10;
    const int rows = 2;
    final SpriteAtlas atlas = SpriteAtlas(
      assetPath: 'assets/skins/skins_atlas.png',
      columns: columns,
      rows: rows,
      maxCellSize: 512,
    );
    await atlas.preload();

    final Directory out = Directory('.tmp_preview/skin_cells');
    if (!out.existsSync()) out.createSync(recursive: true);
    for (int id = 0; id < columns * rows; id++) {
      final ui.Image? image = atlas.cell(id ~/ columns + 1, id % columns + 1);
      if (image == null) {
        stderr.writeln('missing cell $id');
        continue;
      }
      final ByteData? png =
          await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/skin_${id.toString().padLeft(2, '0')}.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    }
    stdout.writeln('exported ${columns * rows} cells');
  });
}
