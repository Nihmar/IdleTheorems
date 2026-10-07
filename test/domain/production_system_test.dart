import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/game/systems/production_system.dart';

void main() {
  group('effective click power (§13.2)', () {
    final prod = const ProductionSystem();

    test('base click without upgrades or bonuses', () {
      expect(prod.clickPower(GameState()), closeTo(1, 1e-9));
    });

    test('study tools add +100% Counting per level', () {
      final s = GameState()..upgradeLevels['study_tools'] = 2;
      expect(prod.clickPower(s), closeTo(3, 1e-9));
    });

    test('lifetime Legacy adds +2% per point to clicks', () {
      final s = GameState()..prestige.legacyAllTime = 5;
      expect(prod.clickPower(s), closeTo(1.1, 1e-9));
    });

    test('completed-challenge boost applies to clicks', () {
      final s = GameState()..challengeGlobalMult = 1.05;
      expect(prod.clickPower(s), closeTo(1.05, 1e-9));
    });

    test('conjecture counting and global boosts apply to clicks', () {
      final s = GameState()
        ..conjectureCountingMult = 1.25
        ..conjectureGlobalMult = 1.5;
      expect(prod.clickPower(s), closeTo(1.875, 1e-9));
    });
  });
}
