import 'dart:math';

import 'package:flutter/widgets.dart';

/// Shared layout tuning for a UI that was designed against phone-sized
/// viewports and has to look intentional on an iPad too.
///
/// The whole game (playfield proportions, menu grids, card widths, sprite
/// sizes) was tuned against phone widths of roughly 360-430 logical pixels.
/// There are two bad ways to put that on a 1024x1366 iPad: stretch it, which
/// blows every proportion out; or pin it to phone size and centre it, which
/// leaves a postage stamp floating in a sea of background.
///
/// So instead everything scales. A single [uiScale] factor - derived from how
/// much bigger the viewport is than the phone the design targets - drives the
/// menu column width and typography, and [worldScale] does the same for the
/// playfield, applied as one canvas transform so the simulation itself never
/// has to know what device it is on. An iPad player sees the same amount of
/// ridge as a phone player, just bigger.
class LayoutConfig {
  LayoutConfig._();

  /// The viewport the design targets: a large modern phone in portrait.
  static const double _designWidth = 430;
  static const double _designHeight = 860;

  /// Widest a phone in portrait realistically gets, plus a little slack.
  /// Anything narrower than this (basically every phone) is unaffected.
  static const double maxContentWidth = 460;

  /// How much larger than a phone this viewport is, clamped so a tablet never
  /// turns the UI into a cartoon and a small phone never shrinks it.
  ///
  /// Bounded by *both* axes: scaling menus off the bottom of a short-but-wide
  /// window would be just as broken as overflowing a narrow one.
  static double uiScale(Size size) {
    if (size.isEmpty) return 1;
    final double raw = min(size.width / _designWidth, size.height / _designHeight);
    return raw.clamp(1.0, 1.45).toDouble();
  }

  /// Scale applied to the whole playfield canvas.
  ///
  /// Allowed to go further than [uiScale] because the playfield is the thing
  /// the player is actually staring at, and because scaling it is what keeps
  /// the *amount of visible ridge* constant: without it an iPad would show
  /// nearly twice as many segments as a phone and quietly become an easier
  /// game.
  static double worldScale(Size size) {
    if (size.isEmpty) return 1;
    final double raw = min(size.width / _designWidth, size.height / _designHeight);
    return raw.clamp(1.0, 2.0).toDouble();
  }

  /// The viewport the simulation and the painter both work in: real pixels
  /// divided by [worldScale].
  ///
  /// The game controller must be given *this* size rather than the raw
  /// constraints, because it uses viewport height to decide how far ahead to
  /// spawn and how far behind to recycle.
  static Size worldViewport(Size size) {
    final double scale = worldScale(size);
    return Size(size.width / scale, size.height / scale);
  }

  /// Width the centred menu column is allowed to occupy.
  static double contentWidth(Size size) =>
      min(size.width, maxContentWidth * uiScale(size));

  /// The ambient text scaler multiplied by [uiScale], so tablet typography
  /// grows with the layout while still honouring the player's accessibility
  /// text-size setting.
  static TextScaler textScaler(BuildContext context, Size size) {
    final double scale = uiScale(size);
    final TextScaler ambient = MediaQuery.textScalerOf(context);
    if (scale == 1) return ambient;
    return _MultipliedTextScaler(ambient, scale);
  }
}

class _MultipliedTextScaler extends TextScaler {
  const _MultipliedTextScaler(this._inner, this._factor);

  final TextScaler _inner;
  final double _factor;

  @override
  double scale(double fontSize) => _inner.scale(fontSize * _factor);

  @Deprecated('Only implemented to satisfy the TextScaler interface.')
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => _inner.textScaleFactor * _factor;

  @override
  bool operator ==(Object other) =>
      other is _MultipliedTextScaler &&
      other._inner == _inner &&
      other._factor == _factor;

  @override
  int get hashCode => Object.hash(_inner, _factor);
}
