import 'package:flutter/material.dart';

/// Shared chrome for every out-of-game screen: painted volcanic backdrop,
/// darkening veil so text stays legible, and a compact header with a back
/// button and an optional trailing widget.
class MenuScaffold extends StatelessWidget {
  const MenuScaffold({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.showBack = true,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool showBack;

  static const String backgroundAsset = 'assets/bg_location_3_asset.webp';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120A10),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(backgroundAsset, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xE6140A12), Color(0xF21A0C10)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(title: title, showBack: showBack, trailing: trailing),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.showBack,
    required this.trailing,
  });

  final String title;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(showBack ? 4 : 18, 4, 16, 4),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Back',
            ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
