import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/career.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/game/systems/apprentice_service.dart';
import 'package:idle_theorems/game/systems/production_system.dart';

GameState _professor() => GameState()
  ..career.stage = CareerStage.professor
  ..resources.gain(1e12, 1e12, 1e12);

void main() {
  final svc = const ApprenticeService();

  group('hiring gates', () {
    test('only professors may hire apprentices', () {
      final s = _professor()..career.stage = CareerStage.postdoc;
      expect(svc.canHire(s), isFalse);
      expect(svc.hire(s), isNull);
      expect(s.career.apprentices, 0);
    });

    test('the laboratory caps at five researchers', () {
      final s = _professor();
      for (var i = 0; i < ApprenticeService.max; i++) {
        expect(svc.hire(s), isNotNull);
      }
      expect(s.career.apprentices, ApprenticeService.max);
      expect(svc.nextHire(s.career.apprentices), isNull);
      expect(svc.canHire(s), isFalse);
      expect(svc.hire(s), isNull);
      expect(s.career.apprentices, ApprenticeService.max);
    });
  });

  group('costs and output', () {
    test('hiring pays escalating costs in order', () {
      final s = _professor();
      final first = ApprenticeService.catalog[0];
      final cBefore = s.resources.counting;
      expect(svc.hire(s), first);
      expect(s.resources.counting, closeTo(cBefore - first.costCounting, 1e-9));
      // Second recruit must be the next one in the catalog.
      expect(svc.hire(s), ApprenticeService.catalog[1]);
    });

    test('unaffordable recruits are refused without side effects', () {
      final s = _professor()..resources.spend(1e12, 1e12, 1e12);
      expect(svc.hire(s), isNull);
      expect(s.career.apprentices, 0);
    });

    test('output sums every employed researcher', () {
      expect(svc.outputOf(0), 0);
      expect(svc.outputOf(1), ApprenticeService.catalog[0].countingPerSec);
      var total = 0.0;
      for (final d in ApprenticeService.catalog) {
        total += d.countingPerSec;
      }
      expect(svc.outputOf(ApprenticeService.max), closeTo(total, 1e-9));
    });
  });

  group('production integration', () {
    test('apprentice Counting joins the passive rate', () {
      final prod = const ProductionSystem();
      final base = prod.compute(_professor());
      final withLab = prod.compute(_professor()..career.apprentices = 2);
      final expected = svc.outputOf(2);
      expect(
        withLab.countingPerSec - base.countingPerSec,
        closeTo(expected, 1e-9),
      );
    });

    test('apprentice output scales with conjecture multipliers', () {
      final prod = const ProductionSystem();
      final s = _professor()
        ..career.apprentices = 1
        ..conjectureCountingMult = 2;
      final rates = prod.compute(s);
      final plain = prod.compute(_professor()..career.apprentices = 1);
      expect(rates.countingPerSec / plain.countingPerSec, closeTo(2, 1e-9));
    });
  });
}
