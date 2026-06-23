import 'dart:async';

import 'package:flutter/material.dart';

import '../models/cell.dart';
import '../models/level.dart';
import '../models/level_generator.dart';
import '../services/progress_service.dart';
import '../theme.dart';
import '../widgets/explosion_fx.dart';
import '../widgets/game_hud.dart';
import 'how_to_play_screen.dart';

class GameScreen extends StatefulWidget {
  final int levelIndex;
  const GameScreen({super.key, required this.levelIndex});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Level _level;
  late int _charges;
  late int _totalCharges;
  late int _startCrystals;

  bool _busy = false;
  bool _ended = false;
  final List<_Fx> _fx = [];
  int _fxCounter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _level = LevelGenerator.build(widget.levelIndex).copy();
    _charges = _level.charges;
    _totalCharges = _level.charges;
    _startCrystals = _level.totalCrystals;
    _busy = false;
    _ended = false;
    _fx.clear();
  }

  Future<void> _onTapCell(int r, int c) async {
    if (_busy || _ended) return;
    if (_charges <= 0) return;

    setState(() {
      _busy = true;
      _charges--;
    });

    final sim = _level.copy();
    final result = sim.detonate(r, c);

    for (final wave in result.waves) {
      if (!mounted) return;
      setState(() {
        for (final cell in wave.flash) {
          _fx.add(_Fx(id: _fxCounter++, r: cell.r, c: cell.c));
        }
        for (final cell in wave.destroyed) {
          _level.grid[cell.r][cell.c] = CellType.empty;
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    if (!mounted) return;
    setState(() => _busy = false);
    _checkEnd();
  }

  void _removeFx(int id) {
    if (!mounted) return;
    setState(() => _fx.removeWhere((f) => f.id == id));
  }

  Future<void> _checkEnd() async {
    if (_ended) return;
    if (_level.isCleared) {
      _ended = true;
      final stars = _calcStars();
      await ProgressService.instance.completeLevel(widget.levelIndex, stars);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) _showWin(stars);
    } else if (_charges <= 0) {
      _ended = true;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) _showLose();
    }
  }

  int _calcStars() {
    final used = _totalCharges - _charges;
    final par = _totalCharges;
    if (used <= par - 2) return 3;
    if (used <= par - 1) return 2;
    return 1;
  }

  void _openHelp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bg.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.55)),
          SafeArea(
            child: Column(
              children: [
                GameHud(
                  level: widget.levelIndex,
                  charges: _charges,
                  totalCharges: _totalCharges,
                  crystalsLeft: _level.totalCrystals,
                  totalCrystals: _startCrystals,
                  onBack: () => Navigator.of(context).pop(),
                  onRestart: () => setState(_load),
                  onHelp: _openHelp,
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildBoard()),
                _buildHint(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        _charges > 0 ? 'Tap to launch a magma charge' : 'Out of charges!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _charges > 0 ? MagmaColors.ember : MagmaColors.lava,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellW = constraints.maxWidth / _level.cols;
          final cellH = constraints.maxHeight / _level.rows;
          final cell = cellW < cellH ? cellW : cellH;
          final boardW = cell * _level.cols;
          final boardH = cell * _level.rows;
          return Center(
            child: SizedBox(
              width: boardW,
              height: boardH,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: MagmaColors.rockLight.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  for (var r = 0; r < _level.rows; r++)
                    for (var c = 0; c < _level.cols; c++)
                      Positioned(
                        left: c * cell,
                        top: r * cell,
                        width: cell,
                        height: cell,
                        child: _CellView(
                          type: _level.grid[r][c],
                          onTap: () => _onTapCell(r, c),
                        ),
                      ),
                  for (final f in _fx)
                    Positioned(
                      left: f.c * cell,
                      top: f.r * cell,
                      width: cell,
                      height: cell,
                      child: ExplosionFx(
                        key: ValueKey(f.id),
                        size: cell,
                        seed: f.id,
                        onDone: () => _removeFx(f.id),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showWin(int stars) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        title: 'LEVEL CLEARED',
        stars: stars,
        isWin: true,
        hasNext: widget.levelIndex < LevelGenerator.totalLevels,
        onReplay: () {
          Navigator.of(context).pop();
          setState(_load);
        },
        onNext: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(levelIndex: widget.levelIndex + 1),
            ),
          );
        },
        onMenu: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showLose() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        title: 'OUT OF CHARGES',
        stars: 0,
        isWin: false,
        hasNext: false,
        onReplay: () {
          Navigator.of(context).pop();
          setState(_load);
        },
        onNext: () {},
        onMenu: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Fx {
  final int id;
  final int r;
  final int c;
  _Fx({required this.id, required this.r, required this.c});
}

class _CellView extends StatelessWidget {
  final CellType type;
  final VoidCallback onTap;
  const _CellView({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
          child: type == CellType.empty
              ? const SizedBox.shrink(key: ValueKey('empty'))
              : Image.asset(type.asset, key: ValueKey(type), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ResultDialog extends StatelessWidget {
  final String title;
  final int stars;
  final bool isWin;
  final bool hasNext;
  final VoidCallback onReplay;
  final VoidCallback onNext;
  final VoidCallback onMenu;

  const _ResultDialog({
    required this.title,
    required this.stars,
    required this.isWin,
    required this.hasNext,
    required this.onReplay,
    required this.onNext,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
        decoration: BoxDecoration(
          gradient: MagmaColors.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: MagmaColors.lava, width: 2),
          boxShadow: [
            BoxShadow(
              color: MagmaColors.lava.withValues(alpha: 0.4),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: isWin ? MagmaColors.ember : MagmaColors.lava,
              ),
            ),
            const SizedBox(height: 16),
            if (isWin)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 44,
                      color: i < stars ? MagmaColors.ember : Colors.black38,
                    ),
                  );
                }),
              )
            else ...[
              const Icon(Icons.local_fire_department_rounded,
                  size: 56, color: MagmaColors.lava),
              const SizedBox(height: 8),
              const Text(
                "Don't give up — try again!",
                style: TextStyle(color: MagmaColors.ash, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            // Buttons row.
            Row(
              children: [
                _smallBtn(icon: Icons.home_rounded, onTap: onMenu),
                const SizedBox(width: 8),
                Expanded(
                  child: _bigBtn(
                    icon: Icons.refresh_rounded,
                    label: 'RETRY',
                    onTap: onReplay,
                  ),
                ),
                if (isWin && hasNext) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _bigBtn(
                      icon: Icons.arrow_forward_rounded,
                      label: 'NEXT',
                      onTap: onNext,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: MagmaColors.rockLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MagmaColors.ember, width: 1.2),
        ),
        child: Icon(icon, color: MagmaColors.ember, size: 22),
      ),
    );
  }

  Widget _bigBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
          gradient: MagmaColors.lavaButton,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MagmaColors.ember, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
