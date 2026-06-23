import 'cell.dart';

typedef CellPos = ({int r, int c});

/// One step of a chain reaction.
class ExplosionWave {
  final List<CellPos> flash; // cells where a blast graphic appears
  final List<CellPos> destroyed; // cells emptied this wave
  ExplosionWave(this.flash, this.destroyed);
}

/// Result of detonating a tap: ordered waves, for animation.
class ExplosionResult {
  final List<ExplosionWave> waves;
  final int crystalsDestroyed;
  ExplosionResult(this.waves, this.crystalsDestroyed);
}

class Level {
  final int index; // 1-based
  final int rows;
  final int cols;
  final List<List<CellType>> grid;
  final int charges; // par charges granted to the player

  Level({
    required this.index,
    required this.rows,
    required this.cols,
    required this.grid,
    required this.charges,
  });

  int get totalCrystals {
    var n = 0;
    for (final row in grid) {
      for (final c in row) {
        if (c.isExplosiveCrystal) n++;
      }
    }
    return n;
  }

  Level copy() {
    return Level(
      index: index,
      rows: rows,
      cols: cols,
      grid: [for (final row in grid) List<CellType>.from(row)],
      charges: charges,
    );
  }

  bool _inside(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  /// Cells affected by a "normal" 3x3 blast centered at (r,c).
  List<CellPos> _normalArea(int r, int c) {
    final out = <CellPos>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final nr = r + dr, nc = c + dc;
        if (_inside(nr, nc)) out.add((r: nr, c: nc));
      }
    }
    return out;
  }

  /// Cells affected by an amplifier blast: full row & column from (r,c),
  /// stopping at rock (blocked) or shield (consumed, included).
  List<CellPos> _amplifierArea(int r, int c) {
    final out = <CellPos>[(r: r, c: c)];
    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    for (final d in dirs) {
      var nr = r + d[0], nc = c + d[1];
      while (_inside(nr, nc)) {
        final t = grid[nr][nc];
        if (t == CellType.rock) break;
        out.add((r: nr, c: nc));
        if (t == CellType.shield) break;
        nr += d[0];
        nc += d[1];
      }
    }
    return out;
  }

  /// Simulate a tap at (r,c). Mutates [grid] (destroys crystals/shields)
  /// to the final state, and returns the wave sequence for animation.
  ExplosionResult detonate(int r, int c) {
    final waves = <ExplosionWave>[];
    var destroyed = 0;

    // A pending detonation: its center and whether it is an amplifier-type blast.
    var current = <({int r, int c, bool amp})>[
      (r: r, c: c, amp: false),
    ];

    while (current.isNotEmpty) {
      final flash = <CellPos>{};
      final destroyedThisWave = <CellPos>[];
      final next = <({int r, int c, bool amp})>[];

      for (final det in current) {
        final area = det.amp
            ? _amplifierArea(det.r, det.c)
            : _normalArea(det.r, det.c);
        for (final cell in area) {
          flash.add(cell);
          final t = grid[cell.r][cell.c];
          if (t.isExplosiveCrystal) {
            grid[cell.r][cell.c] = CellType.empty;
            destroyed++;
            destroyedThisWave.add(cell);
            next.add((r: cell.r, c: cell.c, amp: t == CellType.amplifier));
          } else if (t == CellType.shield) {
            grid[cell.r][cell.c] = CellType.empty;
            destroyedThisWave.add(cell);
          }
        }
      }

      waves.add(ExplosionWave(flash.toList(), destroyedThisWave));
      current = next;
    }

    return ExplosionResult(waves, destroyed);
  }

  bool get isCleared => totalCrystals == 0;
}
