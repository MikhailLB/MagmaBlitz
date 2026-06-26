import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/launch_mode.dart';

// ============================================================
// Vault — persistence facade
// ============================================================
// All install-wide state lives here.  We split the storage by
// sensitivity:
//
//   • SharedPreferences — non-sensitive flags (mode, timestamps).
//   • FlutterSecureStorage — URLs and one-shot push payloads.
//
// The "OS-denied" flag is critical: once Android's runtime push
// dialog returns DENIED, the OS will never show it again, so we
// must stop re-prompting even after the 3-day cool-down expires.
// ============================================================

class Vault {
  static const _kLaunchMode = 'mb_launch_mode';
  static const _kSavedUrl = 'mb_landing_url';
  static const _kExpiresAt = 'mb_landing_expires';
  static const _kAlertsCooldown = 'mb_alerts_cooldown_until';
  static const _kAlertsGranted = 'mb_alerts_granted';
  static const _kAlertsOsDenied = 'mb_alerts_os_denied';
  static const _kPushUrl = 'mb_push_landing';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _strongbox = const FlutterSecureStorage();

  Future<void> warmUp() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── launch mode ────────────────────────────────────────────

  LaunchMode get launchMode => LaunchMode.parse(_prefs.getString(_kLaunchMode));

  Future<void> writeLaunchMode(LaunchMode mode) =>
      _prefs.setString(_kLaunchMode, mode.token);

  // ── persisted landing URL (secure) ─────────────────────────

  Future<String?> readSavedUrl() => _strongbox.read(key: _kSavedUrl);

  Future<void> writeSavedUrl(String url) =>
      _strongbox.write(key: _kSavedUrl, value: url);

  int? get savedUrlExpiry => _prefs.getInt(_kExpiresAt);

  Future<void> writeSavedUrlExpiry(int unixSeconds) =>
      _prefs.setInt(_kExpiresAt, unixSeconds);

  bool get savedUrlExpired {
    final ts = savedUrlExpiry;
    if (ts == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= ts;
  }

  // ── push permission state ──────────────────────────────────

  bool get alertsGranted => _prefs.getBool(_kAlertsGranted) ?? false;

  Future<void> markAlertsGranted(bool granted) =>
      _prefs.setBool(_kAlertsGranted, granted);

  /// Set when the system dialog returned `denied` — never prompt again.
  bool get alertsOsDenied => _prefs.getBool(_kAlertsOsDenied) ?? false;

  Future<void> markAlertsOsDenied() =>
      _prefs.setBool(_kAlertsOsDenied, true);

  int? get alertsCooldownUntil => _prefs.getInt(_kAlertsCooldown);

  Future<void> writeAlertsCooldown(int unixSeconds) =>
      _prefs.setInt(_kAlertsCooldown, unixSeconds);

  /// Three-state check per ТЗ:
  ///  • Already granted → no.
  ///  • OS-level denied (system dialog dismissed) → no.
  ///  • First time or cool-down elapsed → yes.
  bool shouldShowAlertsScreen() {
    if (alertsGranted) return false;
    if (alertsOsDenied) return false;
    final until = alertsCooldownUntil;
    if (until == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= until;
  }

  // ── one-shot push URL (secure) ─────────────────────────────

  Future<String?> readPushUrl() => _strongbox.read(key: _kPushUrl);

  Future<void> stashPushUrl(String? url) async {
    if (url == null) {
      await _strongbox.delete(key: _kPushUrl);
    } else {
      await _strongbox.write(key: _kPushUrl, value: url);
    }
  }

  /// Pops the push URL if present — only ever consumed once.
  Future<String?> consumePushUrl() async {
    final url = await readPushUrl();
    if (url != null) {
      await _strongbox.delete(key: _kPushUrl);
    }
    return url;
  }
}
