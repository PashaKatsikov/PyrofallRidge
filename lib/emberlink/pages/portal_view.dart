import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../infra/ember_agent.dart';
import '../infra/ember_vault.dart';
import '../infra/pulse_relay.dart';
import '../infra/signal_probe.dart';
import 'offline_screen.dart';

/// Full-screen WebView shell for the online flow. Owns safe-area handling,
/// native-feel JS injections, rotation reflow, offline fallback and the
/// cold-start viewport fix.
class PortalView extends StatefulWidget {
  const PortalView({
    super.key,
    required this.url,
    required this.vault,
    required this.probe,
    required this.pulse,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final EmberVault vault;
  final SignalProbe probe;
  final PulseRelay pulse;
  final EmberAgent agent;
  final bool coldLaunch;

  @override
  State<PortalView> createState() => _PortalViewState();
}

class _PortalViewState extends State<PortalView> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _coldReloadIssued = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Inline playback is a creation parameter rather than an injected script,
    // so the page never has to be touched for it.
    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(widget.agent.userAgent)
          ..enableZoom(false)
          ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    widget.pulse.onDestination = (url) {
      final uri = Uri.tryParse(url);
      if (mounted && uri != null && uri.hasScheme) {
        _controller.loadRequest(uri);
      }
    };
    _networkSubscription = widget.probe.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        _goOffline();
      }
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    // Let immersive mode settle in the phone's ACTUAL orientation before the
    // WebView mounts so WKWebView measures the correct viewport — no rotation
    // nudge (which made cold-start links open sideways then flip).
    await Future<void>.delayed(const Duration(milliseconds: 415));
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
    _metricsDebounce?.cancel();
    _pokeReflow(const <int>[75, 215, 445, 690, 985]);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller.runJavaScript(
          'window.dispatchEvent(new Event("orientationchange"));'
          'window.dispatchEvent(new Event("resize"));'
          'if(window.visualViewport)'
          '  window.visualViewport.dispatchEvent(new Event("resize"));',
        ).catchError((_) {});
      });
    }
    _metricsDebounce = Timer(const Duration(milliseconds: 425), () {
      if (!mounted) return;
      _syncNativeFeel();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _consumePending();
    }
  }

  Future<void> _consumePending() async {
    final value = await widget.vault.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (mounted && uri != null && uri.hasScheme) {
      await _controller.loadRequest(uri);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _syncNativeFeel();
        Future<void>.delayed(const Duration(milliseconds: 1035), () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _syncNativeFeel();
          if (widget.coldLaunch && !_coldReloadIssued) {
            _coldReloadIssued = true;
            await _controller.reload();
          }
        });
      },
      onWebResourceError: (error) {
        if (error.errorCode == -999) return; // cancelled
        // WKWebView may report isForMainFrame as null for the main navigation
        // — treat null as main-frame so a real failure is never swallowed.
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop = error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        if (redirectLoop && _lastMainUrl != null && _redirectAttempts < 4) {
          _redirectAttempts++;
          _controller.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        if (!mainFrame) return;
        _showOfflineAfterProbe();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        if (uri.scheme == 'javascript') return NavigationDecision.prevent;
        if (<String>{
          'http',
          'https',
          'about',
          'data',
          'blob',
        }.contains(uri.scheme)) {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    );
  }

  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    bool online = true;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineScreen(
          probe: widget.probe,
          retryBuilder: (_) => PortalView(
            url: current,
            vault: widget.vault,
            probe: widget.probe,
            pulse: widget.pulse,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  /// Installs the whole native-feel bundle in a single pass and leaves an
  /// idempotent `window.__rdgSync` behind. Calling this again after a reflow or
  /// a page load only re-asserts the viewport/inset state — the listeners and
  /// stylesheets are attached exactly once.
  void _syncNativeFeel() {
    _controller.runJavaScript(_nativeFeelScript).catchError((_) {});
  }

  static const String _nativeFeelScript = r'''
(() => {
  const w = window;
  if (w.__rdgSync) { w.__rdgSync(); return; }

  const nativeOnly = ':not(input):not(textarea):not([contenteditable="true"])';
  const insetVars = [
    'safe-area-inset-top', 'safe-area-inset-right',
    'safe-area-inset-bottom', 'safe-area-inset-left',
    'sat', 'sar', 'sab', 'sal',
    'safe-top', 'safe-right', 'safe-bottom', 'safe-left',
  ].map((n) => `--${n}:0px!important;`).join('');

  const host = () => document.head || document.documentElement;

  const sheet = (id, css) => {
    const parent = host();
    if (!parent) return;
    let node = document.getElementById(id);
    if (!node) {
      node = document.createElement('style');
      node.id = id;
      parent.appendChild(node);
    }
    if (node.textContent !== css) node.textContent = css;
  };

  const typing = () => {
    const vv = w.visualViewport;
    return !!vv && vv.height < w.innerHeight * 0.72;
  };

  // Re-asserted on every __rdgSync: the page may rewrite <meta viewport> or
  // drop our stylesheet during client-side navigation.
  const sync = () => {
    if (typing()) return;
    const parent = host();
    if (!parent) return;
    let meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      parent.appendChild(meta);
    }
    meta.setAttribute('content', [
      'width=device-width', 'initial-scale=1.0', 'minimum-scale=1.0',
      'maximum-scale=1.0', 'user-scalable=no', 'viewport-fit=contain',
    ].join(', '));
    sheet('rdg-shell-vars',
      `:root{${insetVars}}` +
      'html,body{overscroll-behavior:none!important;' +
      'overscroll-behavior-y:none!important;}');
  };

  sheet('rdg-shell-feel',
    '*{-webkit-tap-highlight-color:transparent!important;}' +
    `*${nativeOnly}{-webkit-touch-callout:none!important;}` +
    'input,textarea,select,[contenteditable="true"]' +
    '{font-size:max(16px,1em)!important;}');

  const block = (e) => e.preventDefault();
  for (const type of ['gesturestart', 'gesturechange', 'gestureend']) {
    document.addEventListener(type, block, {passive: false});
  }
  document.addEventListener('touchmove', (e) => {
    if (e.scale !== undefined && e.scale !== 1) e.preventDefault();
  }, {passive: false});

  let previousTap = 0;
  document.addEventListener('touchend', (e) => {
    const stamp = Date.now();
    if (stamp - previousTap <= 285) e.preventDefault();
    previousTap = stamp;
  }, {passive: false});

  const caretIntoView = () => {
    const node = document.activeElement;
    if (!node || !node.matches) return;
    if (!node.matches(`input, textarea, select, [contenteditable="true"]`)) {
      return;
    }
    node.scrollIntoView({behavior: 'auto', block: 'nearest'});
  };
  document.addEventListener('focusin', (e) => {
    const node = e.target;
    if (node && node.matches &&
        node.matches('input, textarea, select, [contenteditable="true"]')) {
      w.setTimeout(caretIntoView, 315);
    }
  }, true);

  // Client-side routing does not fire load events, so re-sync around it.
  const afterRoute = () => { w.setTimeout(sync, 165); w.setTimeout(sync, 745); };
  for (const name of ['pushState', 'replaceState']) {
    const original = history[name];
    history[name] = function(...args) {
      const result = original.apply(this, args);
      afterRoute();
      return result;
    };
  }
  w.addEventListener('popstate', afterRoute);

  w.__rdgSync = sync;
  sync();
  w.setInterval(sync, 2900);
})();
''';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _networkSubscription?.cancel();
    widget.pulse.onDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _controller),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
