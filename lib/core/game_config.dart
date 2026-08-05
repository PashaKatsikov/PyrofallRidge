/// Central tuning constants for the MVP gameplay loop.
///
/// Keeping every magic number in one place makes it easy to balance the
/// first minute of play (see the design brief) without hunting through the
/// simulation code.
class GameConfig {
  GameConfig._();

  // --- World / lanes -------------------------------------------------
  static const int laneCount = 2;

  /// Height (in logical pixels) of a single vertical world segment.
  static const double segmentHeight = 60;

  /// How many segments the world keeps generated above the player.
  ///
  /// Must comfortably exceed the worst-case spawn look-ahead distance (see
  /// [SpawnDirector]: telegraph + fall + buffer at max rise speed, plus the
  /// hazard-spacing search window) so a target row is always already
  /// generated when the spawn director wants to use it.
  static const int lookAheadSegments = 28;

  /// How many segments below the camera are kept before being recycled.
  static const int cleanupMarginSegments = 4;

  // --- Player ----------------------------------------------------------
  /// Fraction of the screen height where the player is anchored (from top).
  static const double playerAnchorFraction = 0.66;

  /// Base auto-climb speed in logical px/sec.
  static const double baseRiseSpeed = 84;

  /// Maximum auto-climb speed bonus granted purely by height.
  static const double maxRiseSpeedBonus = 96;

  /// Meters-per-height-unit growth rate for the rise speed curve.
  ///
  /// Deliberately shallow so the climb keeps accelerating for the first few
  /// hundred metres instead of hitting its ceiling within the first minute:
  /// the speed cap is reached around 320 m, which is where the ridge stops
  /// getting faster and only gets busier.
  static const double riseSpeedGrowthPerMeter = 0.3;

  /// Horizontal half-width of a lane, used for player + object drawing.
  static const double playerHalfWidth = 16;
  static const double playerHalfHeight = 20;

  // --- Swipe controls ----------------------------------------------------
  static const double swipeThreshold = 18;
  static const double laneChangeAnimationSeconds = 0.16;

  // --- Falling objects: shared -----------------------------------------
  static const double impactDuration = 0.16;
  static const double landedFlashDuration = 0.35;
  static const int maxActiveFallingObjects = 4;

  /// Extra lead time (seconds) added on top of telegraph+fall duration when
  /// picking how many segments ahead an object should target, guaranteeing
  /// the player always has margin to react even if rise speed fluctuates.
  static const double spawnSafetyBufferSeconds = 0.35;

  /// Minimum number of rows required between the target rows of any two
  /// simultaneously active (non-landed) falling objects, regardless of
  /// lane. This guarantees their "falling" danger windows never overlap in
  /// time as the player passes through, so the two lanes can never both be
  /// blocked at once (see bugfix: diagonal meteors from both sides).
  static const int minHazardRowGap = 3;

  /// Hard floor for reaction time, never crossed regardless of difficulty.
  static const double absoluteMinReactionSeconds = 0.7;

  // --- Rockfall ----------------------------------------------------------
  static const double rockfallTelegraphMin = 1.0;
  static const double rockfallTelegraphMax = 1.35;
  static const double rockfallFallDuration = 0.5;
  static const double rockfallHalfWidth = 15;

  // --- Meteor --------------------------------------------------------
  static const double meteorTelegraphMin = 1.2;
  static const double meteorTelegraphMax = 1.65;
  static const double meteorFallDuration = 0.4;
  static const double meteorHalfWidth = 24;
  /// Meteor platforms are wider than the lane itself, bridging danger.
  static const double meteorPlatformBonusWidth = 20;

  // --- Homing meteor --------------------------------------------------
  /// Base probability that a meteor is a homing meteor (tracks the player's
  /// lane during its telegraph). Scaled up by the difficulty curve.
  static const double homingMeteorBaseChance = 0.30;
  static const double homingMeteorMaxChance = 0.72;

  /// Extra telegraph time a homing meteor gets on top of the standard range,
  /// so the player always has a reaction window even if they only realize the
  /// meteor is chasing them halfway through the wind-up.
  static const double homingMeteorExtraTelegraph = 0.28;

  // --- Difficulty curve -------------------------------------------------
  /// Height (in meters) at which difficulty scaling reaches its cap. Reached
  /// roughly a minute into a run: the climb tops out its speed at ~320 m, and
  /// the rest of the ramp is spent getting steadily busier at that speed.
  static const double difficultyRampMeters = 850;

