import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// Shared pipeline for every sprite atlas in the game (skins, VFX, items,
/// terrain, lava): load the sheet once, find each cell's real content bounds
/// and cache that tightly cropped region as its own [ui.Image]. No pixel work
/// ever happens again after [preload] completes.
///
/// Cropping to the real content rather than to the raw grid rectangle is what
/// makes the sprites usable. The source sheets leave a different amount of
/// empty padding around every drawing - on the skins sheet the characters
/// range from 257 to 387 px tall inside a 432 px cell - so drawing raw cells
/// aspect-fit into a fixed box makes each one a different size sitting at a
/// different height.
///
/// Row/column accessors are 1-indexed to match the art-direction sheets the
/// sprite coordinates were specified with; internally cells are stored in a
/// flat, row-major, 0-indexed list.
class SpriteAtlas {
  SpriteAtlas({
    required this.assetPath,
    required this.columns,
    required this.rows,
    this.mirrorX = false,
    this.maxCellSize = 192,
    this.onlyCells,
    this.rightOverscan,
  }) : _cells = List<ui.Image?>.filled(columns * rows, null);

  final String assetPath;
  final int columns;
  final int rows;

  /// Mirrors every cell horizontally while it is being extracted, so drawing
  /// code never pays for the flip.
  final bool mirrorX;

  /// Longest edge (in pixels) a cached cell may have. Cells are drawn at at
  /// most ~70 logical px in-game and ~130 in the UI, so keeping them small
  /// cuts texture memory several times over with no visible difference.
  final double maxCellSize;

  /// Optional whitelist of flat cell indices to materialize. Sheets where
  /// only a handful of cells are ever used (terrain, lava) pass one so the
  /// other 50+ cells never occupy memory.
  final Set<int>? onlyCells;

  /// Extra pixels to search past a cell's right edge before cropping,
  /// keyed by flat cell index. These sheets are hand-illustrated rather than
  /// laid out on a strict grid, and a few drawings genuinely straddle their
  /// nominal column - a boulder's shoulder spilling into the next cell, say.
  /// Without this the content search clips at the grid line, cutting a round
  /// shape into one with a flat, straight-edged side.
  final Map<int, double>? rightOverscan;

  final List<ui.Image?> _cells;
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// [row] and [col] are 1-indexed. Returns null if out of range, not
  /// whitelisted, or the atlas hasn't finished loading (or failed to) -
  /// callers must always be ready to fall back to a primitive placeholder.
  ui.Image? cell(int row, int col) {
    final int r = row - 1;
    final int c = col - 1;
    if (r < 0 || r >= rows || c < 0 || c >= columns) return null;
    return _cells[r * columns + c];
  }

  Future<void> preload() async {
    if (_isLoaded) return;
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final ui.Codec codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image sheet = frame.image;

      // One single readback of the whole sheet; the alpha channel is all the
      // bounds search needs. The search itself runs off the UI isolate so the
      // loading screen keeps animating smoothly.
      final ByteData? bytes =
          await sheet.toByteData(format: ui.ImageByteFormat.rawRgba);
      Int32List? bounds;
      if (bytes != null) {
        bounds = await compute(
          computeAtlasCellBounds,
          AtlasBoundsRequest(
            pixels: bytes.buffer.asUint8List(),
            sheetWidth: sheet.width,
            sheetHeight: sheet.height,
            columns: columns,
            rows: rows,
            wanted: onlyCells?.toList(),
            rightOverscan: rightOverscan,
          ),
        );
      }

      final double cellWidth = sheet.width / columns;
      final double cellHeight = sheet.height / rows;

      for (int index = 0; index < columns * rows; index++) {
        if (onlyCells != null && !onlyCells!.contains(index)) continue;
        final int row = index ~/ columns;
        final int col = index % columns;
        final ui.Rect gridRect = ui.Rect.fromLTWH(
          col * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        );
        ui.Rect srcRect = gridRect;
        if (bounds != null && bounds[index * 4] >= 0) {
          srcRect = ui.Rect.fromLTRB(
            bounds[index * 4].toDouble(),
            bounds[index * 4 + 1].toDouble(),
            bounds[index * 4 + 2].toDouble(),
            bounds[index * 4 + 3].toDouble(),
          );
        }
        _cells[index] = await _extractCell(sheet, srcRect);
      }
      sheet.dispose();
      _isLoaded = true;
    } catch (_) {
      // Fail safe: every cell simply stays null and callers fall back to
      // their primitive placeholder - the game must never block or crash
      // because art failed to decode.
      _isLoaded = true;
    }
  }

  Future<ui.Image> _extractCell(ui.Image sheet, ui.Rect srcRect) async {
    final double scale = math.min(
      1.0,
      maxCellSize / math.max(srcRect.width, srcRect.height),
    );
    final int outWidth = (srcRect.width * scale).round().clamp(1, 4096);
    final int outHeight = (srcRect.height * scale).round().clamp(1, 4096);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
    );
    if (mirrorX) {
      canvas.translate(outWidth.toDouble(), 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      sheet,
      srcRect,
      ui.Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image cellImage = await picture.toImage(outWidth, outHeight);
    picture.dispose();
    return cellImage;
  }
}

