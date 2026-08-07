import 'dart:math';
import 'dart:ui' as ui show Image, ImageShader, TileMode;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../core/game_config.dart';
import '../core/layout_config.dart';
import '../game/game_controller.dart';
import '../game/particle_field.dart';
import '../game/player.dart';
import '../models/falling_object.dart';
import '../models/floating_text.dart';
import '../models/game_phase.dart';
import '../models/lane.dart';
import '../models/pickup.dart';
import '../models/segment.dart';
import '../models/updraft.dart';
import '../models/vfx_instance.dart';
import '../services/background_service.dart';
import '../services/items_atlas_service.dart';
import '../services/lava_atlas_service.dart';
import '../services/settings_service.dart';
import '../services/skin_atlas_service.dart';
import '../services/skin_manager.dart';
import '../services/terrain_atlas_service.dart';
import '../services/vfx_atlas_service.dart';
import 'palette.dart';
import 'terrain_sprites.dart';
import 'vfx_sprites.dart';

/// Draws the entire game world every frame.
///
/// Every dynamic element (hazards, telegraphs, landed platforms, pickups,
/// impact/smoke VFX, the player's skin) prefers a pre-sliced, chroma-keyed
/// sprite from one of the atlases and transparently falls back to the
/// original hand-drawn primitive if that sprite hasn't finished loading (or
/// failed to). No per-frame allocations beyond the few small [Paint]
/// objects Flutter itself requires (kept as fields and reused) and a small
/// bounded [TextPainter] cache for floating "+N" popups.
///
/// Draw order (background -> danger/platform ground -> pickups -> hazard
/// bodies -> player -> VFX -> telegraphs on top) matches the layering the
/// brief specifies; ground cell states never overlap each other spatially,
/// so their relative order doesn't matter, but everything else does.
class GamePainter extends CustomPainter {
  GamePainter(this.controller)
      : super(repaint: Listenable.merge(<Listenable>[
          controller,
          SkinManager.instance,
          SettingsService.instance,
        ]));

  final GameController controller;

  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  // Terrain tiles are drawn at very close to 1:1 (one tile spans half a lane,
  // which is roughly the atlas cell's decoded size), so bilinear filtering is
  // indistinguishable from mipmapped here while covering far more pixels.
  final Paint _tilePaint = Paint()..filterQuality = FilterQuality.low;
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  final Map<FloatingText, TextPainter> _textPainterCache =
      <FloatingText, TextPainter>{};

  /// Repeating-texture shaders, keyed by image identity and tile size. Only a
  /// handful ever exist (one per material per viewport width), and building one
  /// is expensive enough to be worth never doing per frame.
  final Map<String, ui.ImageShader> _tileShaders = <String, ui.ImageShader>{};

  /// Viewport-sized paints (sky, location veil) that only change when the
  /// window is resized. Rebuilding a [LinearGradient] shader every frame is
  /// several milliseconds on mid-range Androids, so we do it once here.
  Size _cachedSize = Size.zero;
  late Paint _skyPaint;
  late Paint _veilPaint;

  static const double _sideMarginFraction = 0.08;
  static const double _laneGap = 6;

  /// Warm volcanic wash composited straight onto the masonry floor tile.
  static final ColorFilter _safeGroundTint = ColorFilter.mode(
    Palette.safeBottom.withValues(alpha: 0.42),
    BlendMode.srcOver,
  );

  @override
  void paint(Canvas canvas, Size rawSize) {
    // Everything below is authored against a phone-sized viewport. On a bigger
    // screen the entire playfield is drawn through one uniform scale, so an
    // iPad shows the same amount of ridge as an iPhone - just larger - and no
    // sprite, lane or hitbox has to know which device it is on.
    final double worldScale = LayoutConfig.worldScale(rawSize);
    final Size size = LayoutConfig.worldViewport(rawSize);

    canvas.save();
    if (worldScale != 1) canvas.scale(worldScale);

    // Camera shake is a pure canvas translation applied over the whole world,
    // deliberately *inside* the scale so it reads with the same strength on
    // every device, and never touches the camera's world anchor.
    if (controller.camera.isShaking) {
      canvas.translate(controller.camera.offsetX, controller.camera.offsetY);
    }

    _paintWorld(canvas, size);
    canvas.restore();

    _drawScreenOverlays(canvas, rawSize);
  }

