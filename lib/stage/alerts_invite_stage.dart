import 'package:flutter/material.dart';

import '../core/alerts_relay.dart';
import '../core/net_sensor.dart';
import '../core/vault.dart';
import '../setup/blitz_config.dart';
import '../theme.dart';
import 'portal_stage.dart' deferred as portal;

// ============================================================
// AlertsInviteStage — pre-WebView "enable notifications" promo
// ============================================================
// Triggered by `Vault.shouldShowAlertsScreen()`.  Background is
// the magma artwork at full bleed; controls are pinned to the
// bottom edge with a clear vertical hierarchy:
//
//   ┌────────────────────────┐
//   │     ACCEPT (button)    │
//   │           ‖            │
//   │       Skip (link)      │
//   └────────────────────────┘
//
// Button design deliberately uses a flat obsidian slab with an
// inner ember rim — different from the rounded gold pill used
// in sibling apps so the binaries don't share matching widgets.
// ============================================================

class AlertsInviteStage extends StatefulWidget {
  final Vault vault;
  final AlertsRelay relay;
  final NetSensor netSensor;
  final String landingUrl;

  const AlertsInviteStage({
    super.key,
    required this.vault,
    required this.relay,
    required this.netSensor,
    required this.landingUrl,
  });

  @override
  State<AlertsInviteStage> createState() => _AlertsInviteStageState();
}

class _AlertsInviteStageState extends State<AlertsInviteStage> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted = await widget.relay.requestPermission();
      if (!granted) {
        final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
            BlitzConfig.alertsSkipCooldownSeconds;
        await widget.vault.writeAlertsCooldown(until);
      }
    } finally {
      if (mounted) await _enterPortal();
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        BlitzConfig.alertsSkipCooldownSeconds;
    await widget.vault.writeAlertsCooldown(until);
    if (mounted) await _enterPortal();
  }

  Future<void> _enterPortal() async {
    await portal.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => portal.PortalStage(
          openingUrl: widget.landingUrl,
          vault: widget.vault,
          relay: widget.relay,
          netSensor: widget.netSensor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MagmaColors.deepRock,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final landscape = orientation == Orientation.landscape;
          final asset = landscape
              ? 'assets/Horizontal_Notifications_Screen.webp'
              : 'assets/Vertical_Notifications_Screen.webp';
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: landscape ? 0.18 : 0.32),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: landscape
                      // Landscape: fixed-width column centred horizontally,
                      // pulled close to the bottom edge.
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.36,
                            child: _buildControls(true),
                          ),
                        )
                      // Portrait: full-width column with side margins.
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 38),
                          child: _buildControls(false),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls(bool landscape) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FlameSlab(
          label: 'ACCEPT',
          icon: Icons.local_fire_department_rounded,
          compact: landscape,
          onTap: _accept,
        ),
        SizedBox(height: landscape ? 8 : 14),
        _SkipFlare(label: 'Skip', compact: landscape, onTap: _skip),
      ],
    );
  }
}

/// ACCEPT button: angular slab with a left-edge ember sliver and
/// a small flame icon.  Visually distinct from any rounded pill
/// the sibling slate uses for the same purpose.
class _FlameSlab extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool compact;
  final VoidCallback onTap;

  const _FlameSlab({
    required this.label,
    required this.icon,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_FlameSlab> createState() => _FlameSlabState();
}

class _FlameSlabState extends State<_FlameSlab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _emberCtrl;
  late final Animation<double> _emberAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _emberCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _emberAnim = CurvedAnimation(
      parent: _emberCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _emberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.compact ? 54.0 : 64.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _emberAnim,
        builder: (_, _) {
          final ember = 0.35 + (_emberAnim.value * 0.55);
          return AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 90),
            child: Container(
              height: h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _pressed
                      ? [
                          const Color(0xFFCB4A14),
                          const Color(0xFF6E1F08),
                        ]
                      : [
                          MagmaColors.lavaBright,
                          MagmaColors.lava,
                        ],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: MagmaColors.ember.withValues(alpha: 0.9),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: MagmaColors.lava.withValues(alpha: ember),
                    blurRadius: 18 + (_emberAnim.value * 8),
                    spreadRadius: 1.2,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Left edge ember sliver — pulses with the controller.
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 4,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: MagmaColors.ember.withValues(alpha: ember),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon,
                          color: Colors.white,
                          size: widget.compact ? 22 : 26),
                      const SizedBox(width: 12),
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.compact ? 18 : 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// SKIP link — text styled as a sub-action with an ember
/// underline that fades on press.
class _SkipFlare extends StatefulWidget {
  final String label;
  final bool compact;
  final VoidCallback onTap;

  const _SkipFlare({
    required this.label,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_SkipFlare> createState() => _SkipFlareState();
}

class _SkipFlareState extends State<_SkipFlare> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedOpacity(
        opacity: _pressed ? 0.4 : 0.85,
        duration: const Duration(milliseconds: 90),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: widget.compact ? 6 : 10,
            horizontal: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 15 : 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: widget.compact ? 28 : 36,
                height: 1.5,
                color: MagmaColors.ember.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
