import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/domain/models/save_data.dart';
import 'package:idle_theorems/domain/models/subject.dart';
import 'package:idle_theorems/domain/services/subject_service.dart';

GameState _state({Map<String, BranchProgress>? branches, String focus = ''}) =>
    GameState()
      ..branches = branches ?? {}
      ..activeSubjectId = focus;

void main() {
  const svc = SubjectService();

  group('unlock rules', () {
    test('LV0 starts unlocked, dependents stay locked until prereqs complete',
        () {
      final s = _state();
      expect(svc.isUnlocked(s, 'logic_sets'), isTrue);
      expect(svc.isUnlocked(s, 'discrete_algebra'), isFalse);
      expect(
          svc.missingPrereqs(s, 'multivariable_calculus'),
          containsAll(['analysis', 'geometry']));
    });

    test('completing every prerequisite unlocks the subject', () {
      final s = _state(branches: {
        'analysis': BranchProgress(completed: true),
        'geometry': BranchProgress(completed: true),
      });
      expect(svc.isUnlocked(s, 'multivariable_calculus'), isTrue);
    });
  });

  group('focus and mastery', () {
    test('cannot focus a locked or already completed subject', () {
      expect(svc.setFocus(_state(), 'discrete_algebra'), isFalse);
      final done = _state(
          branches: {'logic_sets': BranchProgress(completed: true)});
      expect(svc.setFocus(done, 'logic_sets'), isFalse);
    });

    test('accepted papers credit the focused subject; mastery clears focus',
        () {
      final s = _state(focus: 'logic_sets');
      for (var i = 0; i < masteryNeeded(0) - 1; i++) {
        svc.registerAcceptedPaper(s);
      }
      expect(s.branches['logic_sets']!.theoremsMastered, masteryNeeded(0) - 1);
      expect(s.activeSubjectId, 'logic_sets');

      svc.registerAcceptedPaper(s);
      expect(svc.isCompleted(s, 'logic_sets'), isTrue);
      expect(s.activeSubjectId, isEmpty);
    });

    test('accepted papers without a focus grant no theorems', () {
      final s = _state();
      svc.registerAcceptedPaper(s);
      expect(s.branches, isEmpty);
    });
  });

  group('modifiers from completed subjects', () {
    test('no completed subjects means identity modifiers', () {
      final m = svc.modifiers(_state());
      expect(m.clickMultiplier, 1);
      expect(m.countingRateAdd, 0);
      expect(m.paperCostFactor, 1);
      expect(m.extraPapers, 0);
      expect(m.globalResourceMult, 1);
    });

    test('multipliers combine multiplicatively across subjects', () {
      final s = _state(branches: {
        'category_theory': BranchProgress(completed: true),
        'algebraic_geometry': BranchProgress(completed: true),
      });
      final m = svc.modifiers(s);
      expect(m.globalResourceMult, closeTo(1.05, 1e-9));
      expect(m.countingMultiplier, closeTo(1.25, 1e-9));
      expect(m.proofingMultiplier, closeTo(1.25, 1e-9));
    });

    test('flat rates add up', () {
      final s = _state(branches: {
        'discrete_algebra': BranchProgress(completed: true),
        'abstract_algebra': BranchProgress(completed: true),
      });
      final m = svc.modifiers(s);
      expect(m.countingRateAdd, closeTo(0.5, 1e-9));
      expect(m.proofingRateAdd, closeTo(1.0, 1e-9));
    });

    test('number theory scales Counting with total theorems mastered', () {
      final s = _state(branches: {
        'number_theory':
            BranchProgress(completed: true, theoremsMastered: 8),
        'logic_sets': BranchProgress(theoremsMastered: 3),
      });
      // 8 + 3 = 11 theorems -> x1.22 counting multiplier.
      expect(svc.modifiers(s).countingMultiplier, closeTo(1 + 0.02 * 11, 1e-9));
    });

    test('completed topology adds a concurrent paper slot', () {
      expect(svc.maxConcurrentPapers(_state()), 1);
      expect(
          svc.maxConcurrentPapers(_state(
              branches: {'topology': BranchProgress(completed: true)})),
          2);
    });
  });
}