  void _paintWorld(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    if (size != _cachedSize) {
      _cachedSize = size;
      _rebuildViewportPaints(size);
    }
    _drawBackground(canvas, size);

    // Within the (already scaled) viewport the lane column is still clamped to
    // a phone-ish width and centred, so an unusually wide window - a landscape
    // phone, a split-screen iPad - widens the void strips instead of the
    // lanes. The background art fills the rest, so nothing looks empty.
    final double contentWidth = min(width, LayoutConfig.maxContentWidth);
    final double outerGutter = (width - contentWidth) / 2;
    final double sideMargin =
        outerGutter + contentWidth * _sideMarginFraction;
    final double laneAreaWidth =
        contentWidth - contentWidth * _sideMarginFraction * 2;
    final double laneWidth = (laneAreaWidth - _laneGap) / 2;
    final double leftLaneLeft = sideMargin;
    final double rightLaneLeft = sideMargin + laneWidth + _laneGap;
    final double leftCenterX = leftLaneLeft + laneWidth / 2;
    final double rightCenterX = rightLaneLeft + laneWidth / 2;

    double laneLeftOf(Lane lane) =>
        lane == Lane.left ? leftLaneLeft : rightLaneLeft;
    double centerXOf(Lane lane) =>
        lane == Lane.left ? leftCenterX : rightCenterX;

    final double anchorScreenY = height * GameConfig.playerAnchorFraction;
    final double cameraWorldY = controller.cameraWorldY;
    double screenYOf(double worldY) =>
        anchorScreenY - (worldY - cameraWorldY);

    final double visibleTopWorldY =
        cameraWorldY + anchorScreenY + GameConfig.segmentHeight;
    final double visibleBottomWorldY =
        cameraWorldY - (height - anchorScreenY) - GameConfig.segmentHeight;
    final int rowTop = (visibleTopWorldY / GameConfig.segmentHeight).ceil();
    final int rowBottom =
        (visibleBottomWorldY / GameConfig.segmentHeight).floor();

    // Void strips either side of the two lanes: dark enough that the painted
    // location art behind them never competes with the playfield.
    _fillPaint.color = Palette.voidColor.withValues(alpha: 0.78);
    canvas.drawRect(Rect.fromLTWH(0, 0, leftLaneLeft, height), _fillPaint);
    canvas.drawRect(
      Rect.fromLTWH(rightLaneLeft + laneWidth, 0,
          width - (rightLaneLeft + laneWidth), height),
      _fillPaint,
    );
    // The chasm between the two paths.
    _fillPaint.color = Palette.voidColor.withValues(alpha: 0.9);
    canvas.drawRect(
      Rect.fromLTWH(leftLaneLeft + laneWidth, 0, _laneGap, height),
      _fillPaint,
    );

    // Layer 2+3: safe ground, lava and landed platforms, drawn one lane at a
    // time so vertically contiguous cells become a single textured run.
    for (final lane in Lane.values) {
      _drawLaneTerrain(
        canvas,
        lane: lane,
        left: laneLeftOf(lane),
        width: laneWidth,
        rowBottom: rowBottom,
        rowTop: rowTop,
        screenYOf: screenYOf,
      );
    }

    for (final u in controller.spawnDirector.updrafts) {
      _drawUpdraft(canvas, u, laneLeftOf(u.lane), laneWidth, screenYOf, height);
    }

    // Layer 4: pickups.
    for (final p in controller.spawnDirector.pickups) {
      _drawPickup(canvas, p, centerXOf(p.lane), screenYOf);
    }

    // Layer 5: falling hazard bodies (telegraphs are drawn later, on top).
    for (final obj in controller.spawnDirector.active) {
      _drawHazardBody(canvas, obj, centerXOf(obj.lane), screenYOf);
    }

    // Layer 6: particles behind the player (ash drifting down, embers rising
    // from below) - the ones drawn in front are done after the player.
    _drawParticles(canvas, centerXOf, laneWidth, screenYOf, inFront: false);

    // Layer 7: player.
    final bool boosting = controller.spawnDirector
        .isBoosting(controller.player.lane, controller.player.worldY);
    final ui.Image? skinImage = SkinAtlasService.instance
        .imageForSkinInGame(SkinManager.instance.selectedSkinId);
    _drawPlayer(canvas, controller.player, leftCenterX, rightCenterX,
        anchorScreenY, boosting, skinImage);

    _drawParticles(canvas, centerXOf, laneWidth, screenYOf, inFront: true);

    // Layer 8: VFX (impact bursts, landed smoke, ambient smoke, collect
    // blips) and their floating "+N" companions.
    for (final v in controller.vfxManager.active) {
      _drawVfxInstance(canvas, v, centerXOf(v.lane), screenYOf);
    }
    for (final t in controller.vfxManager.activeTexts) {
      _drawFloatingText(canvas, t, centerXOf(t.lane), screenYOf);
    }

    // Layer 9: telegraphs, always drawn last so warnings never get buried
    // under a hazard body, the player or a VFX puff.
    for (final obj in controller.spawnDirector.active) {
      _drawTelegraphLayer(canvas, obj, centerXOf(obj.lane), screenYOf);
    }
  }

  /// Full-screen treatments that must not be affected by the world scale or
  /// the camera shake: the heat vignette, the combo glow and the fade that
  /// closes a run.
  void _drawScreenOverlays(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Combo heat: the edges of the screen catch fire as the streak climbs, so
    // the reward for a long chain is visible without looking at the HUD.
    final int multiplier = controller.hud.value.comboMultiplier;
    if (multiplier > 1 && controller.phase.value == GamePhase.playing) {
      final double intensity =
          ((multiplier - 1) / (GameConfig.comboMaxMultiplier - 1))
              .clamp(0.0, 1.0)
              .toDouble();
      final double pulse = 0.75 + 0.25 * sin(controller.runTime * 7);
      final double band = size.height * 0.16;
      _drawEdgeGlow(canvas, rect, band, 0.16 * intensity * pulse);
    }

    final double fade = controller.deathFade;
    if (fade > 0) {
      _fillPaint.color = const Color(0xFF12060A).withValues(alpha: fade);
      canvas.drawRect(rect, _fillPaint);
    }
  }

