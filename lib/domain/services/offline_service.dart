import '../../game/systems/production_system.dart';
import '../models/game_state.dart';
import '../models/resources.dart';
import '../models/save_data.dart';
import 'balance_service.dart';
import 'subject_service.dart';

class OfflineReport {
  final double secondsApplied;
  final Resources gained;

  const OfflineReport(this.secondsApplied, this.gained);
}

/// Offline progression with anti-clock-rollback guard (plan sections 13.10,
/// 14.3). Default cap 4h at 50% efficiency; Measure Theory doubles the cap
/// once branches exist (phase 2+).
class OfflineService {
  const OfflineService({ProductionSystem? production})
      : _production = production ?? const ProductionSystem();

  final ProductionSystem _production;

  /// [capMultiplier] extends the default window (Measure Theory x2); [mods]
  /// carries completed-subject effects into the rate computation.
  OfflineReport compute(SaveData save, DateTime now,
      {double capMultiplier = 1, SubjectModifiers? mods}) {
    var elapsedMs = now.difference(save.savedAt).inMilliseconds;
    // Clock rolled backwards since last load -> no offline earnings.
    if (save.savedAt.isBefore(save.lastLoadedAt)) elapsedMs = 0;
    if (elapsedMs < 0) elapsedMs = 0;

    final capMs = BalanceService.offlineCapDefault.inMilliseconds * capMultiplier;
    final cappedMs = elapsedMs < capMs ? elapsedMs : capMs;
    final appliedSeconds = cappedMs / 1000 * BalanceService.offlineEfficiency;

    final rates = _production.compute(GameState.fromSave(save), mods);
    return OfflineReport(
      appliedSeconds,
      Resources(
        counting: rates.countingPerSec * appliedSeconds,
        proofing: rates.proofingPerSec * appliedSeconds,
        fame: rates.famePerSec * appliedSeconds,
      ),
    );
  }
}
