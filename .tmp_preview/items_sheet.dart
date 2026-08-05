// Throwaway tool: renders the items atlas as a labelled contact sheet so cells
// can be picked by eye. Run with: flutter test .tmp_preview/items_sheet.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

const int rows = 4;
const int cols = 10;
const double cell = 130;
const double label = 20;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export items contact sheet', () async {
    final ByteData data =
        await rootBundle.load('assets/items/items_atlas.png');
    final ui.Codec codec =
        await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.Image atlas = (await codec.getNextFrame()).image;

    final double cw = atlas.width / cols;
    final double ch = atlas.height / rows;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double sheetW = cols * cell;
    final double sheetH = rows * (cell + label);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, sheetW, sheetH),
      Paint()..color = const Color(0xFF101014),
    );

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final Rect src = Rect.fromLTWH(c * cw, r * ch, cw, ch);
        final double dx = c * cell;
        final double dy = r * (cell + label) + label;
        canvas.drawImageRect(
          atlas,
          src,
          Rect.fromLTWH(dx, dy, cell, cell),
          Paint()..filterQuality = FilterQuality.medium,
        );
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: '${r + 1},${c + 1}',
            style: const TextStyle(color: Color(0xFFFFE08A), fontSize: 15),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(dx + 4, dy - label + 2));
      }
    }

    final ui.Image out = await recorder
        .endRecording()
        .toImage(sheetW.round(), sheetH.round());
    final ByteData? png = await out.toByteData(format: ui.ImageByteFormat.png);
    File('.tmp_preview/items_sheet.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
    debugPrint('wrote .tmp_preview/items_sheet.png '
        '(${sheetW.round()}x${sheetH.round()})');
  });
}
