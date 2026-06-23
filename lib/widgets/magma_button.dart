import 'package:flutter/material.dart';

import '../theme.dart';

class MagmaButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool big;

  const MagmaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.big = false,
  });

  @override
  State<MagmaButton> createState() => _MagmaButtonState();
}

class _MagmaButtonState extends State<MagmaButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.big ? 64.0 : 50.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: h,
          decoration: BoxDecoration(
            gradient: MagmaColors.lavaButton,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MagmaColors.ember, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: MagmaColors.lava.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: widget.big ? 30 : 22),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.big ? 24 : 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
