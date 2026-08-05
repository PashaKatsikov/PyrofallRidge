import 'package:flutter/foundation.dart';

/// Immutable snapshot of the values the HUD renders.
///
/// Kept tiny and comparable so the [ValueNotifier] holding it only fires
/// listeners when a displayed number actually changes, not every frame.
@immutable
class HudSnapshot {
  const HudSnapshot({
    required this.heightMeters,
    required this.bestHeightMeters,
    required this.ridgeNumber,
    required this.embersThisRun,
    required this.totalEmbers,
    this.comboCount = 0,
    this.comboMultiplier = 1,
    this.shieldCharges = 0,
  });

  final int heightMeters;
  final int bestHeightMeters;
  final int ridgeNumber;

  /// Embers collected so far in the current run.
  final int embersThisRun;

  /// Embers collected across every run ever (persisted).
  final int totalEmbers;

  /// How many Embers the player has collected in a row without breaking the
  /// streak. Zero when no combo is active - the HUD hides the badge then.
  final int comboCount;

  /// The bonus factor being applied to newly collected Embers thanks to the
  /// current streak. `1` means "no bonus".
  final int comboMultiplier;

  /// Shield charges (from the upgrade shop) still unspent in this run. Zero
  /// hides the badge, which is also the case for a player who owns no shield.
  final int shieldCharges;

  static const HudSnapshot zero = HudSnapshot(
    heightMeters: 0,
    bestHeightMeters: 0,
    ridgeNumber: 1,
    embersThisRun: 0,
    totalEmbers: 0,
  );

  HudSnapshot copyWith({
    int? heightMeters,
    int? bestHeightMeters,
    int? ridgeNumber,
    int? embersThisRun,
    int? totalEmbers,
    int? comboCount,
    int? comboMultiplier,
    int? shieldCharges,
  }) {
    return HudSnapshot(
      heightMeters: heightMeters ?? this.heightMeters,
      bestHeightMeters: bestHeightMeters ?? this.bestHeightMeters,
      ridgeNumber: ridgeNumber ?? this.ridgeNumber,
      embersThisRun: embersThisRun ?? this.embersThisRun,
      totalEmbers: totalEmbers ?? this.totalEmbers,
      comboCount: comboCount ?? this.comboCount,
      comboMultiplier: comboMultiplier ?? this.comboMultiplier,
      shieldCharges: shieldCharges ?? this.shieldCharges,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HudSnapshot &&
      other.heightMeters == heightMeters &&
      other.bestHeightMeters == bestHeightMeters &&
      other.ridgeNumber == ridgeNumber &&
      other.embersThisRun == embersThisRun &&
      other.totalEmbers == totalEmbers &&
      other.comboCount == comboCount &&
      other.comboMultiplier == comboMultiplier &&
      other.shieldCharges == shieldCharges;

  @override
  int get hashCode => Object.hash(
        heightMeters,
        bestHeightMeters,
        ridgeNumber,
        embersThisRun,
        totalEmbers,
        comboCount,
        comboMultiplier,
        shieldCharges,
      );
}
