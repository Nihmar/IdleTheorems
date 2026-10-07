import 'dart:math';

import '../../domain/models/game_state.dart';
import '../../domain/models/save_data.dart';
import '../../utils/number_format.dart';
import 'challenge_service.dart';

/// Soft-failure frictions (plan section 2): retractions and burnout.
/// Nothing here is a hard failure — only strategic friction that creates
/// decisions. Tuning constants are v0 drafts pending playtest.
class FrictionSystem {
  const FrictionSystem();

  // ------------------------------------------------------------ retractions
  static const double retractionChance = 0.05;
  static const Duration retractionDelay = Duration(minutes: 10);
  static const double retractionFameLossFraction = 0.20;

  /// Consolation Metodo XP when an error surfaces (learning, not punishment).
  static const int retractionMethodXp = 5;

  // ------------------------------------------------------------- burnout
  static const int overloadPaperThreshold = 5;

  /// Full stress bar in ~15 minutes of sustained overload.
  static const double stressPerSecondOverloaded = 1 / 900;

  /// Stress fades over ~30 calm minutes.
  static const double stressDecayPerSecond = 1 / 1800;
  static const Duration burnoutDuration = Duration(hours: 1);

  /// Residual stress left behind once a burnout episode ends.
  static const double postBurnoutStress = 0.5;

  /// Sabbatical price: fraction of current Fame (section 13.10).
  static const double sabbaticalCostFraction = 0.10;

  bool isBurnedOut(GameState s, [DateTime? now]) {
    final end = s.burnedOutUntil;
    if (end == null) return false;
    final t = now ?? DateTime.now();
    return !t.isAfter(end); // active while now <= end
  }

  /// Production penalty while burned out (-50% on every channel).
  double productionMultiplier(GameState s, [DateTime? now]) =>
      isBurnedOut(s, now) ? 0.5 : 1.0;

  /// Accepted papers have a small chance of hiding an error that will
  /// surface later as a retraction.
  void maybeScheduleRetraction(GameState s, Random rng, [DateTime? now]) {
    if (rng.nextDouble() < retractionChance) {
      s.scheduledRetractions.add(
        ScheduledRetraction((now ?? DateTime.now()).add(retractionDelay)),
      );
    }
  }

  /// Advances stress dynamics and fires due retractions. Returns short
  /// player-facing notices for events that happened this tick.
  List<String> tick(GameState s, double dt, [DateTime? now]) {
    final notices = <String>[];
    final t = now ?? DateTime.now();

    for (final r in List.of(s.scheduledRetractions)) {
      if (!t.isBefore(r.dueAt)) {
        final loss = s.resources.fame * retractionFameLossFraction;
        s.resources.fame -= loss;
        s.stats.retractions++;
        s.scheduledRetractions.remove(r);
        notices.add(
          'A reviewer found an old error: -${formatNumber(loss)} Fame',
        );
      }
    }

    if (s.activePapers.length >= overloadPaperThreshold) {
      // Encrypted Run: secrecy makes overload bite twice as hard (§7).
      final stressRate =
          stressPerSecondOverloaded * const ChallengeService().stressFactor(s);
      s.stress = (s.stress + stressRate * dt).clamp(0.0, 1.0);
      if ((s.stress >= 1.0 - 1e-9) && !isBurnedOut(s, t)) {
        s.burnedOutUntil = t.add(burnoutDuration);
        s.stress = postBurnoutStress;
        notices.add(
          'Burnout! Production halved for ${burnoutDuration.inHours} h',
        );
      }
    } else {
      s.stress = (s.stress - stressDecayPerSecond * dt).clamp(0.0, 1.0);
    }
    return notices;
  }

  /// Sabbatical: pay 10% of current Fame to clear stress instantly.
  bool takeSabbatical(GameState s) {
    final cost = s.resources.fame * sabbaticalCostFraction;
    if (cost <= 0 || !s.resources.spend(0, 0, cost)) return false;
    s.stress = 0;
    s.burnedOutUntil = null;
    return true;
  }
}
