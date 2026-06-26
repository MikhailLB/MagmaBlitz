import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// ============================================================
// NetSensor — connectivity gatekeeper
// ============================================================
// Two responsibilities:
//
//   1) Decide whether the device has a REAL internet path.
//      We intentionally avoid DNS lookups as the probe: Android
//      caches DNS responses, so `InternetAddress.lookup` can
//      return a cached IP even when there is no actual upstream
//      (captive portal, WiFi with no route, etc.).
//
//      Instead we open a TCP socket to a well-known IP address
//      (bypassing DNS cache entirely).  A successful three-way
//      handshake proves a routable path exists.
//
//   2) Expose the raw connectivity stream so screens that
//      already render content (PortalStage) can debounce
//      `[none]` bursts and avoid flashing the offline screen
//      whenever the VPN hand-shake takes 400 ms.
// ============================================================

class NetSensor {
  static const _liveInterfaces = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  // Well-known IPs — no DNS involved, so the OS cannot return a
  // stale cache entry.  We race both probes; first success wins.
  static const _probeTargets = <(String, int)>[
    ('1.1.1.1', 443),   // Cloudflare
    ('8.8.8.8', 53),    // Google DNS
  ];

  static const _probeCap = Duration(seconds: 5);

  final Connectivity _engine = Connectivity();

  Future<bool> reachable() async {
    final interfaces = await _engine.checkConnectivity();
    if (!interfaces.any(_liveInterfaces.contains)) return false;
    return _tcpProbe();
  }

  // Race TCP-connect attempts to known IPs in parallel.
  // A successful handshake proves real connectivity.
  Future<bool> _tcpProbe() async {
    try {
      return await Future.any(
        _probeTargets.map((t) => _connectOnce(t.$1, t.$2)),
      ).timeout(_probeCap, onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _connectOnce(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 4),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get changes =>
      _engine.onConnectivityChanged;
}
