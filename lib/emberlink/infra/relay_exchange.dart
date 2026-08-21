import 'dart:convert';

import '../config/ridge_relay_config.dart';
import '../core/relay_models.dart';
import 'drift_tracker.dart';
import 'ember_agent.dart';
import 'ember_vault.dart';

/// POSTs the attribution payload to the config endpoint and parses the reply.
class RelayExchange {
  RelayExchange(this._agent, this._vault);

  final EmberAgent _agent;
  final EmberVault _vault;

  Future<RelayReply> request(Map<String, dynamic> payload) async {
    if (!RidgeRelayConfig.relayCredentialsReady) {
      return RelayReply.rejected('credentials_unavailable');
    }
    try {
      ridgeTrace(() => '[RDG.EXCHANGE] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(RidgeRelayConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 17));
      ridgeTrace(
        () => '[RDG.EXCHANGE] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return RelayReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return RelayReply.rejected('invalid_response');
      final reply = RelayReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      ridgeTrace(() => '[RDG.EXCHANGE] failed: $error');
      return RelayReply.rejected('network_failure');
    }
  }
}
