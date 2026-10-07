import '../../domain/models/game_state.dart';
import '../../domain/models/producers.dart';
import '../../domain/services/balance_service.dart';
import '../../domain/services/subject_service.dart';
import 'apprentice_service.dart';
import 'challenge_service.dart';
import 'friction_system.dart';
import 'prestige_service.dart';

/// Per-second production rates derived from the current state.
class ProductionRates {
  final double countingPerSec;
  final double proofingPerSec;
  final double famePerSec;

  const ProductionRates(
    this.countingPerSec,
    this.proofingPerSec,
    this.famePerSec,
  );

  @override
  String toString() =>
      '${countingPerSec.toStringAsFixed(1)} C/s, ${proofingPerSec.toStringAsFixed(1)} P/s, ${famePerSec.toStringAsFixed(3)} F/s';
}

/// Computes and applies passive production (sections 13.2-13.5).
/// Pure over [GameState]; called once per frame tick from the game loop.
class ProductionSystem {
  const ProductionSystem();

  /// Scholarship cross-upgrade: +50% Counting per level.
  double countingMultiplier(GameState s) => 1 + 0.5 * s.levelOf('scholarship');

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

  /// Effective Counting gained by one manual exercise solve (§13.2):
  /// study tools × subject click & global mults × conjecture counting/global
  /// boosts × completed-challenge boost × lifetime Legacy bonus. Single
  /// source of truth shared by `solveExercise()` and the Solve button.
  double clickPower(GameState s, [SubjectModifiers? mods]) {
    final m = mods ?? const SubjectService().modifiers(s);
    return const BalanceService().clickPower(s.levelOf('study_tools')) *
        m.clickMultiplier *
        m.globalResourceMult *
        s.conjectureCountingMult *
        s.conjectureGlobalMult *
        s.challengeGlobalMult *
        const PrestigeService().productionMultiplier(s);
  }

  ProductionRates compute(GameState s, [SubjectModifiers? mods]) {
    final m = mods ?? const SubjectModifiers();

    var c = 0.0;
    for (final p in countingProducers) {
      c += (s.producerLevels[p.id] ?? 0) * p.outputPerSec;
    }
    // Apprentices: narrated automation adding flat Counting (section 5).
    c += const ApprenticeService().outputOf(s.career.apprentices);
    // Constructivist Run: the lab runs lean (section 7).
    c *= const ChallengeService().passiveProductionFactor(s);
    c *= countingMultiplier(s);
    c = c * m.countingMultiplier + m.countingRateAdd;
    // Gauss: Counting ×2 (prestige perk, section 13.9).
    if (const PrestigeService().hasMathematician(s, 'gauss')) c *= 2;

    // Base proofing only exists once elementary formalization is learned;
    // techniques and collaborators scale everything that produces P.
    final baseP = s.techniques.contains('elementary_formalization') ? 0.5 : 0.0;
    var producersP = 0.0;
    for (final p in proofingProducers) {
      producersP += (s.producerLevels[p.id] ?? 0) * p.outputPerSec;
    }
    final pMult =
        _techniqueMultiplier(s) * (1 + 0.5 * s.levelOf('collaborator'));
    var p =
        (baseP +
            producersP * const ChallengeService().passiveProductionFactor(s)) *
        pMult;
    p = p * m.proofingMultiplier + m.proofingRateAdd;
    // Noether: Proofing ×2 while focused on algebraic branches (§13.9).
    if (const PrestigeService().hasMathematician(s, 'noether') &&
        algebraicBranchIds.contains(s.activeSubjectId)) {
      p *= 2;
    }

    // Completed subjects can compound output while actively playing
    // (+0.5%/min since session start, capped at x2).
    if (m.sessionCompounding) {
      final minutes = DateTime.now()
          .difference(s.sessionStartedAt)
          .inMinutes
          .toDouble();
      final k = (1 + 0.005 * minutes).clamp(1.0, 2.0);
      c *= k;
      p *= k;
    }

    // Category Theory's grand unification touches every gain channel.
    c *= m.globalResourceMult;
    p *= m.globalResourceMult;

    // Proven conjectures and completed challenges grant permanent boosts
    // to their reward channels (sections 4, 7).
    c *=
        s.conjectureCountingMult *
        s.conjectureGlobalMult *
        s.challengeGlobalMult;
    p *=
        s.conjectureProofingMult *
        s.conjectureGlobalMult *
        s.challengeGlobalMult;

    // Lifetime Legacy: every point permanently adds +2% to all production.
    final legacyMult = const PrestigeService().productionMultiplier(s);
    c *= legacyMult;
    p *= legacyMult;

    // Burnout halves every channel while active (section 13.10).
    final burnMult = const FrictionSystem().productionMultiplier(s);
    c *= burnMult;
    p *= burnMult;

    // Passive citations: 0.01 F/s per paper published this run (§13.4).
    var f =
        0.01 *
        s.papersPublishedInRun *
        fameMultiplier(s) *
        m.globalResourceMult *
        s.conjectureGlobalMult *
        s.challengeGlobalMult *
        burnMult;
    // Euler: citation Fame ×2 (prestige perk, section 13.9).
    if (const PrestigeService().hasMathematician(s, 'euler')) f *= 2;
    f *= legacyMult;

    return ProductionRates(c, p, f);
  }

  void tick(GameState s, double dt, [SubjectModifiers? mods]) {
    final r = compute(s, mods);
    s.gain(r.countingPerSec * dt, r.proofingPerSec * dt, r.famePerSec * dt);
  }
}
