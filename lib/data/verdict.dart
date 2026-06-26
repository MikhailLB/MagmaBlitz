// ============================================================
// Verdict — typed wrapper around the JSON returned by the
// `/config.php` endpoint.  Three meaningful shapes:
//
//   • {ok:true,  url:"https://...", expires:1234567890}  → show WebView
//   • {ok:false, message:"organic"}                     → show game
//   • Verdict.failure(reason)                           → I/O error
// ============================================================

class Verdict {
  final bool open;
  final String? landingUrl;
  final String? reason;
  final int? expiresAt;

  const Verdict._({
    required this.open,
    this.landingUrl,
    this.reason,
    this.expiresAt,
  });

  factory Verdict.fromJson(Map<String, dynamic> json) {
    return Verdict._(
      open: json['ok'] as bool? ?? false,
      landingUrl: json['url'] as String?,
      reason: json['message'] as String?,
      expiresAt: json['expires'] as int?,
    );
  }

  factory Verdict.failure(String why) =>
      Verdict._(open: false, reason: why);

  bool get hasUrl => open && (landingUrl?.isNotEmpty ?? false);
}
