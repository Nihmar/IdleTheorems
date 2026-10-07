import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/domain/models/producers.dart';
import 'package:idle_theorems/domain/services/balance_service.dart';
import 'package:idle_theorems/domain/services/offline_service.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  GameState stateWithProducer(int count) {
    final s = GameState();
    s.producerLevels['guided_exercises'] = count;
    return s;
  }

  double countingRate(GameState s) =>
      (s.producerLevels['guided_exercises'] ?? 0) *
      producerCatalog['guided_exercises']!.outputPerSec;

  group('OfflineService', () {
    test('applies half-rate earnings for time away', () {
      final s = stateWithProducer(2);
      final save = s.toSaveData(now)
        ..savedAt = now.subtract(const Duration(hours: 1))
        ..lastLoadedAt = now.subtract(const Duration(hours: 2));

      final report = const OfflineService().compute(save, now);

      expect(
        report.secondsApplied,
        closeTo(3600 * BalanceService.offlineEfficiency, 0.001),
      );
      expect(
        report.gained.counting,
        closeTo(countingRate(s) * report.secondsApplied, 1e-6),
      );
    });

    test('caps at the offline window (4h default)', () {
      final s = stateWithProducer(1);
      final save = s.toSaveData(now)
        ..savedAt = now.subtract(const Duration(hours: 10))
        ..lastLoadedAt = now.subtract(const Duration(hours: 11));

      final report = const OfflineService().compute(save, now);

      expect(
        report.secondsApplied,
        closeTo(
          BalanceService.offlineCapDefault.inSeconds *
              BalanceService.offlineEfficiency,
          0.001,
        ),
      );
    });

    test('clock rollback grants nothing', () {
      final s = stateWithProducer(1);
      final save = s.toSaveData(now)
        ..savedAt = now.subtract(const Duration(hours: 2))
        ..lastLoadedAt = now.subtract(const Duration(minutes: 30));

      final report = const OfflineService().compute(save, now);
      expect(report.gained.total, 0);
    });

    test('cap multiplier doubles the offline window (Measure Theory)', () {
      final s = stateWithProducer(1);
      final save = s.toSaveData(now)
        ..savedAt = now.subtract(const Duration(hours: 10))
        ..lastLoadedAt = now.subtract(const Duration(hours: 11));

      final base = const OfflineService().compute(save, now);
      final doubled = const OfflineService().compute(
        save,
        now,
        capMultiplier: 2,
      );

      expect(doubled.secondsApplied, closeTo(base.secondsApplied * 2, 0.001));
    });
  });
}
