// Throwaway harness: times GamePainter.paint() over many frames on a realistic
// scene that includes an active updraft (the case that used to build a fresh
// LinearGradient shader every single frame).
// Run with: flutter test .tmp_preview/paint_bench.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker, TickerCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:ridgegame/game/game_controller.dart';
import 'package:ridgegame/models/game_phase.dart';
import 'package:ridgegame/models/lane.dart';
import 'package:ridgegame/models/updraft.dart';
import 'package:ridgegame/rendering/game_painter.dart';
import 'package:ridgegame/services/background_service.dart';
import 'package:ridgegame/services/items_atlas_service.dart';
import 'package:ridgegame/services/lava_atlas_service.dart';
import 'package:ridgegame/services/settings_service.dart';
import 'package:ridgegame/services/skin_atlas_service.dart';
import 'package:ridgegame/services/terrain_atlas_service.dart';
import 'package:ridgegame/services/vfx_atlas_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Vsync implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paint benchmark', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService.instance.initialize();
    await TerrainAtlasService.instance.preload();
    await LavaAtlasService.instance.preload();
    await SkinAtlasService.instance.preload();
    await ItemsAtlasService.instance.preload();
    await VfxAtlasService.instance.preload();
    await BackgroundService.instance.preload();

    const Size size = Size(390, 844);
    final GameController controller = GameController(vsync: _Vsync());
    await controller.initialize();
    controller.setViewportSize(size);
    controller.start();

    // A dodging bot, otherwise the run ends on the first lava row and the
    // simulation freezes long before an updraft is scheduled.
    void steer() {
      final int row = controller.player.currentRow;
      final Lane lane = controller.player.lane;
      final Lane other = lane == Lane.left ? Lane.right : Lane.left;
      if (controller.world.isSafeToStand(row + 1, lane)) return;
      if (controller.world.isSafeToStand(row, other) &&
          controller.world.isSafeToStand(row + 1, other)) {
        controller.requestLaneChange(other);
      }
    }

    final GamePainter painter = GamePainter(controller);
    int frames = 0;
    bool sawUpdraft = false;
    while (frames < 60 * 240 && controller.phase.value == GamePhase.playing) {
      steer();
      controller.stepForTest(1 / 60);
      frames++;
      if (controller.spawnDirector.updrafts.isNotEmpty) sawUpdraft = true;
      // Measure the busiest possible frame: keep going until an updraft is
      // actually in its active phase, which is the layer that used to rebuild
      // a gradient shader every frame.
      if (controller.spawnDirector.updrafts
          .any((u) => u.phase == UpdraftPhase.active)) {
        break;
      }
    }
    debugPrint('scene after $frames frames: phase=${controller.phase.value.name} '
        'updraft=$sawUpdraft '
        'hazards=${controller.spawnDirector.active.length} '
        'pickups=${controller.spawnDirector.pickups.length} '
        'vfx=${controller.vfxManager.active.length}');

    // Warm the caches exactly the way the first real frame does.
    for (int i = 0; i < 5; i++) {
      final ui.PictureRecorder r = ui.PictureRecorder();
      painter.paint(Canvas(r), size);
      r.endRecording().dispose();
    }

    const int measured = 900;
    final Stopwatch sw = Stopwatch()..start();
    for (int i = 0; i < measured; i++) {
      steer();
      controller.stepForTest(1 / 60);
      final ui.PictureRecorder r = ui.PictureRecorder();
      painter.paint(Canvas(r), size);
      r.endRecording().dispose();
    }
    sw.stop();
    final double perFrame = sw.elapsedMicroseconds / measured;
    debugPrint('paint+step: ${perFrame.toStringAsFixed(1)} us/frame '
        'over $measured frames (16667 us is the 60fps budget)');
    controller.dispose();

    expect(perFrame, lessThan(4000));
  });

  // Silences the unused-import analyzer hint if the harness is trimmed.
  // ignore: unused_element
  Lane? unused() => null;
}
