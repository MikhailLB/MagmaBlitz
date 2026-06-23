import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A single code-drawn magma burst that plays once and removes itself.
class ExplosionFx extends StatefulWidget {
  final double size;
  final VoidCallback? onDone;
  final int seed;

  const ExplosionFx({
    super.key,
    required this.size,
    this.onDone,
    this.seed = 0,
  });

  @override
  State<ExplosionFx> createState() => _ExplosionFxState();
}

class _ExplosionFxState extends State<ExplosionFx>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    final rng = Random(widget.seed);
    _sparks = List.generate(10, (i) {
      final angle = (i / 10) * 2 * pi + rng.nextDouble();
      return _Spark(
        angle: angle,
        distance: 0.55 + rng.nextDouble() * 0.5,
        radius: 1.5 + rng.nextDouble() * 2.5,
      );
    });
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return CustomPaint(
              painter: _ExplosionPainter(_c.value, _sparks),
            );
          },
        ),
      ),
    );
  }
}

class _Spark {
  final double angle;
  final double distance;
  final double radius;
  _Spark({required this.angle, required this.distance, required this.radius});
}

class _ExplosionPainter extends CustomPainter {
  final double t; // 0..1
  final List<_Spark> sparks;
  _ExplosionPainter(this.t, this.sparks);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Core flash: bright, fades quickly.
    final coreOpacity = (1.0 - t * 1.6).clamp(0.0, 1.0);
    if (coreOpacity > 0) {
      final coreR = maxR * (0.25 + t * 0.55);
      final corePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: coreOpacity),
            MagmaColors.ember.withValues(alpha: coreOpacity * 0.9),
            MagmaColors.lava.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: coreR));
      canvas.drawCircle(center, coreR, corePaint);
    }

    // Expanding shockwave ring.
    final ringR = maxR * (0.2 + t * 0.85);
    final ringOpacity = (1.0 - t).clamp(0.0, 1.0);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = maxR * 0.12 * (1.0 - t)
      ..color = MagmaColors.lavaBright.withValues(alpha: ringOpacity * 0.8);
    canvas.drawCircle(center, ringR, ringPaint);

    // Flying sparks.
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (final s in sparks) {
      final d = maxR * s.distance * Curves.easeOut.transform(t);
      final pos = center + Offset(cos(s.angle) * d, sin(s.angle) * d);
      final op = (1.0 - t).clamp(0.0, 1.0);
      sparkPaint.color = Color.lerp(
        MagmaColors.ember,
        MagmaColors.lava,
        t,
      )!.withValues(alpha: op);
      canvas.drawCircle(pos, s.radius * (1.0 - t * 0.5), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExplosionPainter old) => old.t != t;
}
