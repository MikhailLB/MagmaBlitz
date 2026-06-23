import 'package:flutter_test/flutter_test.dart';

import 'package:magma_blitz/models/level_generator.dart';

void main() {
  test('all 40 levels generate with solvable charges', () {
    for (var i = 1; i <= LevelGenerator.totalLevels; i++) {
      final level = LevelGenerator.build(i);
      expect(level.totalCrystals, greaterThan(0),
          reason: 'level $i has no crystals');
      expect(level.charges, greaterThanOrEqualTo(1),
          reason: 'level $i has no charges');
      expect(level.charges, lessThanOrEqualTo(level.totalCrystals),
          reason: 'level $i should never need more taps than crystals');
    }
  });
}
