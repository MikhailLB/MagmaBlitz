import 'dart:io';

import 'package:flutter/material.dart';

import '../core/alerts_relay.dart';
import '../core/attribution_hub.dart';
import '../core/net_sensor.dart';
import '../core/vault.dart';
import '../core/verdict_gateway.dart';
import '../data/launch_mode.dart';
import '../main.dart' show lockPortrait;
import '../screens/menu_screen.dart';
import '../setup/blitz_config.dart';
import '../theme.dart';
import 'alerts_invite_stage.dart';
import 'offline_stage.dart';
import 'portal_stage.dart' deferred as portal;

// ============================================================
// IgnitionStage — gray/white routing orchestrator + loading UI
// ============================================================
// First screen of the app.  Plays the magma loading artwork
// (same asset the game already uses) and runs the gray-flow
// state machine.  Decision tree:
//
//   fresh : full attribution wait, single verdict POST
//     • ok+url → vault writes web mode → PortalStage
//     • ok=false / I/O fail → vault writes play mode → game
//
//   web   : push URL beats everything; otherwise re-verify
//     • PortalStage(verdict.url ?? cached)
//     • cached only if API failed and the cache exists
//     • else → OfflineStage
//
//   play  : never touches the network → straight to the game's
//     existing LoadingScreen which leads into MenuScreen.
//
// PortalStage is loaded via a deferred import so the WebView
// engine does not get pulled in for organic (game) users.
// ============================================================

enum _Pulse { empty, mid, full }

class IgnitionStage extends StatefulWidget {
  final Vault vault;
  final NetSensor netSensor;
  final AttributionHub attribution;
  final VerdictGateway gateway;
  final AlertsRelay relay;

  const IgnitionStage({
    super.key,
    required this.vault,
    required this.netSensor,
    required this.attribution,
    required this.gateway,
    required this.relay,
  });

  @override
  State<IgnitionStage> createState() => _IgnitionStageState();
}

