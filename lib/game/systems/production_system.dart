import '../../domain/models/game_state.dart';
import '../../domain/models/producers.dart';

/// Per-second production rates derived from the current state.
class ProductionRates {
  final double countingPerSec;
  final double proofingPerSec;
  final double famePerSec;

  const ProductionRates(this.countingPerSec, this.proofingPerSec, this.famePerSec);

  @override
  String toString() =>
      '${countingPerSec.toStringAsFixed(1)} C/s, ${proofingPerSec.toStringAsFixed(1)} P/s, ${famePerSec.toStringAsFixed(3)} F/s';
}

/// Computes and applies passive production (sections 13.2-13.5).
/// Pure over [GameState]; called once per frame tick from the game loop.
class ProductionSystem {
  const ProductionSystem();

  /// Scholarship cross-upgrade: +50% Counting per level.
  double countingMultiplier(GameState s) =>
      1 + 0.5 * s.levelOf('scholarship');

  /// Seminar cross-upgrade: +50% Fame per level. Applies to both paper
  /// rewards and passive citations.
  double fameMultiplier(GameState s) => 1 + 0.5 * s.levelOf('seminar');

  double _techniqueMultiplier(GameState s) {
    var m = 1.0;
    for (final id in s.techniques) {
      final t = techniqueCatalog[id];
      if (t != null) m *= t.proofingMultiplier;
    }
    return m;
  }

  ProductionRates compute(GameState s) {
    var c = 0.0;
    for (final p in countingProducers) {
      c += (s.producerLevels[p.id] ?? 0) * p.outputPerSec;
    }
    c *= countingMultiplier(s);

    // Base proofing only exists once elementary formalization is learned;
    // techniques and collaborators scale everything that produces P.
    final baseP = s.techniques.contains('elementary_formalization') ? 0.5 : 0.0;
    var producersP = 0.0;
    for (final p in proofingProducers) {
      producersP += (s.producerLevels[p.id] ?? 0) * p.outputPerSec;
    }
    final pMult =
        _techniqueMultiplier(s) * (1 + 0.5 * s.levelOf('collaborator'));
    final p = (baseP + producersP) * pMult;

    // Passive citations: 0.01 F/s per published paper this run.
    final f = 0.01 * s.papersInRun * fameMultiplier(s);

    return ProductionRates(c, p, f);
  }

  void tick(GameState s, double dt) {
    final r = compute(s);
    s.gain(r.countingPerSec * dt, r.proofingPerSec * dt, r.famePerSec * dt);
  }
}
