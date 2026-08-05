import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../rendering/item_sprites.dart';
import '../rendering/terrain_sprites.dart';
import '../rendering/vfx_sprites.dart';
import '../services/items_atlas_service.dart';
import '../services/lava_atlas_service.dart';
import '../services/terrain_atlas_service.dart';
import '../services/vfx_atlas_service.dart';
import '../widgets/menu_scaffold.dart';
import '../widgets/progress_badges.dart';

/// Explains the goal and every rule the player has to read off the screen,
/// illustrated with the exact same sprites the game itself draws.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuScaffold(
      title: 'HOW TO PLAY',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          const _Goal(),
          const SizedBox(height: 16),
          _Rule(
            image: TerrainAtlasService.instance
                .sprite(TerrainSprites.floorTile),
            fallback: Icons.swipe,
            title: 'Two lanes, one swipe',
            body: 'Your climber rises on their own. Swipe left or right to '
                'switch lane instantly - that is the only control.',
          ),
          _Rule(
            image: LavaAtlasService.instance.sprite(LavaSprites.lavaTile),
            fallback: Icons.warning_amber,
            title: 'Never stand in lava',
            body: 'Glowing cracked ground is lethal. Be in the other lane '
                'before you reach it. Lava never switches sides without '
                'leaving you clear rows to cross on, so there is always a way '
                'through.',
          ),
          _Rule(
            image: TerrainAtlasService.instance
                .sprite(TerrainSprites.meteorBody.first),
            fallback: Icons.trip_origin,
            title: 'Rocks and meteors are both',
            body: 'While falling they kill on contact. Once they land they '
                'cool down into solid ground you can climb over - a meteor '
                'even bridges a wide lava stretch.',
          ),
          _Rule(
            image: TerrainAtlasService.instance
                .sprite(TerrainSprites.meteorBody.last),
            fallback: Icons.crisis_alert,
            title: 'Some meteors chase you',
            body: 'A meteor ringed in red follows your lane while it is '
                'winding up and locks on the instant it drops - change lane '
                'before the ring stops moving to survive it.',
          ),
          _Rule(
            image: VfxAtlasService.instance.cell(
                VfxSprites.telegraphRing.first.row,
                VfxSprites.telegraphRing.first.col),
            fallback: Icons.adjust,
            title: 'Watch the marker',
            body: 'Every impact is announced by a pulsing ring on the ground '
                'and a dot at the top of the screen. You always get time to '
                'react, and both lanes are never blocked at once.',
          ),
          _Rule(
            image: null,
            fallback: Icons.arrow_upward,
            title: 'Ride the updrafts',
            body: 'Rare columns of hot air lift you several segments fast. '
                'They are harmless, and while riding one you float safely '
                'over the ground below.',
          ),
          _Rule(
            image: ItemsAtlasService.instance
                .cell(ItemSprites.crystal.first.row, ItemSprites.crystal.first.col),
            fallback: Icons.diamond,
            title: 'Collect Embers',
            body: 'Shards, gems, crystals and chests are worth 1, 5, 25 and '
                '50 Embers. They only ever sit on safe ground.',
          ),
          _Rule(
            image: ItemsAtlasService.instance
                .cell(ItemSprites.uiCurrency.row, ItemSprites.uiCurrency.col),
            fallback: Icons.local_fire_department,
            title: 'Chain them for a multiplier',
            body: 'Grabbing Embers in a row without letting the streak lapse '
                'pays out x2, x3 and x4 the value. Miss one for too long, or '
                'die, and the combo resets.',
          ),
          _Rule(
            image: ItemsAtlasService.instance
                .cell(ItemSprites.uiLevel.row, ItemSprites.uiLevel.col),
            fallback: Icons.military_tech,
            title: 'Levels unlock skins',
            body: 'Every metre climbed and every Ember collected is XP, and '
                'levels are the only way to unlock new climbers.',
          ),
          _Rule(
            image: ItemsAtlasService.instance
                .cell(ItemSprites.uiShop.row, ItemSprites.uiShop.col),
            fallback: Icons.upgrade_rounded,
            title: 'Spend Embers on upgrades',
            body: 'The Upgrades screen trades Embers for permanent boosts: a '
                'shield that absorbs one deadly hit per charge, a wider pickup '
                'reach, a longer combo window, richer Embers and faster XP. '
                'Embers are only ever earned by playing - nothing in the game '
                'costs real money.',
          ),
        ],
      ),
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccent.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR GOAL',
            style: TextStyle(
              color: kAccent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The mountain is collapsing upward. Climb as high as you can '
            'before it takes you, gather Embers on the way, and push your '
            'record one Ridge further every run.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({
    required this.image,
    required this.fallback,
    required this.title,
    required this.body,
  });

  final ui.Image? image;
  final IconData fallback;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: image != null
                ? RawImage(image: image, fit: BoxFit.contain)
                : Icon(fallback, color: kAccent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
