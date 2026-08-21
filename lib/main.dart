import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'emberlink/config/ridge_relay_config.dart';
import 'emberlink/infra/drift_tracker.dart';
import 'emberlink/infra/ember_agent.dart';
import 'emberlink/infra/ember_vault.dart';
import 'emberlink/infra/pulse_relay.dart';
import 'emberlink/infra/relay_exchange.dart';
import 'emberlink/infra/signal_probe.dart';
import 'emberlink/relay_coordinator.dart';

/// Orientation is intentionally NOT locked here: the loading screen is
/// allowed to render in either portrait or landscape (it picks the matching
/// artwork). Portrait is enforced once gameplay actually starts, see
/// `LoadingScreen._finish()`.
///
/// The online (gray) services are assembled here and handed to the loading
/// screen, which runs the routing decision alongside its asset warm-up. The
/// whole online path stays inert until [RidgeRelayConfig.relayCredentialsReady]
/// is satisfied — until then this is the plain offline game.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final vault = EmberVault();
  final agent = EmberAgent();
  await Future.wait<void>(<Future<void>>[vault.initialize(), agent.prepare()]);

  var firebaseReady = false;
  if (RidgeRelayConfig.relayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
    } catch (_) {}
    if (firebaseReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (_) {
        // App Check must never block attribution / routing.
      }
    }
  }

  final probe = SignalProbe();
  final pulse = PulseRelay(vault, enabled: firebaseReady);
  final tracker = DriftTracker(agent);
  final coordinator = RelayCoordinator(
    vault: vault,
    probe: probe,
    tracker: tracker,
    exchange: RelayExchange(agent, vault),
    pulse: pulse,
    agent: agent,
    runtimeEnabled: RidgeRelayConfig.relayCredentialsReady,
  );

  runApp(PyrofallRidgeApp(coordinator: coordinator));
}