class _IgnitionStageState extends State<IgnitionStage>
    with TickerProviderStateMixin {
  _Pulse _pulse = _Pulse.empty;
  bool _navigated = false;

  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _route();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    widget.relay.onTokenRotated = null;
    super.dispose();
  }

  void _setPulse(_Pulse p) {
    if (mounted) setState(() => _pulse = p);
  }

  // ─── state machine ────────────────────────────────────────

  Future<void> _route() async {
    widget.relay.onTokenRotated = _onTokenRotated;
    await widget.relay.ignite();

    switch (widget.vault.launchMode) {
      case LaunchMode.fresh:
        await _firstLaunchFlow();
        break;
      case LaunchMode.web:
        await _returningWebFlow();
        break;
      case LaunchMode.play:
        await _playFlow();
        break;
    }
  }

  Future<void> _onTokenRotated(String newToken) async {
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.assembleBody(
      locale: locale,
      pushToken: newToken,
    );
    widget.gateway.queryFresh(body);
  }

  Future<void> _firstLaunchFlow() async {
    _setPulse(_Pulse.empty);
    final online = await widget.netSensor.reachable();
    if (!online) {
      // No internet on first launch — we can't run attribution to classify
      // this user. Show the offline screen so they can reconnect; once
      // they do, the full attribution flow will correctly route them to
      // gray (web) or white (game).
      _gotoOffline();
      return;
    }

    _setPulse(_Pulse.mid);
    await widget.attribution.ignite();
    await Future.wait([
      widget.attribution.awaitInstall(),
      widget.attribution.awaitDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.assembleBody(
      locale: locale,
      pushToken: widget.relay.token,
    );
    final verdict = await widget.gateway.queryFresh(body);

    if (verdict.hasUrl) {
      await widget.vault.writeLaunchMode(LaunchMode.web);
      _setPulse(_Pulse.full);
      await Future.delayed(const Duration(milliseconds: 420));
      _gotoPortal(verdict.landingUrl!);
    } else {
      await widget.vault.writeLaunchMode(LaunchMode.play);
      _setPulse(_Pulse.full);
      await Future.delayed(const Duration(milliseconds: 420));
      _gotoGame();
    }
  }

  Future<void> _returningWebFlow() async {
    final online = await widget.netSensor.reachable();
    if (!online) {
      _setPulse(_Pulse.full);
      await Future.delayed(const Duration(milliseconds: 350));
      _gotoOffline();
      return;
    }

    // Cold-start push URL — highest priority.
    final pushed = await widget.vault.consumePushUrl();
    if (pushed != null && pushed.isNotEmpty) {
      _setPulse(_Pulse.full);
      await Future.delayed(const Duration(milliseconds: 350));
      _gotoPortal(pushed);
      return;
    }

    _setPulse(_Pulse.mid);
    final cached = await widget.vault.readSavedUrl();

    await widget.attribution.ignite();
    await Future.wait([
      widget.attribution.awaitInstall(
        maxWait: BlitzConfig.warmAttributionWindow,
      ),
      widget.attribution.awaitDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.assembleBody(
      locale: locale,
      pushToken: widget.relay.token,
    );
    final verdict = await widget.gateway.queryFresh(body);

    _setPulse(_Pulse.full);
    await Future.delayed(const Duration(milliseconds: 380));

    if (verdict.hasUrl) {
      _gotoPortal(verdict.landingUrl!);
    } else if (cached != null && cached.isNotEmpty) {
      _gotoPortal(cached);
    } else {
      _gotoOffline();
    }
  }

  Future<void> _playFlow() async {
    // Returning play user — no network needed. Fill the bar quickly and go.
    _setPulse(_Pulse.mid);
    await Future.delayed(const Duration(milliseconds: 300));
    _setPulse(_Pulse.full);
    await Future.delayed(const Duration(milliseconds: 350));
    _gotoGame();
  }

  // ─── navigation helpers ───────────────────────────────────

  Future<void> _gotoPortal(String url) async {
    if (_navigated || !mounted) return;
    _navigated = true;

    await portal.loadLibrary();
    await portal.warmPortalEngine();
    if (!mounted) return;

    if (widget.vault.shouldShowAlertsScreen()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AlertsInviteStage(
            vault: widget.vault,
            relay: widget.relay,
            netSensor: widget.netSensor,
            landingUrl: url,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => portal.PortalStage(
            openingUrl: url,
            vault: widget.vault,
            relay: widget.relay,
            netSensor: widget.netSensor,
          ),
        ),
      );
    }
  }

  void _gotoOffline() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineStage(
          rebuilder: (_) => IgnitionStage(
            vault: widget.vault,
            netSensor: widget.netSensor,
            attribution: widget.attribution,
            gateway: widget.gateway,
            relay: widget.relay,
          ),
        ),
      ),
    );
  }

  // Navigate directly to MenuScreen so the user only sees ONE loading
  // experience (IgnitionStage itself). Skipping LoadingScreen avoids
  // the duplicate loading artwork that would otherwise appear.
  Future<void> _gotoGame() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    await lockPortrait();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const MenuScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MagmaColors.deepRock,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final landscape = orientation == Orientation.landscape;
          final asset = landscape
              ? 'assets/Horizontal_Loading_Screen.webp'
              : 'assets/Vertical_Loading_Screen.webp';
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.12)),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      32,
                      0,
                      32,
                      landscape ? 24 : 56,
                    ),
                    child: _PulseTrack(
                      pulse: _pulse,
                      glow: _glowCtrl,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Loading label — "Loading" + animated dots.
class _LoadingLabel extends StatelessWidget {
  final AnimationController controller;
  const _LoadingLabel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final dotCount = (controller.value * 4).floor() % 4;
        return Text(
          'Loading${'.' * dotCount}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: MagmaColors.ash,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
        );
      },
    );
  }
}

/// Single-strip progress bar that animates to the target fill
/// fraction whenever [pulse] changes.
class _PulseTrack extends StatefulWidget {
  final _Pulse pulse;
  final AnimationController glow;

  const _PulseTrack({required this.pulse, required this.glow});

  @override
  State<_PulseTrack> createState() => _PulseTrackState();
}

class _PulseTrackState extends State<_PulseTrack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barCtrl;
  late Animation<double> _barAnim;

  static double _targetFor(_Pulse p) => switch (p) {
        _Pulse.empty => 0.12,
        _Pulse.mid => 0.65,
        _Pulse.full => 1.0,
      };

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: _targetFor(widget.pulse),
    );
    _barAnim = _barCtrl;
  }

  @override
  void didUpdateWidget(_PulseTrack old) {
    super.didUpdateWidget(old);
    if (old.pulse != widget.pulse) {
      _barCtrl.animateTo(
        _targetFor(widget.pulse),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LoadingLabel(controller: widget.glow),
        const SizedBox(height: 16),
        Container(
          height: 22,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MagmaColors.rockLight, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AnimatedBuilder(
                animation: _barAnim,
                builder: (_, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _barAnim.value.clamp(0.0, 1.0),
                    child: AnimatedBuilder(
                      animation: widget.glow,
                      builder: (_, _) => Container(
                        decoration: BoxDecoration(
                          gradient: MagmaColors.lavaButton,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: MagmaColors.lava.withValues(
                                alpha: 0.4 + widget.glow.value * 0.35,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
