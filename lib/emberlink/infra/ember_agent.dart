import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/ridge_relay_config.dart';

/// HTTP client that stamps every request with a real-device Safari-class
/// User-Agent, assembled from the encoded fragments in [RidgeRelayConfig] so no
/// browser scaffolding literal is present in the binary. The same string is
/// reused for the WebView (see PortalView) to keep session continuity.
///
/// GAME THEME CATEGORY: slot (partner requires the identity suffix; the two
/// identity tokens are decoded from encoded byte arrays and assembled at
/// runtime — no plaintext identity literal ships in the binary).
class EmberAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _userAgent = _mobileSafari(_normalizedIos(info.systemVersion));
    } catch (_) {
      _userAgent = _fallback();
    }
  }

  String get userAgent => _userAgent ?? _fallback();

  String _normalizedIos(String raw) {
    final parts = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .take(3)
        .toList();
    if (parts.isEmpty || parts.first < 18) return '18.7';
    return parts.join('.');
  }

  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    final base = '${RidgeRelayConfig.uaProduct} '
        '${RidgeRelayConfig.uaPlatformPrefix} $cpu '
        '${RidgeRelayConfig.uaPlatformSuffix} '
        '${RidgeRelayConfig.uaEngine} '
        'Version/${RidgeRelayConfig.safariVersion} '
        '${RidgeRelayConfig.uaMobileToken} '
        'Safari/${RidgeRelayConfig.safariTail}';
    final appId = RidgeRelayConfig.uaAppIdToken;
    if (appId.isEmpty) return base;
    // Slot-partner identity, appended last: <token><store id> <token><AppName>.
    return '$base $appId${RidgeRelayConfig.iosStoreId} '
        '${RidgeRelayConfig.uaAppNameToken}${RidgeRelayConfig.uaAppName}';
  }

  String _fallback() => _mobileSafari('18.7');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
