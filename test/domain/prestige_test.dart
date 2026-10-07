import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/career.dart';
import 'package:idle_theorems/domain/models/conjecture.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/domain/models/save_data.dart';
import 'package:idle_theorems/game/systems/conjecture_system.dart';
import 'package:idle_theorems/game/systems/prestige_service.dart';
import 'package:idle_theorems/game/systems/production_system.dart';

void main() {
  final prestige = const PrestigeService();

  group('conversion formula (§13.9)', () {
    test('floor(sqrt(fame / 100)) matches the design table', () {
      expect(prestige.legacyGain(GameState()..gain(0, 0, 1e4)), 10);
      expect(prestige.legacyGain(GameState()..gain(0, 0, 1e6)), 100);
      expect(prestige.legacyGain(GameState()..gain(0, 0, 1e8)), 1000);
      expect(prestige.legacyGain(GameState()..gain(0, 0, 9999)), 9);
    });

    test('first prestige needs at least 10 legacy worth of Fame', () {
      expect(prestige.canPrestige(GameState()..gain(0, 0, 9999)), isFalse);
      expect(prestige.canPrestige(GameState()..gain(0, 0, 1e4)), isTrue);
    });
  });

  group('reboot rules', () {
    GameState richState() => GameState()
      ..playerName = 'Blaise'
      ..gain(500, 300, 1e5)
      ..producerLevels['guided_exercises'] = 7
      ..upgradeLevels['writing_desk'] = 2
      ..techniques.add('elementary_formalization')
      ..branches = {'analysis': BranchProgress(completed: true)}
      ..activeSubjectId = 'analysis'
      ..career.stage = CareerStage.phd
      ..conjectures.add(ConjectureState(defId: 'double_counting_lemmas'))
      ..stress = 0.4
      ..metodoLevel = 3
      ..metodoXp = 40
      ..stats.papersPublished = 12;

    test('prestige keeps what §13.9 says persists and resets the rest', () {
      final s = richState();
      // One proven conjecture survives with its multiplier.
      s.conjectures.add(
        ConjectureState(defId: 'twin_primes', status: ConjectureStatus.proven),
      );
      s.conjectureCountingMult = 1.25;
      s.prestige.mathematicians.add('gauss');

      prestige.applyPrestige(s);

      // Persisted.
      expect(s.playerName, 'Blaise');
      expect(s.prestige.legacy, 31); // floor(sqrt(1e5/100))
      expect(s.prestige.legacyAllTime, 31);
      expect(s.prestige.prestigesCount, 1);
      expect(s.prestige.mathematicians, contains('gauss'));
      expect(s.metodoLevel, 3);
      expect(s.metodoXp, 40);
      expect(s.stats.papersPublished, 12);
      expect(s.conjectures.single.defId, 'twin_primes');
      expect(s.conjectures.single.status, ConjectureStatus.proven);
      expect(s.conjectureCountingMult, 1.25);

      // Reset.
      expect(s.resources.counting, 0);
      expect(s.resources.fame, 0);
      expect(s.lifetime['fame'], 0);
      expect(s.producerLevels, isEmpty);
      expect(s.upgradeLevels, isEmpty);
      expect(s.techniques, isEmpty);
      expect(s.branches, isEmpty);
      expect(s.activeSubjectId, '');
      expect(s.career.stage, CareerStage.student);
      expect(s.stress, 0);
      expect(s.scheduledRetractions, isEmpty);
      expect(s.trend.activeSubject, isEmpty);
      expect(s.papersInRun, 0);
    });

    test('no-op below the minimum gain', () {
      final s = GameState()..gain(0, 0, 100);
      prestige.applyPrestige(s);
      expect(s.prestige.legacy, 0);
      expect(s.prestige.prestigesCount, 0);
    });
  });

  group('mathematician perks wiring', () {
    test('lifetime Legacy adds +2% per point to every channel', () {
      final base = const ProductionSystem().compute(
        GameState()..producerLevels['guided_exercises'] = 2,
      );
      final boosted = const ProductionSystem().compute(
        GameState()
          ..producerLevels['guided_exercises'] = 2
          ..prestige.legacyAllTime = 5,
      );
      expect(boosted.countingPerSec / base.countingPerSec, closeTo(1.1, 1e-9));
    });

    test('Gauss doubles Counting production', () {
      final base = const ProductionSystem().compute(
        GameState()..producerLevels['guided_exercises'] = 2,
      );
      final gauss = const ProductionSystem().compute(
        GameState()
          ..producerLevels['guided_exercises'] = 2
          ..prestige.mathematicians.add('gauss'),
      );
      expect(gauss.countingPerSec / base.countingPerSec, closeTo(2, 1e-9));
    });

    test('Noether doubles Proofing only on algebraic branches', () {
      final state = GameState()
        ..techniques.add('elementary_formalization')
        ..prestige.mathematicians.add('noether');
      state.activeSubjectId = 'abstract_algebra';
      final onAlgebra = const ProductionSystem().compute(state);
      state.activeSubjectId = 'topology';
      final offAlgebra = const ProductionSystem().compute(state);
      expect(
        onAlgebra.proofingPerSec / offAlgebra.proofingPerSec,
        closeTo(2, 1e-9),
      );
    });

    test('Euler doubles citation Fame', () {
      final base = const ProductionSystem().compute(
        GameState()..papersInRun = 10,
      );
      final euler = const ProductionSystem().compute(
        GameState()
          ..papersInRun = 10
          ..prestige.mathematicians.add('euler'),
      );
      expect(euler.famePerSec / base.famePerSec, closeTo(2, 1e-9));
    });

    test('hiring spends Legacy exactly once', () {
      final s = GameState()..gain(0, 0, 1e5);
      prestige.applyPrestige(s);
      expect(prestige.hireMathematician(s, 'gauss'), isTrue);
      expect(s.prestige.legacy, 31 - 10);
      expect(prestige.hireMathematician(s, 'gauss'), isFalse);
      expect(prestige.hireMathematician(s, 'euler'), isFalse); // too poor
    });
  });

  group('Ramanujan perk', () {
    test('raises conjecture success probability by 10 points', () {
      final svc = ConjectureSystem();
      expect(
        svc.successProbability(3, 2, ramanujanBonus: 0.1) -
            svc.successProbability(3, 2),
        closeTo(0.1, 1e-9),
      );
    });
  });
}
