import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/career.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/domain/models/save_data.dart';
import 'package:idle_theorems/game/systems/career_system.dart';
import 'package:idle_theorems/game/systems/friction_system.dart';
import 'package:idle_theorems/game/systems/production_system.dart';

void main() {
  group('career stage rules (section 5)', () {
    test('papers earn half Fame before the thesis defense', () {
      expect(CareerSystem.paperFameFactor(CareerState()), 0.5);
      expect(
        CareerSystem.paperFameFactor(CareerState(thesisDefended: true)),
        1.0,
      );
    });

    test('next stage hint tracks lifetime Fame thresholds', () {
      final s = GameState();
      expect(CareerSystem.nextStageHint(s), contains('PhD'));
      s.career.stage = CareerStage.phd;
      expect(CareerSystem.nextStageHint(s), contains('Postdoc'));
      s.career.stage = CareerStage.postdoc;
      expect(CareerSystem.nextStageHint(s), contains('Professor'));
      s.career.stage = CareerStage.professor;
      expect(CareerSystem.nextStageHint(s), isEmpty);
    });
  });

  group('retractions (section 2)', () {
    const friction = FrictionSystem();

    test('accepted papers have a small chance of scheduling one', () {
      var seed = 1;
      while (Random(seed).nextDouble() >= FrictionSystem.retractionChance) {
        seed++;
      }
      final s = GameState();
      friction.maybeScheduleRetraction(s, Random(seed));
      expect(s.scheduledRetractions, hasLength(1));
      final wait = s.scheduledRetractions.single.dueAt.difference(
        DateTime.now(),
      );
      expect(wait.inMinutes, inInclusiveRange(9, 11));
    });

    test('due retractions cut Fame, count stats, then clear', () {
      final s = GameState()..resources.gain(0, 0, 1000);
      s.scheduledRetractions.add(ScheduledRetraction(DateTime.now()));
      final notices = friction.tick(s, 1);
      expect(notices, hasLength(1));
      expect(s.resources.fame, closeTo(800, 1e-9)); // -20%
      expect(s.stats.retractions, 1);
      expect(s.scheduledRetractions, isEmpty);
    });
  });

  group('burnout (section 13.10)', () {
    const friction = FrictionSystem();

    test('sustained overload triggers burnout at full stress', () {
      final s = GameState();
      for (var i = 0; i < FrictionSystem.overloadPaperThreshold; i++) {
        s.activePapers.add(PaperJob(60));
      }
      friction.tick(s, 900); // fills the bar in ~15 min
      expect(friction.isBurnedOut(s), isTrue);
      expect(friction.productionMultiplier(s), 0.5);
      expect(s.stress, FrictionSystem.postBurnoutStress);
    });

    test('calm time fades stress back to zero', () {
      final s = GameState()..stress = 1.0;
      friction.tick(s, 1800);
      expect(s.stress, closeTo(0, 1e-9));
    });

    test('burnout halves passive production rates', () {
      final base = const ProductionSystem().compute(
        GameState()..producerLevels['guided_exercises'] = 2,
      );
      final burned = const ProductionSystem().compute(
        GameState()
          ..producerLevels['guided_exercises'] = 2
          ..burnedOutUntil = DateTime.now().add(const Duration(hours: 1)),
      );
      expect(burned.countingPerSec / base.countingPerSec, closeTo(0.5, 1e-9));
    });

    test('sabbatical clears everything for 10% of current Fame', () {
      final s = GameState()
        ..resources.gain(0, 0, 1000)
        ..stress = 0.8
        ..burnedOutUntil = DateTime.now().add(const Duration(minutes: 30));
      expect(friction.takeSabbatical(s), isTrue);
      expect(s.resources.fame, closeTo(900, 1e-9));
      expect(s.stress, 0);
      expect(s.burnedOutUntil, isNull);
    });

    test('sabbatical needs some Fame to pay', () {
      final s = GameState()..stress = 0.5;
      expect(friction.takeSabbatical(s), isFalse);
    });
  });
}
