import 'dart:typed_data';

// ============================================================
// Magma Blitz cipher — XOR string deobfuscator
// ============================================================
// All sensitive strings (config endpoint, AppsFlyer dev key,
// Firebase project number, browser UA fragments) live in the
// binary as encoded byte arrays instead of literals.
//
// The 16-byte XOR key is derived from `_seedBytes` via a tiny
// LCG.  This seed is project-unique — DO NOT copy it across
// other titles in the slate, otherwise two binaries would share
// identical encoded payloads.
//
// To regenerate the byte arrays after editing the seed run:
//
//     dart run tool/encode_keys.dart
//
// (use the Dart tool — PowerShell-based encoders overflow at
// 32 bits on Windows and produce broken HTTP headers.)
// ============================================================

const _seedBytes = <int>[
  // ASCII: "blz_fyr8" — chosen per Magma Blitz slate identifier.
  0x62, 0x6C, 0x7A, 0x5F, 0x66, 0x79, 0x72, 0x38,
];

Uint8List _buildKey() {
  if (_seedBytes.isEmpty) return Uint8List(16);
  var seed = 0;
  for (final byte in _seedBytes) {
    seed = (seed * 31 + byte) & 0xFFFFFFFF;
  }
  final key = Uint8List(16);
  var state = seed;
  for (var i = 0; i < key.length; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    key[i] = state & 0xFF;
  }
  return key;
}

final Uint8List _xorKey = _buildKey();

/// Decodes an XOR-obfuscated byte payload into a plain UTF-8 string.
String unveil(List<int> payload) {
  if (payload.isEmpty) return '';
  final out = Uint8List(payload.length);
  for (var i = 0; i < payload.length; i++) {
    out[i] = payload[i] ^ _xorKey[i % _xorKey.length];
  }
  return String.fromCharCodes(out);
}
