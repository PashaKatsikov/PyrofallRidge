import 'dart:math';

import 'package:flutter/material.dart';

import '../core/layout_config.dart';
import '../rendering/item_sprites.dart';
import '../services/items_atlas_service.dart';
import '../services/progress_service.dart';
import '../widgets/atlas_icon.dart';
import '../widgets/menu_scaffold.dart';
import '../widgets/menu_tile.dart';
import '../widgets/progress_badges.dart';
import 'daily_reward_screen.dart';
import 'game_screen.dart';
import 'goals_screen.dart';
import 'how_to_play_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'skins_screen.dart';

/// The app's home once loading finishes: branding, the player's level and
/// Embers, one big PLAY button and the entrances to every meta section.
///
/// Everything reachable from here is offline and local - there is no network,
/// account or purchase anywhere in the game.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF120A10),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(MenuScaffold.backgroundAsset, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xD9140A12), Color(0xF01A0C10)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: LayoutConfig.contentWidth(size),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: LayoutConfig.textScaler(context, size),
                  ),
                  child: AnimatedBuilder(
                    animation: ProgressService.instance,
                    builder: (context, _) => _MenuBody(onOpen: _open),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuBody extends StatelessWidget {
  const _MenuBody({required this.onOpen});

  final void Function(BuildContext, Widget) onOpen;

  @override
  Widget build(BuildContext context) {
    final ProgressService progress = ProgressService.instance;
    final double scale = LayoutConfig.uiScale(MediaQuery.sizeOf(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        // The wordmark is the one element with slack in it, so it absorbs the
        // difference between a tall phone and a short one - which is what keeps
        // the whole menu on a single screen instead of hiding the bottom row of
        // tiles below a scroll the player has no reason to expect.
        final double logoWidth = min(
          210 * scale,
          constraints.maxHeight * 0.235,
        );
        final double gap = (constraints.maxHeight * 0.018).clamp(8.0, 22.0);
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 8),
          child: Column(
            children: [
              Row(
                children: const [
                  Expanded(child: LevelPanel(compact: true)),
                  SizedBox(width: 10),
                  EmbersBadge(),
                ],
              ),
              SizedBox(height: gap),
              _BreathingLogo(width: logoWidth),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AtlasIcon(
                    image: ItemsAtlasService.instance.cell(
                      ItemSprites.uiTitleEmblem.row,
                      ItemSprites.uiTitleEmblem.col,
                    ),
                    size: 15,
                    fallback: Icons.auto_awesome,
                    fallbackColor: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Climb as high as the mountain allows',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: gap * 0.7),
              _BestHeightLine(meters: progress.bestHeightMeters),
              SizedBox(height: gap),
              PrimaryButton(
                label: 'PLAY',
                width: 220,
                onTap: () => onOpen(context, const GameScreen()),
              ),
              const SizedBox(height: 10),
              // Kept out of the tile grid below so that grid stays two even rows,
              // and because spending Embers deserves to sit next to PLAY.
              PrimaryButton(
                label: 'UPGRADES',
                icon: Icons.upgrade_rounded,
                filled: false,
                width: 220,
                onTap: () => onOpen(context, const ShopScreen()),
              ),
              SizedBox(height: gap),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.02,
                children: [
                  MenuTile(
                    label: 'SKINS',
                    icon: ItemSprites.uiSkinsButton,
                    fallbackIcon: Icons.face_retouching_natural,
                    onTap: () => onOpen(context, const SkinsScreen()),
                  ),
                  MenuTile(
                    label: 'GOALS',
                    icon: ItemSprites.uiGoals,
                    fallbackIcon: Icons.flag,
                    badge: progress.claimableGoalCount > 0,
                    onTap: () => onOpen(context, const GoalsScreen()),
                  ),
                  MenuTile(
                    label: 'DAILY',
                    icon: ItemSprites.uiDaily,
                    fallbackIcon: Icons.card_giftcard,
                    badge: progress.canClaimDaily,
                    onTap: () => onOpen(context, const DailyRewardScreen()),
                  ),
                  MenuTile(
                    label: 'RANKING',
                    icon: ItemSprites.uiLeaderboard,
                    fallbackIcon: Icons.leaderboard,
                    onTap: () => onOpen(context, const LeaderboardScreen()),
                  ),
                  MenuTile(
                    label: 'HOW TO PLAY',
                    icon: ItemSprites.uiHowToPlay,
                    fallbackIcon: Icons.help_outline,
                    onTap: () => onOpen(context, const HowToPlayScreen()),
                  ),
                  MenuTile(
                    label: 'SETTINGS',
                    icon: ItemSprites.uiSettings,
                    fallbackIcon: Icons.settings,
                    onTap: () => onOpen(context, const SettingsScreen()),
                  ),
                ],
              ),
              SizedBox(height: gap * 0.5),
            ],
          ),
        );
      },
    );
  }
}

/// The wordmark, breathing very slowly.
///
/// A perfectly still title on an otherwise animated menu is the one thing that
/// makes a game look like a mock-up, and the movement is small enough that it
/// never competes with the PLAY button for attention.
class _BreathingLogo extends StatefulWidget {
  const _BreathingLogo({required this.width});

  final double width;

  @override
  State<_BreathingLogo> createState() => _BreathingLogoState();
}

class _BreathingLogoState extends State<_BreathingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.985,
        end: 1.02,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Image.asset(
        'assets/Game_Name.webp',
        width: widget.width,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _BestHeightLine extends StatelessWidget {
  const _BestHeightLine({required this.meters});

  final int meters;

  @override
  Widget build(BuildContext context) {
    if (meters <= 0) {
      return Text(
        'No climb recorded yet',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AtlasIcon(
          image: ItemsAtlasService.instance.cell(
            ItemSprites.uiHeight.row,
            ItemSprites.uiHeight.col,
          ),
          size: 16,
          fallback: Icons.terrain,
          fallbackColor: kAccent,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'Best height  $meters m',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