  static const double minSpawnInterval = 1.0;
  static const double maxSpawnInterval = 2.0;

  static const double minDangerChance = 0.18;
  static const double maxDangerChance = 0.56;

  static const double minFallSpeedMultiplier = 1.0;
  static const double maxFallSpeedMultiplier = 1.6;

  // --- Updraft ------------------------------------------------------------
  /// How many segments tall a single updraft column is.
  static const int updraftSpanRows = 3;

  static const double updraftTelegraphMin = 1.3;
  static const double updraftTelegraphMax = 1.7;

  /// How long an updraft stays usable once active. Long enough that reaching a
  /// telegraphed column is not a precision challenge, short enough that it
  /// cannot be leaned on to skip a whole dangerous stretch.
  static const double updraftActiveDuration = 2.5;

  /// Cosmetic fade-out once expired.
  static const double updraftFadeDuration = 0.4;

  /// Extra rise speed (px/s) added on top of the normal auto-climb speed
  /// while the player is inside an active updraft in its lane.
  static const double updraftBoostSpeedBonus = 260;

  /// Fraction of the lane width the visual column occupies.
  static const double updraftColumnWidthFactor = 0.6;

  /// Rows of clearance that must stay free of any falling-object hazard
  /// both below and above an updraft's span, and vice versa. This is what
  /// guarantees an updraft can never fling the player into (or right up
  /// against) a falling hazard without a normal reaction window.
  static const int updraftSafetyMarginRows = 3;

  static const int maxActiveUpdrafts = 1;

  /// The very first updraft of a run appears within this window.
  static const double firstUpdraftMinSeconds = 40;
  static const double firstUpdraftMaxSeconds = 62;

  /// Updrafts are rare after the first one too.
  static const double updraftMinIntervalSeconds = 30;
  static const double updraftMaxIntervalSeconds = 46;

  // --- VFX -----------------------------------------------------------------
  static const int maxActiveVfx = 12;
  static const double ambientSmokeMinInterval = 5;
  static const double ambientSmokeMaxInterval = 11;
  static const int maxAmbientSmoke = 2;

  // --- Pickups (Embers currency) -------------------------------------------
  static const int maxActivePickups = 10;

  /// Average vertical spacing between pickups, in segments. Wider than the
  /// rows-per-second the climb covers, so a full streak means actually going
  /// out of the way for Embers instead of collecting them by standing still.
  static const double pickupMinRowGap = 4;
  static const double pickupMaxRowGap = 7;

  /// A pickup is never placed within this many rows of an active hazard's
  /// target row.
  static const int pickupHazardClearanceRows = 2;

  static const double pickupBobAmplitude = 4;
  static const double pickupBobSpeed = 2.4;

  static const int shardValue = 1;
  static const int gemValue = 5;
  static const int crystalValue = 25;
  static const int chestValue = 50;

  // Spawn weights (relative, not percentages) - shard common, chest rare.
  static const double shardWeight = 60;
  static const double gemWeight = 27;
  static const double crystalWeight = 11;
  static const double chestWeight = 2;

  static const double floatingTextDuration = 0.9;
  static const double collectBlipDuration = 0.28;
  static const int maxActiveFloatingTexts = 8;

  // --- Ember combo ---------------------------------------------------------
  /// How long, in seconds, the player has between two Ember pickups before
  /// the combo streak resets.
  static const double comboDecaySeconds = 5.5;

  /// Number of Embers-in-a-row needed to bump the multiplier one step. Steps
  /// stack up to [comboMaxMultiplier].
  static const int comboStep = 3;
  static const int comboMaxMultiplier = 4;

  // --- Shield upgrade -------------------------------------------------------
  /// Immunity granted by spending one shield charge. Long enough to swipe out
  /// of a lava lane and settle on solid ground, short enough that a stack of
  /// charges is not simply a free pass through a whole stretch of the ridge.
  static const double shieldGraceSeconds = 1.2;

  // --- Score -------------------------------------------------------------
  /// World px per displayed "meter" of height.
  static const double pixelsPerMeter = 12;

  /// Meters between each "Ridge N" milestone shown in the HUD.
  static const double metersPerRidge = 100;

  // --- Frame timing -------------------------------------------------
  static const double maxDeltaSeconds = 0.033;
}
