import 'dart:math';

import '../core/game_config.dart';
import '../core/object_pool.dart';
import '../models/falling_object.dart';
import '../models/lane.dart';
import '../models/segment.dart';

/// Owns the procedurally generated vertical strip of [Segment]s.
///
/// Generation invariants (fairness rules):
///  * A freshly generated row never has both lanes in [LaneState.danger] at
///    the same time, so an escape route always exists on every single row.
///  * Danger may only *switch lanes* after at least
///    [minSafeRowsBeforeLaneSwitch] completely safe rows. Without this, two
///    consecutive rows could hold danger on opposite lanes, which is
///    genuinely unsurvivable: standing still walks into the danger one row
///    up, and stepping across walks into the danger on the current row. A
///    danger that stays in the *same* lane needs no gap at all - the player
///    simply keeps to the other side while the lava river scrolls past.
///  * A single lava river is capped at [maxDangerRunRows] rows so the player
///    is never locked into one lane for an unreasonable stretch.
class World {
  World(this._random);

  final Random _random;
  final Map<int, Segment> _segments = <int, Segment>{};
  final ObjectPool<Segment> _pool = ObjectPool<Segment>(() => Segment(0));

  /// Highest row index that has been procedurally generated (inclusive).
  int highestGeneratedRow = -1;

  /// Number of fully-safe rows guaranteed at the start of every run.
  static const int tutorialSafeRows = 8;

  /// Fully-safe rows required before a danger lane may flip to the other
  /// side. One row would technically be enough to cross, but it collapses
  /// the window to a single row of travel; two keeps it readable at the
  /// highest rise speed.
  static const int minSafeRowsBeforeLaneSwitch = 2;

  /// Longest uninterrupted run of danger rows within one lane.
  static const int maxDangerRunRows = 5;

  /// Row index of the most recently generated danger row, and which lane it
  /// occupied. Drives the lane-switch spacing rule above.
  int _lastDangerRow = -1000;
  Lane? _lastDangerLane;
  int _dangerRunLength = 0;

  Segment? segmentAt(int row) => _segments[row];

  static double worldYForRow(int row) => row * GameConfig.segmentHeight;

  void reset() {
    for (final segment in _segments.values) {
      _pool.release(segment);
    }
    _segments.clear();
    highestGeneratedRow = -1;
    _lastDangerRow = -1000;
    _lastDangerLane = null;
    _dangerRunLength = 0;
  }

  /// Ensures rows up to [uptoRow] exist, generating new ones as needed.
  ///
  /// [dangerChance] is the probability (0..1) that a non-tutorial row will
  /// contain one dangerous lane. The caller (spawn director / controller)
  /// is responsible for later "resolving" a danger lane into a platform.
  void ensureGenerated(int uptoRow, double dangerChance) {
    if (uptoRow <= highestGeneratedRow) return;
    for (int row = highestGeneratedRow + 1; row <= uptoRow; row++) {
      final segment = _pool.acquire()..reset(row);
      if (row >= tutorialSafeRows && _random.nextDouble() < dangerChance) {
        final Lane? dangerLane = _pickDangerLane(row);
        if (dangerLane != null) {
          segment.setState(dangerLane, LaneState.danger);
          _dangerRunLength = row == _lastDangerRow + 1 ? _dangerRunLength + 1 : 1;
          _lastDangerRow = row;
          _lastDangerLane = dangerLane;
        }
      }
      _segments[row] = segment;
    }
    highestGeneratedRow = uptoRow;
  }

  /// Chooses which lane may hold danger on [row], or null when this row has
  /// to stay fully safe to keep the climb survivable.
  Lane? _pickDangerLane(int row) {
    final Lane? last = _lastDangerLane;
    if (last == null) {
      return _random.nextBool() ? Lane.left : Lane.right;
    }
    // Rows strictly between the previous danger row and this one are safe by
    // construction, so this is exactly the size of the crossing window.
    final int safeRowsBetween = row - _lastDangerRow - 1;
    if (safeRowsBetween >= minSafeRowsBeforeLaneSwitch) {
      return _random.nextBool() ? Lane.left : Lane.right;
    }
    // Too close to flip sides: either extend the current river in the same
    // lane, or break it off entirely once it has run long enough.
    if (safeRowsBetween == 0 && _dangerRunLength >= maxDangerRunRows) {
      return null;
    }
    return last;
  }

  /// Recycles segments that have scrolled far enough below the visible
  /// bottom edge of the screen ([visibleBottomWorldY]).
  void cleanup(double visibleBottomWorldY) {
    final double cutoff = visibleBottomWorldY -
        GameConfig.cleanupMarginSegments * GameConfig.segmentHeight;
    final List<int> toRemove = <int>[];
    for (final entry in _segments.entries) {
      if (worldYForRow(entry.key) < cutoff) {
        toRemove.add(entry.key);
      }
    }
    for (final row in toRemove) {
      final segment = _segments.remove(row);
      if (segment != null) _pool.release(segment);
    }
  }

  bool isDanger(int row, Lane lane) =>
      segmentAt(row)?.stateOf(lane) == LaneState.danger;

  bool isSafeToStand(int row, Lane lane) {
    final state = segmentAt(row)?.stateOf(lane);
    return state == LaneState.safe || state == LaneState.platform;
  }

  /// Turns a segment's lane into a permanent platform (called when a
  /// falling object lands).
  void markPlatform(int row, Lane lane, FallingObjectType type) {
    final segment = segmentAt(row);
    if (segment == null) return;
    segment.setState(lane, LaneState.platform);
    segment.setGlow(lane, 1);
    segment.setLandedType(lane, type);
    // The exact sprite variant is picked here (not in the renderer) so it
    // stays fixed for the platform's lifetime instead of flickering between
    // choices every frame; the renderer only ever does `variant % count`.
    segment.setPlatformVariant(lane, _random.nextInt(1 << 16));
  }

  /// Advances the cooling-glow cosmetic fade on every recently landed
  /// platform currently kept in memory. The segment map is small (roughly
  /// [GameConfig.lookAheadSegments] entries) so a full pass is cheap.
  void updateGlow(double dt) {
    const double fadePerSecond = 0.35;
    for (final segment in _segments.values) {
      if (segment.leftGlow > 0) {
        segment.leftGlow =
            (segment.leftGlow - fadePerSecond * dt).clamp(0.0, 1.0).toDouble();
      }
      if (segment.rightGlow > 0) {
        segment.rightGlow = (segment.rightGlow - fadePerSecond * dt)
            .clamp(0.0, 1.0)
            .toDouble();
      }
    }
  }
}
