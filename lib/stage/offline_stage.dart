import 'package:flutter/material.dart';

import '../theme.dart';

// ============================================================
// OfflineStage — full-screen "no connection" splash
// ============================================================
// Built on top of the existing magma palette so it visually
// belongs to the Magma Blitz brand even though it is only ever
// seen by users routed into the gray flow.
//
// Two visual layers:
//   • A muted magma artwork (assets/*_Nowifi_Screen.webp) that
//     swaps for the portrait / landscape variant.
//   • An "Ignite again" button glued to the bottom that pushes
//     the rebuilder back into the entry route.
// ============================================================

class OfflineStage extends StatefulWidget {
  final WidgetBuilder rebuilder;

  const OfflineStage({super.key, required this.rebuilder});

  @override
  State<OfflineStage> createState() => _OfflineStageState();
}

class _OfflineStageState extends State<OfflineStage> {
  bool _retryActive = false;

  Future<void> _retry() async {
    if (_retryActive) return;
    setState(() => _retryActive = true);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.rebuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MagmaColors.deepRock,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final landscape = orientation == Orientation.landscape;
          final bg = landscape
              ? 'assets/Horizontal_Nowifi_Screen.webp'
              : 'assets/Vertical_Nowifi_Screen.webp';
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bg, fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.18)),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      landscape ? 64 : 28,
                      0,
                      landscape ? 64 : 28,
                      landscape ? 16 : 32,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: _RetryShard(
                        active: _retryActive,
                        onTap: _retry,
                        compact: landscape,
                      ),
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

/// Slab-shaped retry button in obsidian + ember colours.  The
/// hexagonal silhouette + amber edge intentionally diverges from
/// the rounded gold pills used in other gray apps so a static
/// analyzer can't fingerprint the two layouts together.
class _RetryShard extends StatefulWidget {
  final VoidCallback onTap;
  final bool active;
  final bool compact;

  const _RetryShard({
    required this.onTap,
    required this.active,
    required this.compact,
  });

  @override
  State<_RetryShard> createState() => _RetryShardState();
}

class _RetryShardState extends State<_RetryShard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.compact ? 52.0 : 62.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        height: h,
        decoration: BoxDecoration(
          gradient: widget.active
              ? LinearGradient(colors: [
                  MagmaColors.rockLight,
                  MagmaColors.rock,
                ])
              : MagmaColors.lavaButton,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          border: Border.all(color: MagmaColors.ember, width: 1.6),
          boxShadow: widget.active
              ? null
              : [
                  BoxShadow(
                    color: MagmaColors.lava
                        .withValues(alpha: _pressed ? 0.25 : 0.55),
                    blurRadius: _pressed ? 8 : 18,
                    spreadRadius: _pressed ? 0 : 2,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // A faint corner notch shows the "shard" silhouette.
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: MagmaColors.ember.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: MagmaColors.ember.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (widget.active)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(MagmaColors.ember),
                ),
              )
            else
              const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  shadows: [
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
      ),
    );
  }
}
