import 'dart:math';

import 'cell.dart';
import 'level.dart';

/// Deterministic procedural generator producing 40 levels, easy -> hard.
class LevelGenerator {
  static const int totalLevels = 40;

  static final Map<int, Level> _cache = {};

  static Level build(int index) {
    return _cache.putIfAbsent(index, () => _generate(index));
  }

  static Level _generate(int index) {
    // Grid grows with progression.
    final cols = _clamp(5 + (index - 1) ~/ 8, 5, 8);
    final rows = _clamp(6 + (index - 1) ~/ 5, 6, 11);

    // Difficulty knobs.
    final crystalDensity = 0.28 + (index / totalLevels) * 0.20; // 0.28 -> 0.48
    final amplifierStart = 6;
    final shieldStart = 12;
    final rockStart = 4;

    List<List<CellType>> grid;
    int par;
    var attempt = 0;

    // Keep generating until we have a sensible level (>= a few crystals).
    do {
      grid = _emptyGrid(rows, cols);
      final r2 = Random(1000 + index + attempt * 97);

      // Place rocks (obstacles).
      if (index >= rockStart) {
        final rocks = (rows * cols * (0.04 + (index / totalLevels) * 0.07))
            .round();
        _scatter(grid, r2, rocks, CellType.rock);
      }

      // Place shields (blockers).
      if (index >= shieldStart) {
        final shields = 1 + (index - shieldStart) ~/ 6;
        _scatter(grid, r2, shields, CellType.shield);
      }

      // Place amplifiers.
      if (index >= amplifierStart) {
        final amps = 1 + (index - amplifierStart) ~/ 8;
        _scatter(grid, r2, amps, CellType.amplifier);
      }

      // Fill remaining cells with magma crystals by density.
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (grid[r][c] == CellType.empty && r2.nextDouble() < crystalDensity) {
            grid[r][c] = CellType.magma;
          }
        }
      }

      par = _computePar(grid, rows, cols);
      attempt++;
    } while (_countCrystals(grid) < 4 + index ~/ 6 && attempt < 40);

    // Charges: par + leniency that tightens as levels progress.
    final bonus = index <= 8
        ? 2
        : index <= 20
            ? 1
            : 0;
    final charges = max(1, par + bonus);

    return Level(
      index: index,
      rows: rows,
      cols: cols,
      grid: grid,
      charges: charges,
    );
  }

  // ---- helpers ----

  static int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  static List<List<CellType>> _emptyGrid(int rows, int cols) =>
      List.generate(rows, (_) => List.filled(cols, CellType.empty));

  static int _countCrystals(List<List<CellType>> grid) {
    var n = 0;
    for (final row in grid) {
      for (final c in row) {
        if (c.isExplosiveCrystal) n++;
      }
    }
    return n;
  }

  static void _scatter(
    List<List<CellType>> grid,
    Random rng,
    int count,
    CellType type,
  ) {
    final rows = grid.length, cols = grid[0].length;
    var placed = 0, guard = 0;
    while (placed < count && guard < count * 50 + 50) {
      guard++;
      final r = rng.nextInt(rows), c = rng.nextInt(cols);
      if (grid[r][c] == CellType.empty) {
        grid[r][c] = type;
        placed++;
      }
    }
  }

  /// Minimum taps needed (upper bound that is always achievable):
  /// number of source strongly-connected components in the "ignites" graph.
  static int _computePar(List<List<CellType>> grid, int rows, int cols) {
    bool inside(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;
    int id(int r, int c) => r * cols + c;

    // Collect explosive crystal nodes.
    final nodes = <int>[];
    final nodeIndex = <int, int>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (grid[r][c].isExplosiveCrystal) {
          nodeIndex[id(r, c)] = nodes.length;
          nodes.add(id(r, c));
        }
      }
    }
    final n = nodes.length;
    if (n == 0) return 0;

    final adj = List.generate(n, (_) => <int>[]);

    void addEdge(int fromR, int fromC, int toR, int toC) {
      final f = nodeIndex[id(fromR, fromC)];
      final t = nodeIndex[id(toR, toC)];
      if (f != null && t != null && f != t) adj[f].add(t);
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final t = grid[r][c];
        if (t == CellType.magma) {
          for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
              if (dr == 0 && dc == 0) continue;
              final nr = r + dr, nc = c + dc;
              if (inside(nr, nc) && grid[nr][nc].isExplosiveCrystal) {
                addEdge(r, c, nr, nc);
              }
            }
          }
        } else if (t == CellType.amplifier) {
          const dirs = [
            [-1, 0],
            [1, 0],
            [0, -1],
            [0, 1],
          ];
          for (final d in dirs) {
            var nr = r + d[0], nc = c + d[1];
            while (inside(nr, nc)) {
              final ct = grid[nr][nc];
              if (ct == CellType.rock) break;
              if (ct.isExplosiveCrystal) addEdge(r, c, nr, nc);
              if (ct == CellType.shield) break;
              nr += d[0];
              nc += d[1];
            }
          }
        }
      }
    }

    return _countSourceSccs(n, adj);
  }

  /// Tarjan SCC + count condensed components with in-degree 0.
  static int _countSourceSccs(int n, List<List<int>> adj) {
    final indexOf = List.filled(n, -1);
    final low = List.filled(n, 0);
    final onStack = List.filled(n, false);
    final comp = List.filled(n, -1);
    final stack = <int>[];
    var counter = 0;
    var sccCount = 0;

    // Iterative Tarjan to avoid stack overflow.
    for (var start = 0; start < n; start++) {
      if (indexOf[start] != -1) continue;
      final callStack = <List<int>>[]; // [node, childPtr]
      callStack.add([start, 0]);
      indexOf[start] = low[start] = counter++;
      stack.add(start);
      onStack[start] = true;

      while (callStack.isNotEmpty) {
        final frame = callStack.last;
        final v = frame[0];
        if (frame[1] < adj[v].length) {
          final w = adj[v][frame[1]];
          frame[1]++;
          if (indexOf[w] == -1) {
            indexOf[w] = low[w] = counter++;
            stack.add(w);
            onStack[w] = true;
            callStack.add([w, 0]);
          } else if (onStack[w]) {
            if (indexOf[w] < low[v]) low[v] = indexOf[w];
          }
        } else {
          if (low[v] == indexOf[v]) {
            while (true) {
              final u = stack.removeLast();
              onStack[u] = false;
              comp[u] = sccCount;
              if (u == v) break;
            }
            sccCount++;
          }
          callStack.removeLast();
          if (callStack.isNotEmpty) {
            final parent = callStack.last[0];
            if (low[v] < low[parent]) low[parent] = low[v];
          }
        }
      }
    }

    // Count components with in-degree 0.
    final hasIncoming = List.filled(sccCount, false);
    for (var v = 0; v < n; v++) {
      for (final w in adj[v]) {
        if (comp[v] != comp[w]) hasIncoming[comp[w]] = true;
      }
    }
    var sources = 0;
    for (var i = 0; i < sccCount; i++) {
      if (!hasIncoming[i]) sources++;
    }
    return sources;
  }
}
