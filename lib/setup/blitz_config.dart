import 'api_secrets.dart';
import 'attribution_secrets.dart';

// ============================================================
// Magma Blitz — central config facade
// ============================================================
// Everything app-level (bundle id, display name, retry windows,
// the user-agent suffix mandated for slot-theme titles) is
// resolved through this single class.  Call sites should never
// hard-code identifiers — pull them from here so renaming or
// rebuilding for a different storefront is a one-file edit.
// ============================================================

class BlitzConfig {
  BlitzConfig._();

  /// Android applicationId / iOS bundle identifier.
  static const String bundleId = 'com.furymagma.magmablitz';

  /// Google Play package name (== bundle on Android).
  static const String storeId = 'com.furymagma.magmablitz';

  /// Human-readable display label used in notifications & menus.
  static const String displayLabel = 'Magma Blitz';

  /// PascalCase, space-free token appended to the User-Agent for
  /// slot-themed titles (see gray_user_agent.mdc).
  static const String agentTag = 'MagmaBlitz';

  /// iOS App Store numeric id — Android builds leave this empty.
  static const String iosStoreId = '';

  /// Lazy accessors — secrets are decoded on demand.
  static String get verdictEndpoint => ignitionEndpoint();
  static String get appsFlyerDevKey => unveilAppsFlyerKey();
  static String get firebaseProjectNumber => unveilFirebaseProject();

  /// 3-day delay (per ТЗ) before re-prompting the user for push
  /// notifications after they tapped "Skip".
  static const int alertsSkipCooldownSeconds = 3 * 24 * 60 * 60;

  /// How long to wait before retrying via GCD when AppsFlyer
  /// reports `af_status: Organic` on first callback.
  static const int organicProbeDelaySeconds = 5;

  /// Soft attribution timeout for first install.
  static const Duration firstLaunchAttributionWindow = Duration(seconds: 30);

  /// Faster timeout on returning launches — the cached saved URL
  /// keeps us covered if attribution is slow.
  static const Duration warmAttributionWindow = Duration(seconds: 10);

  /// Deep-link callback wait window.
  static const Duration deepLinkWindow = Duration(seconds: 5);

  /// Hard ceiling for the verdict POST request.
  static const Duration verdictRequestTimeout = Duration(seconds: 15);
}
