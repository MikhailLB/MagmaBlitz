import 'cipher.dart';

// ============================================================
// AppsFlyer / Firebase obfuscated identifiers
// ============================================================
// All values here are XOR-encoded byte payloads.  Edit the
// plaintexts in tool/encode_keys.dart and re-run it; never paste
// raw strings here.
//
// Until the operations team hands over real AppsFlyer + Firebase
// credentials, these arrays decode to the `TODO_*` placeholders.
// `unveilAppsFlyerKey()` returns an empty string when the prefix
// is still a placeholder, which keeps the SDK init from blowing
// up with malformed parameters.
// ============================================================

// "QWAjL24vW2RjWN4TdxonmT"
const _kAppsFlyerKey = <int>[
  0x70, 0x11, 0x46, 0x5e, 0x11, 0xe0, 0x97, 0xd6, 0x0e, 0x2c, 0xad, 0xa6,
  0x42, 0x64, 0x2f, 0xec, 0x45, 0x3e, 0x68, 0x5a, 0x30, 0x86,
];

// "543917289312"
const _kFirebaseProject = <int>[
  0x14, 0x72, 0x34, 0x0d, 0x6c, 0xe5, 0x91, 0x98, 0x60, 0x2d, 0xce, 0xfe,
];

// "https://gcdsdk.appsflyer.com"
const _kGcdHost = <int>[
  0x49, 0x32, 0x73, 0x44, 0x2e, 0xe8, 0x8c, 0x8f, 0x3e, 0x7d, 0x9b, 0xbf,
  0x71, 0x41, 0x35, 0xd9, 0x51, 0x36, 0x74, 0x52, 0x31, 0xab, 0xc6, 0xd2,
  0x77, 0x7d, 0x90, 0xa1,
];

// "/install_data/v4.0/"
const _kGcdPath = <int>[
  0x0e, 0x2f, 0x69, 0x47, 0x29, 0xb3, 0xcf, 0xcc, 0x06, 0x7a, 0x9e, 0xb8,
  0x74, 0x05, 0x6d, 0x8c, 0x0f, 0x76, 0x28,
];

String unveilAppsFlyerKey() => unveil(_kAppsFlyerKey);

String unveilFirebaseProject() => unveil(_kFirebaseProject);

/// Builds the GCD (Get-Conversion-Data) endpoint URL used as a
/// fallback when AppsFlyer reports false-organic on first install.
String buildGcdEndpoint({
  required String appId,
  required String deviceId,
}) {
  final host = unveil(_kGcdHost);
  if (host.isEmpty || appId.isEmpty || deviceId.isEmpty) return '';
  final base = host + unveil(_kGcdPath) + appId;
  return '$base?device_id=$deviceId';
}
