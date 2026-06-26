// ============================================================
// Magma Blitz — secret string encoder
// ============================================================
// Run from project root:
//   dart run tool/encode_keys.dart
//
// The script derives the same 16-byte key as lib/setup/cipher.dart
// (LCG initialised by `_seedBytes`) and XOR-encodes each plaintext
// into a byte array suitable for embedding in:
//   - lib/setup/api_secrets.dart   (config endpoint URL)
//   - lib/setup/attribution_secrets.dart
//   - lib/core/agent_client.dart   (browser version fragments)
// ============================================================

import 'dart:typed_data';

// MUST be identical to `_seedBytes` in lib/setup/cipher.dart.
const _seedBytes = <int>[
  0x62, 0x6C, 0x7A, 0x5F, 0x66, 0x79, 0x72, 0x38, // "blz_fyr8"
];

Uint8List _deriveKey() {
  if (_seedBytes.isEmpty) return Uint8List(16);
  var seed = 0;
  for (final b in _seedBytes) {
    seed = (seed * 31 + b) & 0xFFFFFFFF;
  }
  final key = Uint8List(16);
  var v = seed;
  for (var i = 0; i < key.length; i++) {
    v = (v * 1103515245 + 12345) & 0x7FFFFFFF;
    key[i] = v & 0xFF;
  }
  return key;
}

final _key = _deriveKey();

List<int> _encode(String s) {
  final raw = s.codeUnits;
  final out = List<int>.filled(raw.length, 0);
  for (var i = 0; i < raw.length; i++) {
    out[i] = raw[i] ^ _key[i % _key.length];
  }
  return out;
}

String _formatArr(List<int> bytes) {
  final buf = StringBuffer('const v = <int>[\n  ');
  for (var i = 0; i < bytes.length; i++) {
    buf.write('0x${bytes[i].toRadixString(16).padLeft(2, '0')},');
    if ((i + 1) % 12 == 0) {
      buf.write('\n  ');
    } else {
      buf.write(' ');
    }
  }
  buf.write('\n];');
  return buf.toString();
}

void _dump(String label, String plain) {
  print('// $label  ->  $plain');
  print(_formatArr(_encode(plain)));
  print('');
}

void main() {
  // Sanity round-trip — the decoded value must match the source string.
  String _decode(List<int> data) {
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ _key[i % _key.length];
    }
    return String.fromCharCodes(out);
  }

  final tests = <String, String>{
    'CONFIG_HOST': 'https://magmablitz.com',
    'CONFIG_PATH': '/config.php',
    'GCD_HOST':    'https://gcdsdk.appsflyer.com',
    'GCD_PATH':    '/install_data/v4.0/',
    'CHROME_VER':  '131.0.6778.260',
    'WEBKIT_VER':  '537.36',
    'APPSFLYER_KEY': 'QWAjL24vW2RjWN4TdxonmT',
    'FB_PROJECT':    '543917289312',
  };

  print('// ===========================================================');
  print('// Magma Blitz encoded constants (cipher seed: "blz_fyr8")');
  print('// ===========================================================');
  print('');

  for (final entry in tests.entries) {
    final enc = _encode(entry.value);
    final dec = _decode(enc);
    if (dec != entry.value) {
      throw StateError('Round-trip failure for ${entry.key}');
    }
    _dump(entry.key, entry.value);
  }
}
