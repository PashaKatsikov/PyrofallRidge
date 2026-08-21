import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/ridge_relay_config.dart';
import '../infra/ember_vault.dart';
import '../infra/pulse_relay.dart';

/// Push opt-in promo shown once before the online content on the gray path.
/// Self-contained painted background (volcanic palette) — no external artwork.
class NudgeScreen extends StatefulWidget {
  const NudgeScreen({
    super.key,
    required this.vault,
    required this.pulse,
    required this.nextBuilder,
    this.onTokenReady,
  });

  final EmberVault vault;
  final PulseRelay pulse;
  final WidgetBuilder nextBuilder;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<NudgeScreen> createState() => _NudgeScreenState();
}

class _NudgeScreenState extends State<NudgeScreen> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The splash locks portrait right before routing here; re-enable landscape
    // so the screen rotates with the device.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final granted = await widget.pulse.askPermission();
    final token = widget.pulse.token;
    if (granted && token != null && token.isNotEmpty) {
      await widget.onTokenReady?.call(token);
    }
    if (!granted) await _snooze();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        RidgeRelayConfig.pushSnoozeSeconds;
    return widget.vault.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: widget.nextBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final width = landscape
        ? (media.size.width * 0.44).clamp(320.0, 560.0)
        : (media.size.width * 0.82).clamp(280.0, 460.0);

    return Scaffold(
      backgroundColor: const Color(0xFF120A10),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _VolcanicBackdrop(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: landscape ? 44 : 28),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: _NudgeCopy(landscape: landscape),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: landscape ? 14 : 34),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _EmberButton(
                          width: width,
                          height: landscape ? 62 : 72,
                          fontSize: landscape ? 21 : 24,
                          label: 'ACCEPT',
                          emphasized: true,
                          busy: _working,
                          onTap: _accept,
                        ),
                        SizedBox(height: landscape ? 10 : 14),
                        _EmberButton(
                          width: width * 0.9,
                          height: landscape ? 54 : 60,
                          fontSize: landscape ? 18 : 20,
                          label: 'SKIP',
                          emphasized: false,
                          busy: false,
                          onTap: _skip,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NudgeCopy extends StatelessWidget {
  const _NudgeCopy({required this.landscape});

  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: landscape ? 84 : 108,
          height: landscape ? 84 : 108,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[Color(0xFFFFC24C), Color(0xFFFF5B1F)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x88FF5B1F),
                blurRadius: 34,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.notifications_active_rounded,
            size: landscape ? 44 : 56,
            color: const Color(0xFF3D1C12),
          ),
        ),
        SizedBox(height: landscape ? 18 : 28),
        Text(
          'ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFFFF3D6),
            fontSize: landscape ? 22 : 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            height: 1.2,
            shadows: const <Shadow>[
              Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Stay tuned for special offers and rewards',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFE7C9A6),
            fontSize: landscape ? 15 : 17,
            fontWeight: FontWeight.w600,
            height: 1.35,
            shadows: const <Shadow>[
              Shadow(color: Colors.black87, blurRadius: 6),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared painted backdrop: dark stone fading to a hot magma glow at the base.
class _VolcanicBackdrop extends StatelessWidget {
  const _VolcanicBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF1A1420),
            Color(0xFF3A1E1A),
            Color(0xFF7A1200),
          ],
          stops: <double>[0.0, 0.62, 1.0],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _EmberButton extends StatelessWidget {
  const _EmberButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.label,
    required this.emphasized,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final double fontSize;
  final String label;
  final bool emphasized;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: emphasized
                ? const <Color>[Color(0xFFFFCF4A), Color(0xFFFF7D2C)]
                : const <Color>[Color(0xFF6B4A44), Color(0xFF37282A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: emphasized ? const Color(0xFF6E301B) : const Color(0xFF241A18),
            width: 3,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Color(0xFF4A2315),
                      ),
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: emphasized
                            ? const Color(0xFF3D1C12)
                            : const Color(0xFFFFE8D2),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        height: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
