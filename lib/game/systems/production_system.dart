import '../../domain/models/game_state.dart';
import '../../domain/models/producers.dart';
import '../../domain/services/subject_service.dart';
import 'friction_system.dart';

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

  ProductionRates compute(GameState s, [SubjectModifiers? mods]) {
    final m = mods ?? const SubjectModifiers();

    var c = 0.0;
    for (final p in countingProducers) {
      c += (s.producerLevels[p.id] ?? 0) * p.outputPerSec;
    }
    c *= countingMultiplier(s);
    c = c * m.countingMultiplier + m.countingRateAdd;

    // Base proofing only exists once elementary formalization is learned;
    // techniques and collaborators scale everything that produces P.
    final baseP = s.techniques.contains('elementary_formalization') ? 0.5 : 0.0;
    var producersP = 0.0;
    for (final p in proofingProducers) {
      producersP += (s.producerLevels[p.id] ?? 0) * p.outputPerSec;
    }
    final pMult =
        _techniqueMultiplier(s) * (1 + 0.5 * s.levelOf('collaborator'));
    var p = (baseP + producersP) * pMult;
    p = p * m.proofingMultiplier + m.proofingRateAdd;

    // Completed subjects can compound output while actively playing
    // (+0.5%/min since session start, capped at x2).
    if (m.sessionCompounding) {
      final minutes = DateTime.now().difference(s.sessionStartedAt).inMinutes.toDouble();
      final k = (1 + 0.005 * minutes).clamp(1.0, 2.0);
      c *= k;
      p *= k;
    }

    // Category Theory's grand unification touches every gain channel.
    c *= m.globalResourceMult;
    p *= m.globalResourceMult;

    // Proven conjectures grant permanent boosts to their reward channels
    // (section 4).
    c *= s.conjectureCountingMult * s.conjectureGlobalMult;
    p *= s.conjectureProofingMult * s.conjectureGlobalMult;

    // Burnout halves every channel while active (section 13.10).
    final burnMult = const FrictionSystem().productionMultiplier(s);
    c *= burnMult;
    p *= burnMult;

    // Passive citations: 0.01 F/s per published paper this run.
    final f = 0.01 *
        s.papersInRun *
        fameMultiplier(s) *
        m.globalResourceMult *
        s.conjectureGlobalMult *
        burnMult;

    return ProductionRates(c, p, f);
  }

  void tick(GameState s, double dt, [SubjectModifiers? mods]) {
    final r = compute(s, mods);
    s.gain(r.countingPerSec * dt, r.proofingPerSec * dt, r.famePerSec * dt);
  }
}
