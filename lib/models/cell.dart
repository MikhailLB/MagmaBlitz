enum CellType {
  empty,
  magma, // target crystal: explodes in a 3x3 area
  amplifier, // target crystal: explodes the whole row and column
  shield, // blocker: absorbs one blast, then is consumed (stops the chain)
  rock, // permanent obstacle: blocks blasts, never destroyed
}

extension CellTypeX on CellType {
  bool get isExplosiveCrystal =>
      this == CellType.magma || this == CellType.amplifier;

  String get asset {
    switch (this) {
      case CellType.magma:
        return 'assets/magma_crystal.webp';
      case CellType.amplifier:
        return 'assets/power_amplifier_crystal.webp';
      case CellType.shield:
        return 'assets/shield_blocker_crystal.webp';
      case CellType.rock:
        return 'assets/rock.webp';
      case CellType.empty:
        return '';
    }
  }
}
