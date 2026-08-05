import '../core/game_config.dart';
import '../rendering/item_sprites.dart';
import 'lane.dart';

/// Cosmetic collectible currency ("Embers"). Purely economy/cosmetic - never
/// affects difficulty, collisions or the core loop.
enum PickupType { shard, gem, crystal, chest }

extension PickupTypeX on PickupType {
  int get value {
    switch (this) {
      case PickupType.shard:
        return GameConfig.shardValue;
      case PickupType.gem:
        return GameConfig.gemValue;
      case PickupType.crystal:
        return GameConfig.crystalValue;
      case PickupType.chest:
        return GameConfig.chestValue;
    }
  }

  double get spawnWeight {
    switch (this) {
      case PickupType.shard:
        return GameConfig.shardWeight;
      case PickupType.gem:
        return GameConfig.gemWeight;
      case PickupType.crystal:
        return GameConfig.crystalWeight;
      case PickupType.chest:
        return GameConfig.chestWeight;
    }
  }

  List<ItemCoord> get spriteOptions {
    switch (this) {
      case PickupType.shard:
        return ItemSprites.shard;
      case PickupType.gem:
        return ItemSprites.gem;
      case PickupType.crystal:
        return ItemSprites.crystal;
      case PickupType.chest:
        return <ItemCoord>[ItemSprites.chest];
    }
  }
}

/// A single pooled collectible instance sitting on a specific lane/row.
class Pickup {
  Pickup();

  PickupType type = PickupType.shard;
  Lane lane = Lane.left;
  int row = 0;
  double worldY = 0;
  ItemCoord sprite = ItemSprites.shard.first;

  /// Random phase offset so multiple pickups don't bob in perfect unison.
  double bobPhase = 0;

  /// Seconds since this pickup spawned, purely to drive the bob/pulse
  /// animation - never touched by gameplay logic.
  double age = 0;

  bool active = false;

  void reset({
    required PickupType type,
    required Lane lane,
    required int row,
    required double worldY,
    required ItemCoord sprite,
    required double bobPhase,
  }) {
    this.type = type;
    this.lane = lane;
    this.row = row;
    this.worldY = worldY;
    this.sprite = sprite;
    this.bobPhase = bobPhase;
    age = 0;
    active = true;
  }
}
