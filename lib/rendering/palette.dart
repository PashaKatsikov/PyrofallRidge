import 'dart:ui';

/// All colors used by the hand-drawn (no external assets) game canvas.
///
/// Kept centralized and primitive (solid colors / simple gradients) per the
/// "silhouettes over detail" visual direction and the performance budget.
class Palette {
  Palette._();

  // Background sky, dark stone fading to a hot glow near the ground.
  static const Color skyTop = Color(0xFF1A1420);
  static const Color skyMid = Color(0xFF3A1E1A);
  static const Color skyGlow = Color(0xFFAD4A1E);

  // Void beyond the ridge lanes.
  static const Color voidColor = Color(0xFF120A10);

  // Safe basalt ground.
  static const Color safeTop = Color(0xFF5B4B44);
  static const Color safeBottom = Color(0xFF37282A);
  static const Color safeHighlight = Color(0xFF7A6659);

  // Danger: magma / chasm.
  static const Color dangerCore = Color(0xFFFF5B1F);
  static const Color dangerHot = Color(0xFFFFC24C);
  static const Color dangerDeep = Color(0xFF7A1200);

  // Platform: cooling landed rock.
  static const Color platformBase = Color(0xFF41332F);
  static const Color platformEdge = Color(0xFF241A18);
  static const Color glowHot = Color(0xFFFFA24A);

  // Falling hazards.
  static const Color rockfallCore = Color(0xFFFF7A3C);
  static const Color rockfallEdge = Color(0xFF8A2E10);
  static const Color meteorCore = Color(0xFFFFE066);
  static const Color meteorEdge = Color(0xFFFF4B1F);

  // Telegraph markers.
  static const Color telegraphZone = Color(0xB3FF3B1A);
  static const Color telegraphRing = Color(0xFFFFD24C);

  // Player.
  static const Color playerCore = Color(0xFFFFF3D6);
  static const Color playerFlame = Color(0xFFFFA033);
  static const Color playerOutline = Color(0xFF1A0F0A);

  // Lane divider.
  static const Color divider = Color(0x66FFB37A);

  // Updraft: warm rising air current.
  static const Color updraftCore = Color(0xFFFFC24C);
  static const Color updraftEdge = Color(0xFFFF8A3C);
  static const Color updraftStripe = Color(0xFFFFF3D0);

  // Atmospheric particles.
  static const Color emberHot = Color(0xFFFFD98A);
  static const Color emberCool = Color(0xFFFF5F2E);
  static const Color ash = Color(0xFF9A8C86);
  static const Color dust = Color(0xFF8A7166);
  static const Color sparkHot = Color(0xFFFFF6DC);
}
