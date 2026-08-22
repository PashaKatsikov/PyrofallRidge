import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../infra/signal_probe.dart';

/// No-internet screen. Retry re-runs the whole boot pipeline by pushing a
/// fresh [retryBuilder] using THIS page's own (mounted) context. Self-contained
/// painted background — no external artwork.
class OfflineScreen extends StatefulWidget {
  const OfflineScreen({
    super.key,
    required this.probe,
    required this.retryBuilder,
  });

  final SignalProbe probe;
  final WidgetBuilder retryBuilder;

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _checking = false;
  bool _stillOffline = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _retry() async {
    if (_checking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _checking = true;
      _stillOffline = false;
    });
    bool online = false;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (!mounted) return;
    if (online) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: widget.retryBuilder),
      );
      return;
    }
    setState(() {
      _checking = false;
      _stillOffline = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final width = landscape
        ? (media.size.width * 0.36).clamp(280.0, 460.0)
        : (media.size.width * 0.66).clamp(240.0, 400.0);

    return Scaffold(
      backgroundColor: const Color(0xFF120A10),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _OfflineBackdrop(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: landscape ? 44 : 28),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Center(child: _OfflineCopy(landscape: landscape)),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: landscape ? 16 : 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _RetryButton(
                          width: width,
                          height: landscape ? 62 : 70,
                          busy: _checking,
                          onTap: _retry,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 235),
                          child: _stillOffline
                              ? const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Still offline — check your connection',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      shadows: <Shadow>[
                                        Shadow(color: Colors.black, blurRadius: 5),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
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

class _OfflineCopy extends StatelessWidget {
  const _OfflineCopy({required this.landscape});

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
              colors: <Color>[Color(0xFF5B4B44), Color(0xFF241A18)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(color: Color(0x66000000), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Icon(
            Icons.wifi_off_rounded,
            size: landscape ? 44 : 56,
            color: const Color(0xFFFFC24C),
          ),
        ),
        SizedBox(height: landscape ? 18 : 28),
        Text(
          'NO INTERNET CONNECTION',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFFFF3D6),
            fontSize: landscape ? 24 : 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            height: 1.2,
            shadows: const <Shadow>[
              Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Check your connection and try again',
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

class _OfflineBackdrop extends StatelessWidget {
  const _OfflineBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF1A1420),
            Color(0xFF2A1A22),
            Color(0xFF3A1E1A),
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.width,
    required this.height,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
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
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFFCC45), Color(0xFFFF762D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF61301C), width: 3),
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
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Color(0xFF422014),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.refresh_rounded,
                            color: Color(0xFF422014), size: 26),
                        SizedBox(width: 10),
                        Text(
                          'RETRY',
                          style: TextStyle(
                            color: Color(0xFF422014),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
