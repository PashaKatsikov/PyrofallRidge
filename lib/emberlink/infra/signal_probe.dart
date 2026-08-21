import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity + reachability checks for the boot pipeline.
class SignalProbe {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Factual internet check: ignores the interface/gateway state reported by
  /// the OS and directly probes real reachability by resolving well-known
  /// hosts (never our own domain, so a VPN or a not-yet-propagated app domain
  /// cannot force a false "offline"). Both hosts are raced in parallel with a
  /// short timeout so a dead upstream resolves to "offline" almost instantly
  /// and the retry button can never hang.
  Future<bool> canReachNetwork() async {
    const hosts = <String>['apple.com', 'icloud.com'];
    const timeout = Duration(milliseconds: 1500);
    final probes = hosts.map((host) async {
      try {
        final records =
            await InternetAddress.lookup(host).timeout(timeout);
        return records.any((record) => record.rawAddress.isNotEmpty);
      } catch (_) {
        return false;
      }
    }).toList();

    // Resolve as soon as ANY host answers positively; otherwise wait for all
    // to fail/time out (bounded by [timeout]).
    final completer = Completer<bool>();
    var pending = probes.length;
    for (final probe in probes) {
      probe.then((reachable) {
        if (reachable) {
          if (!completer.isCompleted) completer.complete(true);
        } else {
          pending -= 1;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(false);
          }
        }
      });
    }
    return completer.future;
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
