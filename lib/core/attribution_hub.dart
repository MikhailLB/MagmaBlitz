import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../setup/attribution_secrets.dart';
import '../setup/blitz_config.dart';
import 'agent_client.dart';

// ============================================================
// AttributionHub — AppsFlyer wrapper
// ============================================================
// Responsibilities:
//
//   • Initialise the AppsFlyer SDK with both attribution and
//     OneLink callbacks.
//   • Cache the install-conversion payload, deep-link payload
//     and app-open payload separately so we can merge them in
//     the right priority order when the gateway needs a body.
//   • Handle the well-known "Organic on first callback" bug by
//     waiting 5 s and re-querying the GCD endpoint manually —
//     the second answer is the trustworthy one.
// ============================================================

class AttributionHub {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installPayload;
  Map<String, dynamic>? _deepLinkPayload;
  Map<String, dynamic>? _appOpenPayload;

  final Completer<Map<String, dynamic>> _installFuture = Completer();
  final Completer<void> _deepLinkFuture = Completer();

  bool _initialized = false;

  Future<void> ignite() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final options = AppsFlyerOptions(
        afDevKey: BlitzConfig.appsFlyerDevKey,
        appId: BlitzConfig.iosStoreId,
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: 10,
      );

      _sdk = AppsflyerSdk(options);

      _sdk!.onInstallConversionData((data) async {
        final raw = _pickPayload(data);

        // AppsFlyer can fire this callback multiple times.  Later calls
        // with {"status":"failure"} carry error info, not attribution —
        // ignore them entirely.  Also stop processing once the completer
        // is already resolved so we don't overwrite good data.
        final cbStatus = raw['status']?.toString();
        if (cbStatus == 'failure') return;
        if (_installFuture.isCompleted) return;

        final afStatus = raw['af_status']?.toString();
        if (afStatus == 'Organic') {
          await Future.delayed(
              Duration(seconds: BlitzConfig.organicProbeDelaySeconds));
          final retry = await _refreshViaGcd();
          _installPayload = retry ?? raw;
        } else {
          _installPayload = raw;
        }

        if (!_installFuture.isCompleted) {
          _installFuture.complete(_installPayload!);
        }
      });

      _sdk!.onAppOpenAttribution((data) {
        _appOpenPayload = _pickPayload(data);
      });

      _sdk!.onDeepLinking((result) {
        try {
          final dl = result.deepLink;
          if (dl != null) {
            _deepLinkPayload =
                Map<String, dynamic>.from(dl.clickEvent as Map);
          }
        } catch (_) {
          // Ignore — best-effort capture.
        }
        if (!_deepLinkFuture.isCompleted) _deepLinkFuture.complete();
      });

      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AttributionHub] init error: $e');
    }
  }

  Map<String, dynamic> _pickPayload(dynamic data) {
    // AppsFlyer SDK may pass Map<dynamic,dynamic> or Map<String,dynamic>.
    // Always convert to a typed map first so the key lookup works correctly.
    Map<String, dynamic> toStrMap(Map m) =>
        {for (final e in m.entries) e.key.toString(): e.value};

    final Map<String, dynamic> outer;
    if (data is Map<String, dynamic>) {
      outer = data;
    } else if (data is Map) {
      outer = toStrMap(data);
    } else {
      return <String, dynamic>{};
    }

    // Unwrap the {"status":"success","payload":{...}} envelope if present.
    final inner = outer['payload'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return toStrMap(inner);

    return outer;
  }

  Future<Map<String, dynamic>?> _refreshViaGcd() async {
    try {
      final uid = await currentUid();
      if (uid == null || uid.isEmpty) return null;
      final appId =
          Platform.isIOS ? BlitzConfig.iosStoreId : BlitzConfig.bundleId;
      final url = buildGcdEndpoint(appId: appId, deviceId: uid);
      if (url.isEmpty) return null;
      final response = await agentClient
          .get(Uri.parse(url), headers: {
            'authorization': 'Bearer ${BlitzConfig.appsFlyerDevKey}',
          })
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Swallow — we'll fall back to the original payload.
    }
    return null;
  }

  Future<Map<String, dynamic>> awaitInstall(
      {Duration? maxWait}) async {
    return _installFuture.future.timeout(
      maxWait ?? BlitzConfig.firstLaunchAttributionWindow,
      onTimeout: () => <String, dynamic>{},
    );
  }

  Future<void> awaitDeepLink() async {
    await _deepLinkFuture.future.timeout(
      BlitzConfig.deepLinkWindow,
      onTimeout: () {},
    );
  }

  Future<String?> currentUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Assembles the POST body for `verdict_gateway.dart`.
  ///
  /// Priority of writes (first wins for shared keys):
  ///   1. install attribution payload
  ///   2. deep-link payload     (putIfAbsent)
  ///   3. app-open payload      (putIfAbsent)
  ///   4. device-side overrides (always written)
  Future<Map<String, dynamic>> assembleBody({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};

    final install = _installPayload;
    if (install != null) body.addAll(install);

    _deepLinkPayload?.forEach((k, v) => body.putIfAbsent(k, () => v));
    _appOpenPayload?.forEach((k, v) => body.putIfAbsent(k, () => v));

    final uid = await currentUid();
    body['af_id'] = uid ?? '';
    body['bundle_id'] = BlitzConfig.bundleId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = BlitzConfig.storeId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final fbProject = BlitzConfig.firebaseProjectNumber;
    if (fbProject.isNotEmpty) {
      body['firebase_project_id'] = fbProject;
    }

    if (kDebugMode) {
      debugPrint('[AttributionHub] body=${jsonEncode(body)}');
    }
    return body;
  }
}