/// Input for the off-isolate content-bounds search.
class AtlasBoundsRequest {
  const AtlasBoundsRequest({
    required this.pixels,
    required this.sheetWidth,
    required this.sheetHeight,
    required this.columns,
    required this.rows,
    required this.wanted,
    this.rightOverscan,
  });

  final Uint8List pixels;
  final int sheetWidth;
  final int sheetHeight;
  final int columns;
  final int rows;

  /// Flat cell indices to measure, or null for all of them.
  final List<int>? wanted;

  /// See [SpriteAtlas.rightOverscan].
  final Map<int, double>? rightOverscan;
}

/// Anything fainter than this counts as background, which keeps a barely
/// visible glow halo from defeating the crop.
const int _alphaThreshold = 24;

/// Returns four sheet-space coordinates (left, top, right, bottom) per cell,
/// or -1s for a cell that is empty or wasn't requested.
///
/// Top-level and pure so it can run through [compute].
Int32List computeAtlasCellBounds(AtlasBoundsRequest request) {
  final int cellCount = request.columns * request.rows;
  final Int32List out = Int32List(cellCount * 4)..fillRange(0, cellCount * 4, -1);
  final Set<int>? wanted = request.wanted?.toSet();
  final double cellWidth = request.sheetWidth / request.columns;
  final double cellHeight = request.sheetHeight / request.rows;

  for (int index = 0; index < cellCount; index++) {
    if (wanted != null && !wanted.contains(index)) continue;
    final int col = index % request.columns;
    final int row = index ~/ request.columns;
    final int x0 = (col * cellWidth).floor();
    final int y0 = (row * cellHeight).floor();
    final double overscan = request.rightOverscan?[index] ?? 0;
    final int x1 = math.min(
        request.sheetWidth, ((col + 1) * cellWidth + overscan).ceil());
    final int y1 = math.min(request.sheetHeight, ((row + 1) * cellHeight).ceil());

    final Int32List? box =
        _cellContentBounds(request.pixels, request.sheetWidth, x0, y0, x1, y1);
    if (box == null) continue;
    out[index * 4] = box[0];
    out[index * 4 + 1] = box[1];
    out[index * 4 + 2] = box[2];
    out[index * 4 + 3] = box[3];
  }
  return out;
}

