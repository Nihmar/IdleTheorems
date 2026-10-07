import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/career.dart';
import 'package:idle_theorems/domain/models/conjecture.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/domain/models/save_data.dart';
import 'package:idle_theorems/domain/models/producers.dart';
import 'package:idle_theorems/game/systems/conjecture_system.dart';
import 'package:idle_theorems/game/systems/production_system.dart';

/// A funded postdoc who has completed [completed] branches.
GameState _postdoc({List<String> completed = const []}) => GameState()
  ..career.stage = CareerStage.postdoc
  ..branches = {for (final b in completed) b: BranchProgress(completed: true)}
  ..resources.gain(1e12, 1e12, 1e12);

/// Same, but at Professor — required for endgame open problems (§3).
GameState _professor({List<String> completed = const []}) => GameState()
  ..career.stage = CareerStage.professor
  ..branches = {for (final b in completed) b: BranchProgress(completed: true)}
  ..resources.gain(1e12, 1e12, 1e12);

int _seedWhere(bool Function(double) condition) {
  for (var i = 1; i < 1000; i++) {
    if (condition(Random(i).nextDouble())) return i;
  }
  fail('no seed found');
}

void main() {
  group('formulation gates', () {
    test('requires postdoc career stage', () {
      final s = _postdoc(completed: ['discrete_algebra']);
      s.career.stage = CareerStage.student;
      expect(
        ConjectureSystem().canFormulate(s, 'double_counting_lemmas'),
        isFalse,
      );
    });

    test('requires every listed branch to be completed', () {
      final svc = ConjectureSystem();
      final s = _postdoc();
      expect(svc.canFormulate(s, 'double_counting_lemmas'), isFalse);
      expect(
        svc.missingSubjects(s, 'double_counting_lemmas'),
        equals(['discrete_algebra']),
      );
      expect(
        svc.canFormulate(
          _postdoc(completed: ['discrete_algebra']),
          'double_counting_lemmas',
        ),
        isTrue,
      );
    });

    test('already-formulated conjectures cannot be formulated again', () {
      final svc = ConjectureSystem();
      final s = _postdoc(completed: ['discrete_algebra']);
      expect(svc.formulate(s, 'double_counting_lemmas'), isTrue);
      expect(svc.canFormulate(s, 'double_counting_lemmas'), isFalse);
      expect(svc.isFormulated(s, 'double_counting_lemmas'), isTrue);
    });
  });

  group('slot caps', () {
    test('max two active discoveries globally', () {
      final svc = ConjectureSystem();
      final s = _postdoc(
        completed: ['discrete_algebra', 'analysis', 'number_theory'],
      );
      expect(svc.formulate(s, 'double_counting_lemmas'), isTrue);
      expect(svc.formulate(s, 'integral_test_bounds'), isTrue);
      expect(svc.activeCount(s), 2);
      expect(svc.slotsAvailable(s, 'euclid_numbers'), isFalse);
      expect(svc.formulate(s, 'euclid_numbers'), isFalse);
      expect(svc.activeCount(s), 2);
    });

    test('completed topology raises the global cap to three', () {
      final svc = ConjectureSystem();
      final s = _postdoc(
        completed: [
          'discrete_algebra',
          'analysis',
          'number_theory',
          'topology',
        ],
      );
      expect(svc.maxActive(s), 3);
      expect(svc.formulate(s, 'double_counting_lemmas'), isTrue);
      expect(svc.formulate(s, 'integral_test_bounds'), isTrue);
      expect(svc.formulate(s, 'euclid_numbers'), isTrue);
      expect(svc.activeCount(s), 3);
    });

    test('one active discovery per branch', () {
      final svc = ConjectureSystem();
      final s = _professor(completed: ['number_theory']);
      expect(svc.formulate(s, 'goldbach'), isTrue);
      // Collatz shares number_theory with Goldbach.
      expect(svc.slotsAvailable(s, 'collatz'), isFalse);
      expect(svc.formulate(s, 'collatz'), isFalse);
    });
  });

  group('work sessions and resolution', () {
    test('a session pays its cost and adds base progress', () {
      final svc = ConjectureSystem();
      final s = _postdoc(completed: ['discrete_algebra']);
      svc.formulate(s, 'double_counting_lemmas');
      final before = s.resources.proofing;
      final outcome = svc.workSession(s, 'double_counting_lemmas');
      expect(outcome, isNull);
      expect(s.resources.proofing, closeTo(before - 100, 1e-9));
      expect(s.conjectures.single.progress, closeTo(12.5, 1e-9));
    });

    test('success at 100% marks proven and applies rewards', () {
      final seed = _seedWhere((r) => r < 0.5); // tier 1 at Metodo 1 -> p=0.5
      final svc = ConjectureSystem(rng: Random(seed));
      final s = _postdoc(completed: ['discrete_algebra']);
      svc.formulate(s, 'double_counting_lemmas');
      s.conjectures.single.progress = 90;
      final fameBefore = s.lifetimeOf(ResourceKind.fame);
      final outcome = svc.workSession(s, 'double_counting_lemmas');
      expect(outcome, ConjectureOutcome.proved);
      final st = s.conjectures.single;
      expect(st.status, ConjectureStatus.proven);
      expect(st.attempts, 1);
      expect(st.resolvedAt, isNotNull);
      // Reward: +25% counting production.
      expect(s.conjectureCountingMult, closeTo(1.25, 1e-9));
      expect(
        s.lifetimeOf(ResourceKind.fame),
        fameBefore,
      ); // no burst reward here
    });

    test('failure halves progress, sets cooldown, keeps the slot', () {
      final seed = _seedWhere((r) => r >= 0.5);
      final svc = ConjectureSystem(rng: Random(seed));
      final s = _postdoc(completed: ['discrete_algebra']);
      svc.formulate(s, 'double_counting_lemmas');
      s.conjectures.single.progress = 90;
      final outcome = svc.workSession(s, 'double_counting_lemmas');
      expect(outcome, ConjectureOutcome.refuted);
      final st = s.conjectures.single;
      expect(st.status, ConjectureStatus.refuted);
      expect(st.progress, closeTo(50, 1e-9)); // clamped to 100 then halved
      expect(st.readyAt, isNotNull);
      expect(st.readyAt!.difference(DateTime.now()).inMinutes, closeTo(30, 2));
      // Still occupies a slot while cooling down.
      expect(svc.activeCount(s), 1);
    });

    test('cooldown expiry returns the conjecture to workable state', () {
      final svc = ConjectureSystem();
      final s = _postdoc(completed: ['discrete_algebra']);
      svc.formulate(s, 'double_counting_lemmas');
      final st = s.conjectures.single;
      st.status = ConjectureStatus.refuted;
      st.readyAt = DateTime.now().add(const Duration(minutes: 30));
      svc.update(s);
      expect(st.status, ConjectureStatus.refuted); // not yet
      svc.update(s, st.readyAt!);
      expect(st.status, ConjectureStatus.active);
      expect(st.readyAt, isNull);
    });
  });

  group('resolution probability (section 4)', () {
    final svc = ConjectureSystem();
    test('base formula scales with Metodo minus tier', () {
      expect(svc.successProbability(1, 1), closeTo(0.5, 1e-9));
      expect(svc.successProbability(3, 1), closeTo(0.66, 1e-9));
      expect(svc.successProbability(1, 5), closeTo(0.18, 1e-9));
    });

    test('clamped to [0.15, 0.95]', () {
      expect(svc.successProbability(1, 10), closeTo(0.15, 1e-9));
      expect(svc.successProbability(20, 1), closeTo(0.95, 1e-9));
    });

    test('Ramanujan bonus shifts the roll upward', () {
      expect(
        svc.successProbability(1, 1, ramanujanBonus: 0.10),
        closeTo(0.60, 1e-9),
      );
    });
  });

  group('reward application', () {
    test('fame bursts grant Fame immediately', () {
      final svc = ConjectureSystem();
      final p = svc.successProbability(1, 2); // tier 2 at Metodo 1
      final seed = _seedWhere((r) => r < p);
      final svcSeeded = ConjectureSystem(rng: Random(seed));
      final s = _postdoc(completed: ['statistics']);
      svcSeeded.formulate(s, 'concentration_inequalities');
      s.conjectures.single.progress = 95;
      final before = s.resources.fame;
      expect(
        svcSeeded.workSession(s, 'concentration_inequalities'),
        ConjectureOutcome.proved,
      );
      expect(s.resources.fame - before, closeTo(5000, 1e-9));
    });

    test('legacy bonuses credit Legacy points', () {
      final svc = ConjectureSystem();
      final p = svc.successProbability(1, 5); // tier 5 at Metodo 1 -> 0.18
      final seed = _seedWhere((r) => r < p);
      final svcSeeded = ConjectureSystem(rng: Random(seed));
      final s = _professor(completed: ['number_theory']);
      svcSeeded.formulate(s, 'goldbach');
      s.conjectures.single.progress = 98;
      expect(svcSeeded.workSession(s, 'goldbach'), ConjectureOutcome.proved);
      expect(s.prestige.legacy, 500);
      expect(s.conjectureGlobalMult, closeTo(1.5, 1e-9));
    });

    test('proven multipliers feed passive production', () {
      final s = _postdoc()
        ..producerLevels['guided_exercises'] = 1
        ..conjectureCountingMult = 1.25
        ..conjectureGlobalMult = 1.5;
      final rates = const ProductionSystem().compute(s);
      // guided_exercises base output scaled by both conjecture multipliers.
      final base = const ProductionSystem().compute(
        _postdoc()..producerLevels['guided_exercises'] = 1,
      );
      expect(rates.countingPerSec / base.countingPerSec, closeTo(1.875, 1e-9));
    });
  });

  group('endgame gating (section 3)', () {
    test('open problems stay sealed below Professor', () {
      final svc = ConjectureSystem();
      final s = _postdoc(completed: ['number_theory']);
      expect(svc.endgameLocked(s, conjectureCatalog['goldbach']!), isTrue);
      expect(svc.canFormulate(s, 'goldbach'), isFalse);
    });

    test('Professor with completed branches may open the frontiers', () {
      final svc = ConjectureSystem();
      final s = _professor(completed: ['number_theory']);
      expect(svc.endgameLocked(s, conjectureCatalog['goldbach']!), isFalse);
      expect(svc.canFormulate(s, 'goldbach'), isTrue);
    });

    test('non-endgame definitions ignore the professor gate', () {
      final svc = ConjectureSystem();
      expect(
        svc.endgameLocked(_postdoc(), conjectureCatalog['collatz']!),
        isFalse,
      );
    });
  });

  group('cosmetic titles', () {
    test('proving an open problem grants its title once', () {
      final p = ConjectureSystem().successProbability(1, 5); // -> 0.18
      final seed = _seedWhere((r) => r < p);
      final svc = ConjectureSystem(rng: Random(seed));
      final s = _professor(completed: ['number_theory']);
      svc.formulate(s, 'goldbach');
      s.conjectures.single.progress = 98;
      expect(svc.workSession(s, 'goldbach'), ConjectureOutcome.proved);
      expect(s.titles, contains('Prime Summarizer'));
      expect(
        conjectureCatalog['goldbach']!.rewardSummary,
        contains('"Prime Summarizer" title'),
      );
    });
  });
}
