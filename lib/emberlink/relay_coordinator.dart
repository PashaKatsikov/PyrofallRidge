import 'dart:async';
import 'dart:io';

import 'config/ridge_relay_config.dart';
import 'core/relay_models.dart';
import 'infra/cold_tap_reader.dart';
import 'infra/drift_tracker.dart';
import 'infra/ember_agent.dart';
import 'infra/ember_vault.dart';
import 'infra/pulse_relay.dart';
import 'infra/relay_exchange.dart';
import 'infra/signal_probe.dart';

/// The routing brain. `decide()` runs the attribution → config pipeline and
/// returns where the splash should send the user. It de-dupes only concurrent
/// startup calls and clears its cache on completion, so a Retry from the
/// offline screen re-runs the whole pipeline instead of replaying a stale
/// verdict.
class RelayCoordinator {
  RelayCoordinator({
    required this.vault,
    required this.probe,
    required this.tracker,
    required this.exchange,
    required this.pulse,
    required this.agent,
    required this.runtimeEnabled,
  });

  final EmberVault vault;
  final SignalProbe probe;
  final DriftTracker tracker;
  final RelayExchange exchange;
  final PulseRelay pulse;
  final EmberAgent agent;
  final bool runtimeEnabled;

  bool get enabled =>
      runtimeEnabled && RidgeRelayConfig.relayCredentialsReady;

  Future<RelayStop>? _decideFuture;

  Future<RelayStop> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??=
          _decide(onProgress: onProgress).whenComplete(() => _decideFuture = null);

  Future<RelayStop> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      onProgress(1);
      return const HomeStop();
    }

    pulse.onTokenChanged = _refreshForToken;
    final coldRoute = await ColdTapReader.consume();
    if (coldRoute != null) {
      await vault.saveRoute(RelayRoute.portal);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return PortalStop(coldRoute, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      RelayRoute.undecided => _firstDecision(onProgress),
      RelayRoute.portal => _returningPortal(onProgress),
      RelayRoute.native => _returningNative(onProgress),
    };
  }

  Future<RelayStop> _firstDecision(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineStop(returnToHome: false);
    }
    if (!await probe.canReachNetwork()) {
      return const OfflineStop(returnToHome: false);
    }
    progress(0.28);
    try {
      await pulse.boot();
    } catch (_) {}
    progress(0.48);
    await tracker.awaitSignals();
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) {
      await vault.saveRoute(RelayRoute.portal);
      return PortalStop(reply.url!);
    }
    await vault.saveRoute(RelayRoute.native);
    return const HomeStop();
  }

  Future<RelayStop> _returningPortal(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineStop(returnToHome: false);
    }
    if (!await probe.canReachNetwork()) {
      return const OfflineStop(returnToHome: false);
    }
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return PortalStop(pending);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return PortalStop(cached);
    }

    await Future.wait<void>(<Future<void>>[pulse.boot(), tracker.start()]);
    progress(0.62);
    await tracker.awaitSignals(
      installTimeout: const Duration(milliseconds: 6900),
    );
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return PortalStop(reply.url!);
    if (cached != null) return PortalStop(cached);
    return const OfflineStop(returnToHome: false);
  }

  Future<RelayStop> _returningNative(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      progress(1);
      return const HomeStop();
    }
    await Future.wait<void>(<Future<void>>[pulse.boot(), tracker.start()]);
    if (!await probe.canReachNetwork()) {
      progress(1);
      return const HomeStop();
    }
    progress(0.55);
    await tracker.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const HomeStop();
    await vault.saveRoute(RelayRoute.portal);
    return PortalStop(reply.url!);
  }

  Future<RelayReply> _requestConfig({String? token}) async {
    final body = await tracker.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? pulse.token,
    );
    return exchange.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        pulse.boot(),
        tracker.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
