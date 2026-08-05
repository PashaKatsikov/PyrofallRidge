import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Renders a pre-sliced atlas sprite as a normal widget-tree icon, falling
/// back to a plain [Icon] whenever the sprite hasn't loaded yet (or failed
/// to) so menus/HUD never show a blank gap.
class AtlasIcon extends StatelessWidget {
  const AtlasIcon({
    super.key,
    required this.image,
    required this.size,
    this.fallback = Icons.circle,
    this.fallbackColor = Colors.white54,
  });

  final ui.Image? image;
  final double size;
  final IconData fallback;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final ui.Image? img = image;
    if (img == null) {
      return Icon(fallback, size: size, color: fallbackColor);
    }
    return SizedBox(
      width: size,
      height: size,
      child: RawImage(image: img, fit: BoxFit.contain),
    );
  }
}
