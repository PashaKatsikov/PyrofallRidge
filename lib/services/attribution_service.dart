import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../core/attribution_config.dart';
import 'storage_service.dart';

/// How the current install was attributed by AppsFlyer.
enum InstallAttribution {
  /// Not known yet - the SDK's async conversion-data callback hasn't
  /// returned (or the app hasn't tried, e.g. missing credentials).
  unknown,

  /// The player found and downloaded the app directly (App Store search,
  /// browsing, a friend's recommendation, etc.) - no ad click involved.
  organic,

  /// The install followed a tracked ad click / OneLink.
  nonOrganic,
}

/// Wraps the AppsFlyer SDK for the one thing this game actually needs: is a
/// given install organic or the result of a paid campaign?
///
/// This is pure measurement, visible only in the AppsFlyer dashboard (and,
/// for our own curiosity, via [attribution]/[mediaSource] below) - nothing
/// in the app's UI, content or behavior ever branches on it.
class AttributionService extends ChangeNotifier {
  AttributionService._();
  static final AttributionService instance = AttributionService._();

  final StorageService _storage = StorageService();
  AppsflyerSdk? _sdk;
  bool _initialized = false;

  InstallAttribution _attribution = InstallAttribution.unknown;
  String? _mediaSource;
  String? _campaign;

  InstallAttribution get attribution => _attribution;

  /// Ad network / partner that drove a non-organic install (AppsFlyer's
  /// `media_source` field), or null for organic installs / before the
  /// callback has fired.
  String? get mediaSource => _mediaSource;
  String? get campaign => _campaign;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Show whatever we learned on the previous launch immediately; the SDK
    // callback below will refresh it once it fires again.
    final String? cachedStatus = await _storage.loadAttributionStatus();
    if (cachedStatus != null) {
      _attribution = _parseStatus(cachedStatus);
      _mediaSource = await _storage.loadAttributionMediaSource();
      notifyListeners();
    }

    if (!AttributionConfig.isConfigured) {
      _log('skipped: no AppsFlyer dev key configured yet');
      return;
    }

    try {
      await _requestTrackingIfNeeded();
      final AppsflyerSdk sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: AttributionConfig.devKey,
          appId: AttributionConfig.iosAppId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 4,
        ),
      );
      _sdk = sdk;
      sdk.onInstallConversionData(_onConversionData);
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: false,
        registerOnDeepLinkingCallback: false,
      );
    } catch (error) {
      _log('initialization failed: $error');
    }
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    final TrackingStatus status =
        await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    // Asking before the first frame settles gets silently ignored by iOS.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  void _onConversionData(dynamic raw) {
    try {
      final Map<String, dynamic> data = _flatten(raw);
      final String? status = data['af_status']?.toString();
      _log('conversion data received: af_status=$status keys=${data.keys}');
      if (status == null) return;

      _attribution = _parseStatus(status);
      _mediaSource =
          _attribution == InstallAttribution.nonOrganic
              ? data['media_source']?.toString()
              : null;
      _campaign =
          _attribution == InstallAttribution.nonOrganic
              ? data['campaign']?.toString()
              : null;
      notifyListeners();

      unawaited(_storage.saveAttributionStatus(status));
      unawaited(_storage.saveAttributionMediaSource(_mediaSource));
    } catch (error) {
      _log('conversion data parse error: $error');
    }
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final dynamic payload = map['payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : map;
  }

  InstallAttribution _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'organic':
        return InstallAttribution.organic;
      case 'non-organic':
        return InstallAttribution.nonOrganic;
      default:
        return InstallAttribution.unknown;
    }
  }

  Future<String?> appsFlyerId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  void _log(String message) {
    assert(() {
      debugPrint('[AttributionService] $message');
      return true;
    }());
  }
}
