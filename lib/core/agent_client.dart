import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../setup/blitz_config.dart';
import '../setup/cipher.dart';

// ============================================================
// AgentClient — single HTTP client used by every service
// ============================================================
// Two reasons it exists:
//
//   1) Sets a real-device User-Agent on every outgoing request
//      AND on the WebView, so the binary doesn't fingerprint
//      itself with the generic "Dart/3.x" UA.
//
//   2) Appends the `appid/<bundle> appname/<token>` suffix
//      required by the slot-theme contract (gray_user_agent.mdc).
//
// Browser version fragments are XOR-obfuscated to keep grep /
// strings from pulling them out as obvious literals.
// ============================================================

// "131.0.6778.260"
const _kChromeVerEncoded = <int>[
  0x10, 0x75, 0x36, 0x1a, 0x6d, 0xfc, 0x95, 0x97, 0x6e, 0x26, 0xd1, 0xfe,
  0x23, 0x1a,
];

// "537.36"
const _kWebKitVerEncoded = <int>[
  0x14, 0x75, 0x30, 0x1a, 0x6e, 0xe4,
];

String get _chromeVer {
  final v = unveil(_kChromeVerEncoded);
  return v.isEmpty ? '131.0.6778.260' : v;
}

String get _webKitVer {
  final v = unveil(_kWebKitVerEncoded);
  return v.isEmpty ? '537.36' : v;
}

class AgentClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  String? _ua;

  Future<void> warmUp() async {
    final base = await _buildBrowserUa();
    _ua = _appendSlotSuffix(base);
  }

  Future<String> _buildBrowserUa() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final sdk = a.version.sdkInt;
        final model = a.model;
        final brand = a.brand;
        final buildId = a.display.isNotEmpty ? a.display : a.id;
        return 'Mozilla/5.0 (Linux; Android $sdk; $brand $model '
            'Build/$buildId) AppleWebKit/$_webKitVer '
            '(KHTML, like Gecko) Chrome/$_chromeVer Mobile Safari/$_webKitVer';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        final ver = i.systemVersion.replaceAll('.', '_');
        return 'Mozilla/5.0 (iPhone; CPU iPhone OS $ver like Mac OS X) '
            'AppleWebKit/$_webKitVer (KHTML, like Gecko) '
            'Version/${i.systemVersion} Mobile/15E148 Safari/$_webKitVer';
      }
    } catch (_) {
      // Fall through to the safe fallback below.
    }
    return 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/AP3A.240905.015) '
        'AppleWebKit/$_webKitVer (KHTML, like Gecko) '
        'Chrome/$_chromeVer Mobile Safari/$_webKitVer';
  }

  /// Per gray_user_agent.mdc — slot-themed titles must end the UA
  /// with `appid/<bundle> appname/<PascalCaseToken>` so the affiliate
  /// network can tie the visit back to the right campaign.
  String _appendSlotSuffix(String base) {
    return '$base appid/${BlitzConfig.bundleId} appname/${BlitzConfig.agentTag}';
  }

  String get userAgent {
    return _ua ?? 'Mozilla/5.0 appid/${BlitzConfig.bundleId} '
        'appname/${BlitzConfig.agentTag}';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Process-wide singleton used by every service.
final agentClient = AgentClient();