/// Bounding box of the cell's own artwork.
///
/// Several sprites on these sheets overflow their grid cell slightly - a
/// flame plume from the neighbour, for instance - and a naive alpha bounding
/// box would swallow that sliver, shrinking and off-centering the real sprite.
/// So the mask is split into connected blobs and only the cell's main blob is
/// kept, together with any detached parts (sparks, floating crystals, a
/// character's own boots landing just clear of its robe) that stay well away
/// from the left/right cell edges, where bleed from a packed neighbour always
/// appears - close enough to the literal seam pixel to still read as "this
/// cell's drawing", but faded by anti-aliasing into a translucent sliver
/// rather than a hard cut. A blob within [_seamMarginFraction] of either edge
/// is treated as that neighbour, not a legitimate part of this cell, however
/// large it is.
Int32List? _cellContentBounds(
  Uint8List pixels,
  int sheetWidth,
  int x0,
  int y0,
  int x1,
  int y1,
) {
  final int width = x1 - x0;
  final int height = y1 - y0;
  if (width <= 0 || height <= 0) return null;

  final Uint8List mask = Uint8List(width * height);
  bool anyOpaque = false;
  for (int y = 0; y < height; y++) {
    final int srcRow = (y0 + y) * sheetWidth + x0;
    final int dstRow = y * width;
    for (int x = 0; x < width; x++) {
      if (pixels[(srcRow + x) * 4 + 3] > _alphaThreshold) {
        mask[dstRow + x] = 1;
        anyOpaque = true;
      }
    }
  }
  if (!anyOpaque) return null;

  final Int32List stack = Int32List(width * height);
  final List<int> areas = <int>[];
  final List<int> boxes = <int>[];

  for (int start = 0; start < mask.length; start++) {
    if (mask[start] != 1) continue;
    int top = 0;
    stack[top++] = start;
    mask[start] = 2;

    int area = 0;
    int minX = width, maxX = -1, minY = height, maxY = -1;

    while (top > 0) {
      final int p = stack[--top];
      final int px = p % width;
      final int py = p ~/ width;
      area++;
      if (px < minX) minX = px;
      if (px > maxX) maxX = px;
      if (py < minY) minY = py;
      if (py > maxY) maxY = py;

      if (px > 0 && mask[p - 1] == 1) {
        mask[p - 1] = 2;
        stack[top++] = p - 1;
      }
      if (px < width - 1 && mask[p + 1] == 1) {
        mask[p + 1] = 2;
        stack[top++] = p + 1;
      }
      if (py > 0 && mask[p - width] == 1) {
        mask[p - width] = 2;
        stack[top++] = p - width;
      }
      if (py < height - 1 && mask[p + width] == 1) {
        mask[p + width] = 2;
        stack[top++] = p + width;
      }
    }

    areas.add(area);
    boxes.addAll(<int>[minX, minY, maxX, maxY]);
  }

  int main = 0;
  for (int i = 1; i < areas.length; i++) {
    if (areas[i] > areas[main]) main = i;
  }

  int minX = boxes[main * 4];
  int minY = boxes[main * 4 + 1];
  int maxX = boxes[main * 4 + 2];
  int maxY = boxes[main * 4 + 3];

  // Specks smaller than this are decoding dust, not artwork.
  final int keepThreshold = (areas[main] * 0.02).ceil();
  final int seamMargin = (width * _seamMarginFraction).round();
  for (int i = 0; i < areas.length; i++) {
    if (i == main || areas[i] < keepThreshold) continue;
    final int bMinX = boxes[i * 4];
    final int bMaxX = boxes[i * 4 + 2];
    final bool nearSeam = bMinX < seamMargin || bMaxX > width - 1 - seamMargin;
    if (nearSeam) continue;
    if (bMinX < minX) minX = bMinX;
    if (boxes[i * 4 + 1] < minY) minY = boxes[i * 4 + 1];
    if (bMaxX > maxX) maxX = bMaxX;
    if (boxes[i * 4 + 3] > maxY) maxY = boxes[i * 4 + 3];
  }

  // One pixel of breathing room so bilinear filtering can't clip the edge.
  return Int32List.fromList(<int>[
    x0 + math.max(0, minX - 1),
    y0 + math.max(0, minY - 1),
    x0 + math.min(width, maxX + 2),
    y0 + math.min(height, maxY + 2),
  ]);
}

/// How close to a cell's left/right edge a secondary blob has to be before
/// it is assumed to be a packed neighbour bleeding across the gap rather
/// than a genuinely detached part of this cell's own drawing.
const double _seamMarginFraction = 0.15;
