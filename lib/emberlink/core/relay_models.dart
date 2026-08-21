/// Persisted routing decision for a returning launch.
enum RelayRoute {
  native,
  portal,
  undecided;

  String get storageValue => switch (this) {
    RelayRoute.native => 'native',
    RelayRoute.portal => 'portal',
    RelayRoute.undecided => 'undecided',
  };

  static RelayRoute parse(String? value) => switch (value) {
    'portal' || 'web' => RelayRoute.portal,
    'native' || 'game' => RelayRoute.native,
    _ => RelayRoute.undecided,
  };
}

/// Parsed config-endpoint response.
class RelayReply {
  const RelayReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory RelayReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return RelayReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory RelayReply.rejected(String reason) =>
      RelayReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

/// Where the boot pipeline decided to send the user.
sealed class RelayStop {
  const RelayStop();
}

/// White part (the game).
final class HomeStop extends RelayStop {
  const HomeStop();
}

/// Online WebView.
final class PortalStop extends RelayStop {
  const PortalStop(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

/// No-internet screen.
final class OfflineStop extends RelayStop {
  const OfflineStop({required this.returnToHome});

  final bool returnToHome;
}
