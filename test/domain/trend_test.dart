import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/career.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/domain/models/save_data.dart';
import 'package:idle_theorems/game/systems/conjecture_system.dart';
import 'package:idle_theorems/game/systems/trend_service.dart';

void main() {
  const trend = TrendService();

  group('schedule management', () {
    test('a fresh calendar gets a current slot and a telegraphed next one', () {
      final s = GameState();
      trend.update(s);
      expect(trend.isActive(s), isTrue);
      expect(s.trend.activeSubject, isNotEmpty);
      expect(s.trend.nextSubject, isNotEmpty);
      expect(s.trend.endsAt!.isAfter(DateTime.now()), isTrue);
      // The next slot starts exactly when the active one ends.
      expect(
        s.trend.nextStartsAt!.difference(s.trend.endsAt!),
        const Duration(),
      );
    });

    test('expired slots roll forward to the telegraphed subject', () {
      final s = GameState();
      trend.update(s);
      final announced = s.trend.nextSubject;
      // Simulate the end of the window.
      s.trend.endsAt = DateTime.now().subtract(const Duration(minutes: 1));
      trend.update(s);
      expect(s.trend.activeSubject, announced);
      expect(s.trend.endsAt!.isAfter(DateTime.now()), isTrue);
      expect(s.trend.nextSubject, isNotEmpty);
      expect(
        s.trend.nextStartsAt!.difference(s.trend.endsAt!),
        const Duration(),
      );
    });

    test('long absences resync instead of replaying missed slots', () {
      final s = GameState();
      trend.update(s);
      // A save written ~5 days ago carries both timestamps in the past
      // (_assignNext keeps nextStartsAt == endsAt).
      final past = DateTime.now().subtract(const Duration(days: 5));
      s.trend.endsAt = past;
      s.trend.nextStartsAt = past;
      trend.update(s);
      expect(trend.isActive(s), isTrue);
      expect(s.trend.endsAt!.isAfter(DateTime.now()), isTrue);
      // The resynced window must not exceed one full rotation.
      expect(
        s.trend.endsAt!.difference(DateTime.now()).inHours,
        lessThanOrEqualTo(TrendService.rotation.inHours + 1),
      );
    });

    test('a single missed window honours its scheduled boundary', () {
      final s = GameState();
      trend.update(s);
      final announced = s.trend.nextSubject;
      final boundary = DateTime.now().subtract(const Duration(hours: 12));
      s.trend.endsAt = boundary;
      s.trend.nextStartsAt = boundary;
      trend.update(s);
      expect(s.trend.activeSubject, announced);
      expect(s.trend.endsAt, boundary.add(TrendService.rotation));
    });
  });

  group('trending effects', () {
    test('isTrending matches only the active field while it runs', () {
      final s = GameState();
      trend.update(s);
      final id = s.trend.activeSubject;
      expect(trend.isTrending(s, id), isTrue);
      expect(trend.isTrending(s, 'pde'), isFalse);
      s.trend.endsAt = DateTime.now().subtract(const Duration(seconds: 1));
      expect(trend.isTrending(s, id), isFalse);
    });

    test('conjecture work gains the trending progress bonus', () {
      final svc = ConjectureSystem();
      final s = GameState()
        ..career.stage = CareerStage.postdoc
        ..branches = {'discrete_algebra': BranchProgress(completed: true)}
        ..resources.gain(1e9, 1e9, 0);
      svc.formulate(s, 'double_counting_lemmas');
      s.trend.activeSubject = 'discrete_algebra';
      s.trend.endsAt = DateTime.now().add(const Duration(hours: 24));
      final outcome = svc.workSession(
        s,
        'double_counting_lemmas',
        trendBonus: TrendService.conjectureProgressBonus,
      );
      expect(outcome, isNull);
      expect(s.conjectures.single.progress, closeTo(12.5 * 1.25, 1e-9));
    });
  });

  group('telegraph rules', () {
    test('next rotation is announced inside the 24 h window only', () {
      final s = GameState();
      trend.update(s);
      s.trend.nextStartsAt = DateTime.now().add(const Duration(hours: 30));
      expect(trend.shouldAnnounceNext(s), isFalse);
      s.trend.nextStartsAt = DateTime.now().add(const Duration(hours: 10));
      expect(trend.shouldAnnounceNext(s), isTrue);
    });

    test('mastered Statistics reveals the whole calendar', () {
      final s = GameState()
        ..branches = {'statistics': BranchProgress(completed: true)};
      trend.update(s);
      s.trend.nextStartsAt = DateTime.now().add(const Duration(days: 3));
      expect(trend.shouldAnnounceNext(s), isTrue);
    });
  });
}
