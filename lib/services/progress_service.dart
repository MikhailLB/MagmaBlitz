import 'package:shared_preferences/shared_preferences.dart';

import '../models/level_generator.dart';

/// Stores how many levels the player has unlocked/completed.
class ProgressService {
  static const _keyUnlocked = 'unlocked_level';
  static const _keyStars = 'stars_'; // + level index

  static final ProgressService instance = ProgressService._();
  ProgressService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Highest unlocked level (1-based). Level 1 always unlocked.
  int get unlockedLevel => (_prefs?.getInt(_keyUnlocked) ?? 1).clamp(1, LevelGenerator.totalLevels);

  bool isUnlocked(int index) => index <= unlockedLevel;

  int starsFor(int index) => _prefs?.getInt('$_keyStars$index') ?? 0;

  Future<void> completeLevel(int index, int stars) async {
    await init();
    final prevStars = starsFor(index);
    if (stars > prevStars) {
      await _prefs!.setInt('$_keyStars$index', stars);
    }
    final next = index + 1;
    if (next > unlockedLevel && next <= LevelGenerator.totalLevels) {
      await _prefs!.setInt(_keyUnlocked, next);
    }
  }

  int get totalStars {
    var sum = 0;
    for (var i = 1; i <= LevelGenerator.totalLevels; i++) {
      sum += starsFor(i);
    }
    return sum;
  }
}
