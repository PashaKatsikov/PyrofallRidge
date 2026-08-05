import 'falling_object.dart';
import 'lane.dart';

/// State of a single lane within a height segment.
enum LaneState {
  /// Solid basalt ground, always safe to stand on.
  safe,

  /// Magma / collapsed ridge / chasm - deadly unless a platform covers it.
  danger,

  /// Cooling rock created by a landed falling object. Always safe.
  platform,
}

/// One horizontal "slice" of the ridge, `GameConfig.segmentHeight` tall,
/// holding the state of both lanes at that height.
///
/// Instances are pooled and reset via [reset] instead of being reallocated
/// every time the world scrolls, per the perf guidelines.
class Segment {
  Segment(this.row) : left = LaneState.safe, right = LaneState.safe;

  int row;
  LaneState left;
  LaneState right;

  /// Freshness of a just-created platform (1 = just landed, 0 = fully
  /// settled). Purely cosmetic, drives the cooling-glow fade in the painter.
  double leftGlow = 0;
  double rightGlow = 0;

  /// Which object type formed the platform, purely for rendering the
  /// resting boulder/meteor silhouette once [FallingObject] itself has
  /// been retired back to its pool.
  FallingObjectType? leftLandedType;
  FallingObjectType? rightLandedType;

  /// Arbitrary integer chosen once at landing time, purely so the renderer
  /// can deterministically pick one of several cooled-platform sprite
  /// variants (`variant % variantCount`) without the model layer needing
  /// to know anything about sprite atlases.
  int leftPlatformVariant = 0;
  int rightPlatformVariant = 0;

  LaneState stateOf(Lane lane) => lane == Lane.left ? left : right;

  void setState(Lane lane, LaneState state) {
    if (lane == Lane.left) {
      left = state;
    } else {
      right = state;
    }
  }

  double glowOf(Lane lane) => lane == Lane.left ? leftGlow : rightGlow;

  void setGlow(Lane lane, double value) {
    if (lane == Lane.left) {
      leftGlow = value;
    } else {
      rightGlow = value;
    }
  }

  FallingObjectType? landedTypeOf(Lane lane) =>
      lane == Lane.left ? leftLandedType : rightLandedType;

  void setLandedType(Lane lane, FallingObjectType? type) {
    if (lane == Lane.left) {
      leftLandedType = type;
    } else {
      rightLandedType = type;
    }
  }

  int platformVariantOf(Lane lane) =>
      lane == Lane.left ? leftPlatformVariant : rightPlatformVariant;

  void setPlatformVariant(Lane lane, int variant) {
    if (lane == Lane.left) {
      leftPlatformVariant = variant;
    } else {
      rightPlatformVariant = variant;
    }
  }

  void reset(int newRow) {
    row = newRow;
    left = LaneState.safe;
    right = LaneState.safe;
    leftGlow = 0;
    rightGlow = 0;
    leftLandedType = null;
    rightLandedType = null;
    leftPlatformVariant = 0;
    rightPlatformVariant = 0;
  }
}
