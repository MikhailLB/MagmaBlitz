import 'package:flutter/material.dart';

import '../models/level_generator.dart';
import '../services/progress_service.dart';
import '../theme.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.instance;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bg.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.55)),
          SafeArea(
            child: Column(
              children: [
                _header(context, progress),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                    ),
                    itemCount: LevelGenerator.totalLevels,
                    itemBuilder: (context, i) {
                      final index = i + 1;
                      final unlocked = progress.isUnlocked(index);
                      final stars = progress.starsFor(index);
                      return _LevelTile(
                        index: index,
                        unlocked: unlocked,
                        stars: stars,
                        onTap: unlocked
                            ? () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        GameScreen(levelIndex: index),
                                  ),
                                );
                                if (mounted) setState(() {});
                              }
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ProgressService progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: MagmaColors.ash),
          ),
          const Text(
            'SELECT LEVEL',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: MagmaColors.ash,
            ),
          ),
          const Spacer(),
          const Icon(Icons.star_rounded, color: MagmaColors.ember, size: 22),
          const SizedBox(width: 4),
          Text(
            '${progress.totalStars}',
            style: const TextStyle(
              color: MagmaColors.ember,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int index;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.index,
    required this.unlocked,
    required this.stars,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: unlocked ? MagmaColors.lavaButton : MagmaColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked ? MagmaColors.ember : MagmaColors.rockLight,
            width: 1.5,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: MagmaColors.lava.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (unlocked)
              Text(
                '$index',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              )
            else
              const Icon(Icons.lock_rounded,
                  color: MagmaColors.rockLight, size: 28),
            if (unlocked)
              Positioned(
                bottom: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (s) {
                    return Icon(
                      s < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 13,
                      color: s < stars ? MagmaColors.ember : Colors.black38,
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
