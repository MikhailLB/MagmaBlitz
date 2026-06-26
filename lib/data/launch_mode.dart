// ============================================================
// LaunchMode — persisted "which experience does this install
// belong to" enum.  Three states (intentionally not boolean):
//
//   • fresh : first launch / verdict has never been resolved.
//   • web   : install was routed to the WebView shell.  Returning
//             launches re-check the verdict but never fall back to
//             the game once the backend has classified them.
//   • play  : install was routed to the native game.  Returning
//             launches go straight to the game — no network at all.
// ============================================================

enum LaunchMode {
  fresh,
  web,
  play;

  static LaunchMode parse(String? raw) {
    switch (raw) {
      case 'web':
        return LaunchMode.web;
      case 'play':
        return LaunchMode.play;
      default:
        return LaunchMode.fresh;
    }
  }

  String get token {
    switch (this) {
      case LaunchMode.web:
        return 'web';
      case LaunchMode.play:
        return 'play';
      case LaunchMode.fresh:
        return 'fresh';
    }
  }
}
