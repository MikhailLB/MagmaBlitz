import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/verdict.dart';
import '../setup/blitz_config.dart';
import 'agent_client.dart';
import 'vault.dart';

// ============================================================
// VerdictGateway — talks to the config endpoint
// ============================================================
// Single POST per launch.  When the endpoint replies with
// `{ok:true, url, expires}` we persist both values in the
// vault; on returning launches we ALWAYS hit the endpoint
// again (per gray_resume_recheck.mdc) so partner URL rotations
// land in the WebView immediately instead of being shadowed by
// the stale cache.
//
// If the request fails (network error or non-200) and a
// previously cached URL exists, the caller falls back to it —
// an expired offer is still better than a blank screen.
// ============================================================

class VerdictGateway {
  final Vault _vault;

  VerdictGateway(this._vault);

  Future<Verdict> queryFresh(Map<String, dynamic> payload) async {
    final endpoint = BlitzConfig.verdictEndpoint;
    if (endpoint.isEmpty) {
      return Verdict.failure('endpoint missing');
    }

    try {
      final uri = Uri.parse(endpoint);
      final response = await agentClient
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(BlitzConfig.verdictRequestTimeout);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[VerdictGateway] http ${response.statusCode} body=${response.body}');
        }
        return Verdict.failure('http ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final verdict = Verdict.fromJson(decoded);

      if (verdict.hasUrl) {
        await _vault.writeSavedUrl(verdict.landingUrl!);
        if (verdict.expiresAt != null) {
          await _vault.writeSavedUrlExpiry(verdict.expiresAt!);
        }
      }

      return verdict;
    } catch (e) {
      if (kDebugMode) debugPrint('[VerdictGateway] error: $e');
      return Verdict.failure(e.toString());
    }
  }

  Future<String?> cachedUrl() => _vault.readSavedUrl();
}