  /// Warm banding hugging the top and bottom edges of the screen. Built from
  /// flat strips for the same reason the ground gradients are: a full-screen
  /// shader rebuilt per frame is by far the most expensive thing here.
  void _drawEdgeGlow(Canvas canvas, Rect rect, double band, double alpha) {
    const int steps = 4;
    for (int i = 0; i < steps; i++) {
      final double f = 1 - (i + 0.5) / steps;
      final double h = band / steps;
      _fillPaint.color = Palette.dangerCore.withValues(alpha: alpha * f);
      canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top + h * i, rect.width, h),
          _fillPaint);
      canvas.drawRect(
          Rect.fromLTWH(
              rect.left, rect.bottom - h * (i + 1), rect.width, h),
          _fillPaint);
    }
  }

  /// Painted location art for the current Ridge, slowly panning upward as the
  /// player climbs and cross-fading into the next location at the milestone.
  /// The gradient sky underneath is still drawn first, so a missing image (or
  /// backgrounds turned off in Settings) simply falls back to it.
  void _drawBackground(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    final double heightMeters =
        controller.player.worldY / GameConfig.pixelsPerMeter;
    final double ridgeRaw = heightMeters / GameConfig.metersPerRidge;
    final int ridge = ridgeRaw.floor() + 1;
    final double ridgeProgress = ridgeRaw - ridgeRaw.floorToDouble();

    final ui.Image? current = SettingsService.instance.showBackgrounds
        ? BackgroundService.instance.forRidge(ridge)
        : null;
    if (current == null) {
      // Nothing will cover it, so the gradient sky *is* the background.
      canvas.drawRect(rect, _skyPaint);
      return;
    }

    // The location art is opaque and fills the whole viewport, so painting the
    // sky underneath it would be a wasted full-screen pass every single frame.
    _drawLocation(canvas, rect, current, ridgeProgress, 1);

    // Blend the next location in over the last stretch of the ridge so the
    // scenery never pops.
    const double fadeStart = 0.9;
    if (ridgeProgress > fadeStart) {
      final ui.Image? next = BackgroundService.instance.forRidge(ridge + 1);
      if (next != null) {
        _drawLocation(
          canvas,
          rect,
          next,
          0,
          (ridgeProgress - fadeStart) / (1 - fadeStart),
        );
      }
    }

    canvas.drawRect(rect, _veilPaint);
  }

  /// (Re)builds the viewport-sized paints. Called only when the window size
  /// actually changes, keeping the hot [paint] path allocation-free.
  void _rebuildViewportPaints(Size size) {
    final Rect rect = Offset.zero & size;
    _skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const <Color>[Palette.skyTop, Palette.skyMid, Palette.skyGlow],
        stops: const <double>[0.0, 0.62, 1.0],
      ).createShader(rect);
    _veilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Palette.skyTop.withValues(alpha: 0.72),
          Palette.skyMid.withValues(alpha: 0.52),
          Palette.skyGlow.withValues(alpha: 0.62),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(rect);
  }

  /// Draws [image] filling [rect] without distortion, zoomed in just enough
  /// that the visible window can pan from the bottom of the art at [pan] == 0
  /// to its top at 1 - which is what sells the climb through a location.
  void _drawLocation(
    Canvas canvas,
    Rect rect,
    ui.Image image,
    double pan,
    double alpha,
  ) {
    const double zoom = 1.3;
    final double imageWidth = image.width.toDouble();
    final double imageHeight = image.height.toDouble();
    final double destAspect = rect.width / rect.height;

    double windowWidth = imageWidth;
    double windowHeight = imageWidth / destAspect;
    if (windowHeight > imageHeight) {
      windowHeight = imageHeight;
      windowWidth = imageHeight * destAspect;
    }
    windowWidth /= zoom;
    windowHeight /= zoom;

    final double top =
        (imageHeight - windowHeight) * (1 - pan.clamp(0.0, 1.0));
    final double left = (imageWidth - windowWidth) / 2;

    _imagePaint.color =
        Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0).toDouble());
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(left, top, windowWidth, windowHeight),
      rect,
      _imagePaint,
    );
  }

  // --- Ground / platforms --------------------------------------------------

  /// Paints one lane's worth of terrain for the visible rows.
  ///
  /// Vertically adjacent cells of the same kind are merged into a single run
  /// and filled with a repeating texture anchored to the world, so a long
  /// stretch of ground looks like one continuous surface instead of a stack of
  /// separately cropped slabs - and no sprite is ever stretched to fit a cell.
  void _drawLaneTerrain(
    Canvas canvas, {
    required Lane lane,
    required double left,
    required double width,
    required int rowBottom,
    required int rowTop,
    required double Function(double) screenYOf,
  }) {
    const double cellHeight = GameConfig.segmentHeight;
    // Anchoring the tile grid to world y = 0 is what makes the texture scroll
    // with the ridge instead of sliding underneath the player.
    final double tileOriginY = screenYOf(0);
    final double tileWidth = width / 2;

    int row = rowBottom;
    while (row <= rowTop) {
      final Segment? segment = controller.world.segmentAt(row);
      if (segment == null) {
        row++;
        continue;
      }
      final LaneState state = segment.stateOf(lane);
      final double bottomY = screenYOf(row * cellHeight);

      if (state == LaneState.platform) {
        _drawPlatformCell(
          canvas,
          Rect.fromLTRB(
              left, screenYOf((row + 1) * cellHeight), left + width, bottomY),
          tileWidth,
          tileOriginY,
          segment.landedTypeOf(lane),
          segment.platformVariantOf(lane),
          segment.glowOf(lane),
        );
        row++;
        continue;
      }

      int end = row;
      while (end < rowTop) {
        final Segment? next = controller.world.segmentAt(end + 1);
        if (next == null || next.stateOf(lane) != state) break;
        end++;
      }
      final Rect rect = Rect.fromLTRB(
          left, screenYOf((end + 1) * cellHeight), left + width, bottomY);
      final Segment? above = controller.world.segmentAt(end + 1);
      final bool exposedTop = above == null || above.stateOf(lane) != state;

      if (state == LaneState.safe) {
        _drawSafeRun(canvas, rect, tileWidth, tileOriginY, exposedTop);
      } else {
        _drawDangerRun(canvas, rect, tileWidth, tileOriginY, exposedTop);
      }
      row = end + 1;
    }
  }

  void _drawSafeRun(
    Canvas canvas,
    Rect rect,
    double tileWidth,
    double tileOriginY,
    bool exposedTop,
  ) {
    _fillPaint.color = Palette.safeBottom;
    canvas.drawRect(rect, _fillPaint);
    // The sheet's masonry is a cool grey; a warm wash ties it to the volcano
    // and keeps the ground quieter than the player silhouette on top of it.
    // Baked into the tile draw as a colour filter rather than a second
    // full-lane rect, since safe ground covers most of the screen.
    _drawTiled(
      canvas,
      rect,
      TerrainAtlasService.instance.sprite(TerrainSprites.floorTile),
      tileWidth,
      rect.left,
      tileOriginY,
      tint: _safeGroundTint,
    );

    if (!exposedTop) return;
    // Contact shadow + lit lip: three constant-alpha strips instead of a
    // per-frame linear-gradient shader, so no [Paint] or [Shader] is allocated
    // on the hot path.
    _drawTopShadeStrip(canvas, rect, Palette.voidColor, 0.42, 22);
    _fillPaint.color = Palette.safeHighlight.withValues(alpha: 0.75);
    canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 2), _fillPaint);
  }

  void _drawDangerRun(
    Canvas canvas,
    Rect rect,
    double tileWidth,
    double tileOriginY,
    bool exposedTop,
  ) {
    // Two solid colour bands (bright core on top of a deep pit) approximate a
    // vertical magma gradient at a fraction of the GPU cost of one, and let us
    // reuse the shared [_fillPaint].
    _fillPaint.color = Palette.dangerDeep;
    canvas.drawRect(rect, _fillPaint);
    _fillPaint.color = Palette.dangerCore.withValues(alpha: 0.55);
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.top, rect.right,
          lerpDouble(rect.top, rect.bottom, 0.55)!),
      _fillPaint,
    );

    _drawTiled(
      canvas,
      rect,
      LavaAtlasService.instance.sprite(LavaSprites.lavaTile),
      tileWidth,
      rect.left,
      tileOriginY,
    );

    // Slow breathing heat so the magma never looks like a static photo. One
    // sin() per lane, one full-rect fill - no shader.
    final double pulse =
        0.5 + 0.5 * sin(controller.runTime * 1.5 + rect.top * 0.012);
    _fillPaint.color = Palette.dangerCore.withValues(alpha: 0.08 + 0.10 * pulse);
    canvas.drawRect(rect, _fillPaint);

    if (!exposedTop) return;
    // Molten rim: two stacked flat strips instead of a gradient shader.
    _fillPaint.color =
        Palette.dangerHot.withValues(alpha: 0.28 + 0.14 * pulse);
    canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 6), _fillPaint);
    _fillPaint.color =
        Palette.dangerHot.withValues(alpha: 0.14 + 0.08 * pulse);
    canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top + 6, rect.width, 10), _fillPaint);
  }

  void _drawPlatformCell(
    Canvas canvas,
    Rect rect,
    double tileWidth,
    double tileOriginY,
    FallingObjectType? type,
    int variant,
    double glow,
  ) {
    _fillPaint.color = Palette.platformBase;
    canvas.drawRect(rect, _fillPaint);
    _drawTiled(
      canvas,
      rect,
      TerrainAtlasService.instance.sprite(TerrainSprites.platformTile),
      tileWidth,
      rect.left,
      tileOriginY,
    );

    _strokePaint
      ..strokeWidth = 2
      ..color = Palette.platformEdge.withValues(alpha: 0.85);
    canvas.drawRect(rect.deflate(1), _strokePaint);
    _fillPaint.color = Palette.glowHot.withValues(alpha: 0.35 + glow * 0.45);
    canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 2), _fillPaint);
    if (glow > 0) {
      _fillPaint.color = Palette.glowHot.withValues(alpha: glow * 0.35);
      canvas.drawRect(rect, _fillPaint);
    }

    if (type == null) return;
    // The boulder itself, rolled to one side so it never hides the player.
    final List<SheetCoord> options = type == FallingObjectType.meteor
        ? TerrainSprites.meteorBody
        : TerrainSprites.rockfallBody;
    final ui.Image? boulder =
        TerrainAtlasService.instance.sprite(options[variant % options.length]);
    if (boulder == null) {
      _drawRestingBoulderFallback(canvas, rect, type, glow);
      return;
    }
    final double size = rect.width * 0.34;
    final bool onLeft = variant.isEven;
    _drawCenteredImage(
      canvas,
      boulder,
      Offset(
        onLeft ? rect.left + size * 0.62 : rect.right - size * 0.62,
        rect.bottom - size * 0.42,
      ),
      size,
      size,
    );
  }

  /// Approximates a bottom-to-top vertical gradient across [rect] with a few
  /// stacked flat bands, reusing [_fillPaint].
  ///
  /// A real [LinearGradient] would have to call `createShader` with the current
  /// rect every frame, which is one of the most expensive things this painter
  /// can do; banding is invisible on the soft, low-alpha overlays this is used
  /// for (updraft columns).
  void _drawVerticalFade(
    Canvas canvas,
    Rect rect,
    Color color, {
    required double bottomAlpha,
    required double topAlpha,
    Color? topColor,
  }) {
    if (rect.height <= 0) return;
    const int bands = 5;
    final double bandH = rect.height / bands;
    for (int i = 0; i < bands; i++) {
      // Sample the ramp at each band's midpoint; 0 = bottom of the rect.
      final double f = (i + 0.5) / bands;
      _fillPaint.color = Color.lerp(color, topColor ?? color, f)!
          .withValues(alpha: lerpDouble(bottomAlpha, topAlpha, f)!);
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.bottom - bandH * (i + 1), rect.width, bandH),
        _fillPaint,
      );
    }
  }

  /// Approximates a vertical [color] -> transparent gradient at the top of
  /// [rect] using three stacked flat-alpha strips. Cheap enough to run for
  /// every exposed ledge in the view without allocating a shader.
  void _drawTopShadeStrip(
    Canvas canvas,
    Rect rect,
    Color color,
    double topAlpha,
    double totalHeight,
  ) {
    final double h = min(totalHeight, rect.height);
    if (h <= 0) return;
    const List<double> alphaMul = <double>[1.0, 0.55, 0.22];
    const List<double> heightMul = <double>[0.25, 0.35, 0.4];
    double y = rect.top;
    for (int i = 0; i < 3; i++) {
      final double bandH = h * heightMul[i];
      _fillPaint.color = color.withValues(alpha: topAlpha * alphaMul[i]);
      canvas.drawRect(
          Rect.fromLTWH(rect.left, y, rect.width, bandH), _fillPaint);
      y += bandH;
    }
  }

  void _drawRestingBoulderFallback(
    Canvas canvas,
    Rect cellRect,
    FallingObjectType type,
    double glow,
  ) {
    final bool isMeteor = type == FallingObjectType.meteor;
    final double radius = cellRect.width * (isMeteor ? 0.34 : 0.24);
    final Offset center =
        Offset(cellRect.center.dx, cellRect.bottom - radius * 0.9);
    _fillPaint.color = isMeteor ? Palette.meteorEdge : Palette.rockfallEdge;
    canvas.drawCircle(center, radius, _fillPaint);
    _fillPaint.color =
        (isMeteor ? Palette.meteorCore : Palette.rockfallCore)
            .withValues(alpha: 0.35 + glow * 0.45);
    canvas.drawCircle(center, radius * 0.6, _fillPaint);
  }

  // --- Updrafts (unchanged - no atlas sprites requested for these) --------

  void _drawUpdraft(
    Canvas canvas,
    Updraft u,
    double laneLeft,
    double laneWidth,
    double Function(double) screenYOf,
    double screenHeight,
  ) {
    final double topY = screenYOf(u.topWorldY);
    final double bottomY = screenYOf(u.bottomWorldY);
    if (bottomY < -8 || topY > screenHeight + 8) return;

    final double columnWidth = laneWidth * GameConfig.updraftColumnWidthFactor;
    final double centerX = laneLeft + laneWidth / 2;
    final Rect columnRect = Rect.fromLTRB(
      centerX - columnWidth / 2,
      topY,
      centerX + columnWidth / 2,
      bottomY,
    );

    switch (u.phase) {
      case UpdraftPhase.telegraph:
        final double t =
            (u.phaseTime / u.telegraphDuration).clamp(0.0, 1.0).toDouble();
        final double revealTop = lerpDouble(bottomY, topY, t)!;
        final Rect revealRect =
            Rect.fromLTRB(columnRect.left, revealTop, columnRect.right, bottomY);
        if (revealRect.height > 0) {
          _drawVerticalFade(
            canvas,
            revealRect,
            Palette.updraftCore,
            bottomAlpha: 0.10 + 0.22 * t,
            topAlpha: 0,
          );
        }
        final double pulse = 0.5 + 0.5 * sin(t * pi * 5 + u.bottomRow);
        _strokePaint
          ..strokeWidth = 2
          ..color = Palette.updraftCore.withValues(alpha: 0.25 + 0.25 * pulse);
        canvas.drawRect(columnRect, _strokePaint);
        break;

      case UpdraftPhase.active:
        _drawVerticalFade(
          canvas,
          columnRect,
          Palette.updraftCore,
          bottomAlpha: 0.7,
          topAlpha: 0.28,
          topColor: Palette.updraftEdge,
        );

        const double stripeSpacing = 26;
        const double stripeHeight = 7;
        final double scroll = (u.phaseTime * 110) % stripeSpacing;
        for (double y = bottomY - scroll; y > topY - stripeSpacing; y -= stripeSpacing) {
          final double top = y - stripeHeight;
          final double bottom = y;
          final double clampedTop = top < topY ? topY : top;
          final double clampedBottom = bottom > bottomY ? bottomY : bottom;
          if (clampedBottom <= clampedTop) continue;
          _fillPaint.color = Palette.updraftStripe.withValues(alpha: 0.35);
          canvas.drawRect(
            Rect.fromLTRB(columnRect.left, clampedTop, columnRect.right, clampedBottom),
            _fillPaint,
          );
        }

        _fillPaint.color = Palette.updraftStripe.withValues(alpha: 0.8);
        canvas.drawRect(
          Rect.fromLTWH(columnRect.left, bottomY - 4, columnRect.width, 4),
          _fillPaint,
        );
        break;

      case UpdraftPhase.expired:
        final double fade = 1 -
            (u.phaseTime / GameConfig.updraftFadeDuration).clamp(0.0, 1.0).toDouble();
        _fillPaint.color = Palette.updraftCore.withValues(alpha: 0.3 * fade);
        canvas.drawRect(columnRect, _fillPaint);
        break;
    }
  }

  // --- Pickups -------------------------------------------------------------

  void _drawPickup(
    Canvas canvas,
    Pickup pickup,
    double centerX,
    double Function(double) screenYOf,
  ) {
    final double bob =
        sin(pickup.age * GameConfig.pickupBobSpeed + pickup.bobPhase) *
            GameConfig.pickupBobAmplitude;
    final double y = screenYOf(pickup.worldY) + bob;
    final double pulse = 0.92 + 0.08 * sin(pickup.age * 3 + pickup.bobPhase);
    final double baseSize = pickup.type == PickupType.chest ? 32 : 24;
    final double size = baseSize * pulse;

    _fillPaint.color = Palette.glowHot.withValues(alpha: 0.22);
    canvas.drawCircle(Offset(centerX, y), size * 0.7, _fillPaint);

    final ui.Image? image =
        ItemsAtlasService.instance.cell(pickup.sprite.row, pickup.sprite.col);
    if (image != null) {
      _drawCenteredImage(canvas, image, Offset(centerX, y), size, size);
    } else {
      _fillPaint.color = Palette.updraftCore;
      canvas.drawCircle(Offset(centerX, y), size * 0.4, _fillPaint);
    }
  }

  // --- Falling hazards -------------------------------------------------------

  void _drawHazardBody(
    Canvas canvas,
    FallingObject obj,
    double centerX,
    double Function(double) screenYOf,
  ) {
    if (obj.phase != FallingPhase.falling) return;
    final double y = screenYOf(obj.currentWorldY);
    final bool isMeteor = obj.type == FallingObjectType.meteor;

    // Motion streak above the object stays a cheap primitive regardless of
    // whether the sprite loaded - it reads as speed blur either way.
    _fillPaint.color =
        (isMeteor ? Palette.meteorEdge : Palette.rockfallEdge)
            .withValues(alpha: 0.22);
    canvas.drawRect(
      Rect.fromLTWH(centerX - obj.halfWidth * 0.5, y - obj.halfWidth * 3.2,
          obj.halfWidth, obj.halfWidth * 3),
      _fillPaint,
    );

    final List<SheetCoord> options =
        isMeteor ? TerrainSprites.meteorBody : TerrainSprites.rockfallBody;
    final ui.Image? image = TerrainAtlasService.instance
        .sprite(options[obj.spriteVariant % options.length]);

    if (image != null) {
      final double size = obj.halfWidth * (isMeteor ? 3.0 : 2.4);
      _drawCenteredImage(canvas, image, Offset(centerX, y), size, size);
    } else {
      _fillPaint.color = isMeteor ? Palette.meteorEdge : Palette.rockfallEdge;
      canvas.drawCircle(Offset(centerX, y), obj.halfWidth, _fillPaint);
      _fillPaint.color = isMeteor ? Palette.meteorCore : Palette.rockfallCore;
      canvas.drawCircle(Offset(centerX, y), obj.halfWidth * 0.62, _fillPaint);
    }
  }

  void _drawTelegraphLayer(
    Canvas canvas,
    FallingObject obj,
    double centerX,
    double Function(double) screenYOf,
  ) {
    if (obj.phase != FallingPhase.telegraph &&
        obj.phase != FallingPhase.falling) {
      return;
    }
    final bool fading = obj.phase == FallingPhase.falling;
    final bool isMeteor = obj.type == FallingObjectType.meteor;
    final double groundY = screenYOf(obj.targetWorldY) - 4;

    final double progress = fading
        ? 1.0
        : (obj.phaseTime / obj.telegraphDuration).clamp(0.0, 1.0).toDouble();
    final double pulse = 0.55 + 0.45 * sin(progress * pi * 6 + obj.targetRow);
    final double alpha = fading ? 0.22 : (0.4 + 0.4 * pulse);
    final double growth = fading ? 1.0 : (0.65 + 0.35 * progress);
    final double zoneHalfWidth =
        obj.halfWidth * (isMeteor ? 1.6 : 1.3) * growth;

    // Homing meteor overlay: an extra pulsing red ring on the target zone so
    // the player instantly knows "this one is following me".
    if (obj.isHoming && !fading) {
      _strokePaint
        ..strokeWidth = 2.6
        ..color = Palette.meteorEdge.withValues(alpha: 0.55 + 0.35 * pulse);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centerX, groundY),
          width: zoneHalfWidth * 2.4,
          height: zoneHalfWidth * 1.1,
        ),
        _strokePaint,
      );
    }

    final VfxCoord ringCoord = VfxSprites.telegraphRing[
        obj.spriteVariant % VfxSprites.telegraphRing.length];
    final ui.Image? ringImage =
        VfxAtlasService.instance.cell(ringCoord.row, ringCoord.col);

    if (ringImage != null) {
      _drawCenteredImage(
        canvas,
        ringImage,
        Offset(centerX, groundY),
        zoneHalfWidth * 2.2,
        zoneHalfWidth * 2.2,
        alpha: alpha,
      );
    } else {
      _fillPaint.color = Palette.telegraphZone.withValues(alpha: alpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centerX, groundY),
          width: zoneHalfWidth * 2,
          height: zoneHalfWidth * 0.9,
        ),
        _fillPaint,
      );
      if (!fading) {
        _strokePaint
          ..strokeWidth = 2.4
          ..color = Palette.telegraphRing.withValues(alpha: 0.5 + 0.4 * pulse);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(centerX, groundY),
            width: zoneHalfWidth * 2 * (0.6 + 0.4 * progress),
            height: zoneHalfWidth * 0.9 * (0.6 + 0.4 * progress),
          ),
          _strokePaint,
        );
      }
    }

    if (!fading) {
      final double markerY = 22 + (isMeteor ? 4 : 0);
      final ui.Image? aimImage = VfxAtlasService.instance
          .cell(VfxSprites.telegraphAimDot.row, VfxSprites.telegraphAimDot.col);
      if (aimImage != null) {
        final double markerSize = isMeteor ? 26 : 20;
        _drawCenteredImage(
          canvas,
          aimImage,
          Offset(centerX, markerY),
          markerSize,
          markerSize,
          alpha: 0.9,
        );
      } else {
        _fillPaint.color =
            (isMeteor ? Palette.meteorCore : Palette.rockfallCore)
                .withValues(alpha: 0.85);
        final double r = isMeteor ? 10 : 7;
        canvas.drawCircle(Offset(centerX, markerY), r, _fillPaint);
        _strokePaint
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.7);
        canvas.drawCircle(Offset(centerX, markerY), r + 3, _strokePaint);
      }
    }
  }

  // --- VFX + floating text --------------------------------------------------

  void _drawVfxInstance(
    Canvas canvas,
    VfxInstance vfx,
    double centerX,
    double Function(double) screenYOf,
  ) {
    final VfxCoord? coord = vfx.currentSprite;
    if (coord == null) return;
    final double alpha = vfx.currentAlpha.clamp(0.0, 1.0).toDouble();
    if (alpha <= 0) return;
    final double size = vfx.baseSize * vfx.currentScale;
    final double y = screenYOf(vfx.worldY);
    final ui.Image? image = VfxAtlasService.instance.cell(coord.row, coord.col);
    if (image != null) {
      _drawCenteredImage(canvas, image, Offset(centerX, y), size, size,
          alpha: alpha);
    } else {
      _fillPaint.color = Palette.dangerHot.withValues(alpha: alpha * 0.6);
      canvas.drawCircle(Offset(centerX, y), size * 0.5, _fillPaint);
    }
  }

  void _drawFloatingText(
    Canvas canvas,
    FloatingText text,
    double centerX,
    double Function(double) screenYOf,
  ) {
    final double t = (text.phaseTime / text.duration).clamp(0.0, 1.0).toDouble();
    final double alpha = 1 - t;
    if (alpha <= 0) return;
    final double riseOffset = -26 * t;
    final double y = screenYOf(text.worldY) + riseOffset - 18;

    // Rebuild the painter each frame with the current alpha baked into the
    // colour: an offscreen [saveLayer] fade would cost a full alpha-blended
    // copy every frame per popup, whereas laying out a six-character line is
    // sub-100 microseconds and typically only one popup is alive at a time.
    final TextPainter painter = _textPainterFor(text, alpha);
    painter.paint(
      canvas,
      Offset(centerX - painter.width / 2, y - painter.height / 2),
    );
  }

  /// Alpha is quantised to 16 buckets so most consecutive frames hit the cache
  /// and no [TextPainter] is rebuilt.
  TextPainter _textPainterFor(FloatingText text, double alpha) {
    final int bucket = (alpha * 15).round().clamp(0, 15);
    TextPainter? cached = _textPainterCache[text];
    if (cached == null ||
        text.paintedText != text.text ||
        text.paintedAlphaBucket != bucket) {
      final double a = bucket / 15;
      cached = TextPainter(
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            color: const Color(0xFFFFD37A).withValues(alpha: a),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            shadows: <Shadow>[
              Shadow(color: Colors.black87.withValues(alpha: a), blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _textPainterCache[text] = cached;
      text.paintedText = text.text;
      text.paintedAlphaBucket = bucket;
    }
    return cached;
  }

  // --- Particles -------------------------------------------------------------

  /// Draws the atmospheric/impact particle layer.
  ///
  /// Split into a pass behind the player and one in front so sparks from an
  /// impact wrap around the climber instead of always sitting flat behind
  /// them: the short-lived, bright kinds go in front, the slow ambient ones
  /// stay behind.
  void _drawParticles(
    Canvas canvas,
    double Function(Lane) centerXOf,
    double laneWidth,
    double Function(double) screenYOf, {
    required bool inFront,
  }) {
    for (final Particle p in controller.particles.active) {
      final bool isForeground =
          p.kind == ParticleKind.spark || p.kind == ParticleKind.dust;
      if (isForeground != inFront) continue;

      final double t = p.t;
      final double x = centerXOf(p.lane) + p.offsetXFraction * laneWidth;
      final double y = screenYOf(p.worldY);

      switch (p.kind) {
        case ParticleKind.ember:
          // Embers cool as they rise and drift on a slow sine, which is what
          // stops a field of dots from looking like falling snow in reverse.
          final double sway = sin(t * 6 + p.spinSeed) * laneWidth * 0.05;
          _fillPaint.color = Color.lerp(
            Palette.emberHot,
            Palette.emberCool,
            t,
          )!
              .withValues(alpha: (1 - t) * 0.85);
          canvas.drawCircle(
              Offset(x + sway, y), p.size * (1 - t * 0.4), _fillPaint);
          break;

        case ParticleKind.ash:
          final double sway = sin(t * 4 + p.spinSeed) * laneWidth * 0.08;
          _fillPaint.color = Palette.ash
              .withValues(alpha: (1 - t) * 0.30 * (t < 0.15 ? t / 0.15 : 1));
          canvas.drawCircle(Offset(x + sway, y), p.size * 0.8, _fillPaint);
          break;

        case ParticleKind.dust:
          _fillPaint.color =
              Palette.dust.withValues(alpha: (1 - t) * 0.55);
          canvas.drawCircle(Offset(x, y), p.size * (0.7 + t * 1.1), _fillPaint);
          break;

        case ParticleKind.spark:
          _fillPaint.color = Color.lerp(
            Palette.sparkHot,
            Palette.emberCool,
            t * t,
          )!
              .withValues(alpha: (1 - t * t));
          canvas.drawCircle(Offset(x, y), p.size * (1 - t * 0.55), _fillPaint);
          break;
      }
    }
  }

  // --- Player ----------------------------------------------------------------

  /// Draws the climber, driven entirely by the procedural rig on [Player].
  ///
  /// The skin atlas only provides a single static sprite per character, so
  /// everything that makes them feel alive happens here: a two-step climb bob,
  /// a leaping arc with squash-and-stretch across a lane change, a contact
  /// shadow that widens as they leave the ground, an updraft stretch, and a
  /// tumble on death.
  void _drawPlayer(
    Canvas canvas,
    Player player,
    double leftCenterX,
    double rightCenterX,
    double anchorScreenY,
    bool boosting,
    ui.Image? skinImage,
  ) {
    final double fromX =
        player.animationFromLane == Lane.left ? leftCenterX : rightCenterX;
    final double toX = player.lane == Lane.left ? leftCenterX : rightCenterX;
    final double t = player.laneAnimationT;
    final double eased = 1 - pow(1 - t, 2).toDouble();
    final double x = lerpDouble(fromX, toX, eased)! + player.deathOffsetX;

    final double halfW = GameConfig.playerHalfWidth;
    final double halfH = GameConfig.playerHalfHeight;

    // Ground plane, i.e. where the feet are when standing. Kept separate from
    // the body's animated Y so the shadow stays pinned while they leap.
    final double groundY = anchorScreenY;
    final double bodyY = groundY +
        player.bobOffset +
        player.hopOffset +
        player.deathOffsetY;

    final double alpha = player.deathAlpha;
    if (alpha <= 0) return;

    // Contact shadow: tight and dark underfoot, wide and faint at the top of
    // a leap. Cheap, and it is what stops the character floating.
    final double shadowAlpha = player.shadowAlpha * alpha;
    if (shadowAlpha > 0) {
      _fillPaint.color = Palette.voidColor.withValues(alpha: shadowAlpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, groundY + 2),
          width: halfW * 1.8 * player.shadowScale,
          height: halfW * 0.62 * player.shadowScale,
        ),
        _fillPaint,
      );
    }

    // Soft flame halo behind the runner, breathing with the climb cycle and
    // flaring while an updraft has hold of them. Three concentric rings
    // approximate a radial falloff: a flat disc reads as a sticker behind the
    // character, and a real radial shader would have to be rebuilt every frame
    // as the player moves.
    final double boost = player.boostBlend;
    final double haloPulse = 1 + 0.06 * sin(controller.runTime * 6.5);
    final Color haloColor =
        Color.lerp(Palette.playerFlame, Palette.updraftCore, boost)!;
    final double haloRadius = halfW * (1.9 + boost * 0.9) * haloPulse;
    const List<double> haloSteps = <double>[1.0, 0.68, 0.42];
    const List<double> haloAlphas = <double>[0.10, 0.14, 0.20];
    for (int i = 0; i < haloSteps.length; i++) {
      _fillPaint.color = haloColor.withValues(
          alpha: haloAlphas[i] * (1 + boost) * alpha);
      canvas.drawCircle(
        Offset(x, bodyY - halfH * 0.4),
        haloRadius * haloSteps[i],
        _fillPaint,
      );
    }

    canvas.save();
    canvas.translate(x, bodyY);
    final double lean = player.lean;
    if (lean != 0) canvas.rotate(lean);
    canvas.scale(player.scaleX, player.scaleY);

    if (skinImage != null) {
      final double targetHeight = halfH * 4.4;
      final double targetWidth =
          targetHeight * (skinImage.width / skinImage.height);
      _drawCenteredImage(
        canvas,
        skinImage,
        Offset(0, -targetHeight * 0.30),
        targetWidth,
        targetHeight,
        alpha: alpha,
      );
    } else {
      _drawPlayerPlaceholder(canvas, halfW, halfH, alpha);
    }
    canvas.restore();
  }

  /// Primitive placeholder silhouette, used until the skin atlas has finished
  /// loading (or if a skin failed to decode for any reason). Drawn in the
  /// player's already-transformed local space, so it inherits the same rig.
  void _drawPlayerPlaceholder(
    Canvas canvas,
    double halfW,
    double halfH,
    double alpha,
  ) {
    final Rect body = Rect.fromCenter(
      center: Offset(0, -halfH * 0.2),
      width: halfW * 1.6,
      height: halfH * 1.8,
    );
    _fillPaint.color = Palette.playerOutline.withValues(alpha: alpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.inflate(2), Radius.circular(halfW * 0.8)),
      _fillPaint,
    );
    _fillPaint.color = Palette.playerCore.withValues(alpha: alpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(halfW * 0.7)),
      _fillPaint,
    );
    _fillPaint.color = Palette.playerFlame.withValues(alpha: alpha);
    canvas.drawCircle(Offset(0, body.top - 4), halfW * 0.55, _fillPaint);
  }

  // --- Shared sprite helper ----------------------------------------------

  /// Fills [dest] with [image] repeated at [tileWidth] logical pixels per tile,
  /// scaled uniformly so the sprite is never distorted. The tile grid is
  /// anchored to ([originX], [originY]) in canvas space, which is how the ground
  /// texture stays locked to the world while the camera climbs.
  ///
  /// A null [image] (atlas still loading, or failed) leaves whatever solid base
  /// colour was painted underneath.
  void _drawTiled(
    Canvas canvas,
    Rect dest,
    ui.Image? image,
    double tileWidth,
    double originX,
    double originY, {
    ColorFilter? tint,
  }) {
    if (image == null || tileWidth <= 0) return;
    final double tileHeight = tileWidth * image.height / image.width;
    if (tileHeight <= 0) return;
    // Only the offset within one tile matters, and keeping the translation
    // small avoids losing precision high up the mountain.
    final double tx = originX - (originX / tileWidth).floorToDouble() * tileWidth;
    final double ty =
        originY - (originY / tileHeight).floorToDouble() * tileHeight;

    // The shader already tiles infinitely, so a plain [drawRect] bounded by
    // [dest] is enough - no clipRect is needed. Skipping the scissor + the
    // save/restore pair meaningfully lifts fps on mid-range Adreno GPUs.
    canvas.save();
    canvas.translate(tx, ty);
    _tilePaint
      ..shader = _tileShader(image, tileWidth)
      ..colorFilter = tint
      ..color = Colors.white;
    canvas.drawRect(dest.shift(Offset(-tx, -ty)), _tilePaint);
    canvas.restore();
  }

  ui.ImageShader _tileShader(ui.Image image, double tileWidth) {
    final String key = '${identityHashCode(image)}@${tileWidth.round()}';
    final ui.ImageShader? cached = _tileShaders[key];
    if (cached != null) return cached;
    // Guard against unbounded growth if the viewport is resized repeatedly.
    if (_tileShaders.length > 8) _tileShaders.clear();
    final double scale = tileWidth / image.width;
    final ui.ImageShader shader = ui.ImageShader(
      image,
      ui.TileMode.repeated,
      ui.TileMode.repeated,
      (Matrix4.identity()..scaleByDouble(scale, scale, 1, 1)).storage,
    );
    _tileShaders[key] = shader;
    return shader;
  }

  /// Draws [image] aspect-fit (like `BoxFit.contain`) inside a `width` x
  /// `height` box centered on [center], with an optional opacity.
  void _drawCenteredImage(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double width,
    double height, {
    double alpha = 1,
  }) {
    final double aspect = image.width / image.height;
    double w = width;
    double h = height;
    if (aspect > w / h) {
      h = w / aspect;
    } else {
      w = h * aspect;
    }
    final Rect dest = Rect.fromCenter(center: center, width: w, height: h);
    _imagePaint.color =
        Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0).toDouble());
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dest,
      _imagePaint,
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
