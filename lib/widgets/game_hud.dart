import 'package:flutter/material.dart';

import '../theme.dart';

/// Code-built volcanic HUD panel shown at the top of the game screen.
class GameHud extends StatelessWidget {
  final int level;
  final int charges;
  final int totalCharges;
  final int crystalsLeft;
  final int totalCrystals;
  final VoidCallback onBack;
  final VoidCallback onRestart;
  final VoidCallback onHelp;

  const GameHud({
    super.key,
    required this.level,
    required this.charges,
    required this.totalCharges,
    required this.crystalsLeft,
    required this.totalCrystals,
    required this.onBack,
    required this.onRestart,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: MagmaColors.panel,
        borderRadius: BorderRadius.circular(18),
        // Uniform border — borderRadius requires all sides same color.
        border: Border.all(color: MagmaColors.rockLight, width: 1.5),
        boxShadow: [
          // Lava glow below the panel acts as the accent bottom line.
          BoxShadow(
            color: MagmaColors.lava.withValues(alpha: 0.8),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _iconBtn(Icons.arrow_back_rounded, onBack),
          const SizedBox(width: 8),
          _badge(label: 'LEVEL', value: '$level'),
          const Spacer(),
          _stat(
            asset: 'assets/magma_fireball_projectile.webp',
            label: 'CHARGES',
            value: '$charges',
            color: MagmaColors.lavaBright,
          ),
          const SizedBox(width: 14),
          _stat(
            asset: 'assets/magma_crystal.webp',
            label: 'CRYSTALS',
            value: '$crystalsLeft',
            color: MagmaColors.ember,
          ),
          const Spacer(),
          _iconBtn(Icons.help_outline_rounded, onHelp),
          const SizedBox(width: 8),
          _iconBtn(Icons.refresh_rounded, onRestart, highlight: true),
        ],
      ),
    );
  }

  Widget _badge({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: MagmaColors.ember,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _stat({
    required String asset,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: MagmaColors.ember,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(asset, width: 26, height: 26),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: const [
                  Shadow(
                      color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {bool highlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: highlight ? MagmaColors.lavaButton : null,
          color: highlight ? null : MagmaColors.rockLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MagmaColors.ember, width: 1),
        ),
        child: Icon(
          icon,
          color: highlight ? Colors.white : MagmaColors.ember,
          size: 22,
        ),
      ),
    );
  }
}
