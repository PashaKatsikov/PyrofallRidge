// Throwaway harness: renders GamePainter straight to a PNG so the terrain can
// be eyeballed without deploying to a device. Run with:
//   flutter test .tmp_preview/render_world.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridgegame/game/game_controller.dart';
import 'package:ridgegame/models/falling_object.dart';
import 'package:ridgegame/models/lane.dart';
import 'package:ridgegame/models/segment.dart';
import 'package:ridgegame/rendering/game_painter.dart';
import 'package:ridgegame/services/background_service.dart';
import 'package:ridgegame/services/items_atlas_service.dart';
import 'package:ridgegame/services/lava_atlas_service.dart';
import 'package:ridgegame/services/settings_service.dart';
import 'package:ridgegame/services/skin_atlas_service.dart';
import 'package:ridgegame/services/terrain_atlas_service.dart';
import 'package:ridgegame/services/vfx_atlas_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // A plain test(), not testWidgets(): the atlas pipeline hands work to a real
  // isolate, which never completes inside testWidgets' fake-async zone.
  TestWidgetsFlutterBinding.ensureInitialized();
  test('render world preview', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService.instance.initialize();
    debugPrint('settings ok');
    await TerrainAtlasService.instance.preload();
    debugPrint('terrain ok');
    await LavaAtlasService.instance.preload();
    debugPrint('lava ok');
    await SkinAtlasService.instance.preload();
    debugPrint('skins ok');
    await ItemsAtlasService.instance.preload();
    debugPrint('items ok');
    await VfxAtlasService.instance.preload();
    debugPrint('vfx ok');
    await BackgroundService.instance.preload();
    debugPrint('bg ok');

    const Size size = Size(390, 844);
    final GameController controller =
        GameController(vsync: const TestVSync());
    controller.setViewportSize(size);
    controller.world.ensureGenerated(40, 0.4);

    // A deterministic scene: some lava, a rockfall platform and a meteor
    // platform bridging it, right around the player.
    controller.player.worldY = 900;
    controller.cameraWorldY = 900;
    controller.runTime = 3.2;
    for (final (int row, Lane lane, LaneState state) in <(int, Lane, LaneState)>[
      (14, Lane.right, LaneState.danger),
      (15, Lane.right, LaneState.danger),
      (16, Lane.right, LaneState.danger),
      (17, Lane.left, LaneState.danger),
      (18, Lane.left, LaneState.danger),
      (13, Lane.left, LaneState.platform),
      (16, Lane.left, LaneState.platform),
      (20, Lane.right, LaneState.platform),
    ]) {
      final Segment? segment = controller.world.segmentAt(row);
      segment?.setState(lane, state);
      if (state == LaneState.platform) {
        segment?.setLandedType(
            lane, row.isEven ? FallingObjectType.meteor : FallingObjectType.rockfall);
        segment?.setPlatformVariant(lane, row);
        segment?.setGlow(lane, row == 16 ? 0.7 : 0);
      }
    }

    // Let the spawn director run for a couple of seconds so the frame contains
    // telegraphs, a hazard in flight and a few pickups.
    for (int i = 0; i < 600; i++) {
      controller.spawnDirector.update(
        dt: 1 / 60,
        playerWorldY: controller.player.worldY,
        riseSpeed: 90,
        heightMeters: controller.player.worldY / 12,
        viewportHeight: size.height,
      );
      if (controller.spawnDirector.active
          .any((o) => o.phase == FallingPhase.falling)) {
        break;
      }
    }
    controller.player.switchLane(Lane.right);
    controller.player.update(0.06, 0);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    GamePainter(controller).paint(canvas, size);
    final ui.Image image = await recorder
        .endRecording()
        .toImage(size.width.round(), size.height.round());
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('.tmp_preview/world.png').writeAsBytesSync(png!.buffer.asUint8List());
    controller.dispose();
  });
}
