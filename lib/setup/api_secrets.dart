import 'cipher.dart';

// ============================================================
// API secrets — config endpoint URL fragments
// ============================================================
// Splitting the URL into host + path makes it harder to pluck
// the full string out of the binary with `strings`.  Run
// `dart run tool/encode_keys.dart` to regenerate the arrays
// after touching either the seed or the URL itself.
// ============================================================

// "https://magmablitz.com"
const _kIgnitionHost = <int>[
  0x49, 0x32, 0x73, 0x44, 0x2e, 0xe8, 0x8c, 0x8f, 0x34, 0x7f, 0x98, 0xa1,
  0x74, 0x48, 0x77, 0xd1, 0x55, 0x3c, 0x29, 0x57, 0x32, 0xbf,
];

// "/config.php"
const _kIgnitionPath = <int>[
  0x0e, 0x25, 0x68, 0x5a, 0x3b, 0xbb, 0xc4, 0x8e, 0x29, 0x76, 0x8f,
];

/// Full `POST` endpoint that returns the install verdict
/// (`{ok, url, expires, message}`).
String ignitionEndpoint() {
  final host = unveil(_kIgnitionHost);
  if (host.isEmpty) return '';
  return host + unveil(_kIgnitionPath);
}
