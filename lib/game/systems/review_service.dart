import 'dart:math';

import '../../domain/services/balance_service.dart';

enum ReviewOutcome { accepted, revisionRequested, rejected }

/// Peer review pipeline for papers (plan sections 2 and 13.4).
/// No hard failure: rejection costs the paper but grants Metodo XP.
class ReviewService {
  ReviewService({Random? rng, BalanceService? balance})
    : _rng = rng ?? Random(),
      _balance = balance ?? const BalanceService();

  final Random _rng;
  final BalanceService _balance;

  /// Rolls the review outcome. `acceptanceBonus` shifts probability mass
  /// toward acceptance (e.g. Probability subject, phase 2+); revision and
  /// rejection probabilities rescale proportionally so they still sum to 1.
  ReviewOutcome roll({double acceptanceBonus = 0}) {
    final accept = (PaperConfig.pAccept + acceptanceBonus).clamp(0.0, 1.0);
    final rest = 1 - accept;
    final revisionShare =
        PaperConfig.pRevision / (PaperConfig.pRevision + PaperConfig.pReject);
    final x = _rng.nextDouble();
    if (x < accept) {
      return ReviewOutcome.accepted;
    }
    if (x < accept + revisionShare * rest) {
      return ReviewOutcome.revisionRequested;
    }
    return ReviewOutcome.rejected;
  }

  /// Fame granted on acceptance (section 13.4):
  /// `25 * multipliers * (1 + 0.1 * papersPublished)` with a one-time
  /// x1.25 bonus when the paper survived a revision round first.
  double paperReward(
    int papersPublishedThisRun, {
    required double fameMultiplier,
    bool afterRevision = false,
  }) {
    final base =
        PaperConfig.baseFame *
        fameMultiplier *
        (1 + PaperConfig.famePerPaperBonus * papersPublishedThisRun);
    return afterRevision ? base * PaperConfig.revisionFameMultiplier : base;
  }

  /// Cost of rewriting after "revision requested": half the original cost.
  double revisionCost(int papersStartedThisRun) =>
      _balance.paperCost(papersStartedThisRun) / 2;

  /// Metodo XP gained from a rejected paper.
  static const int methodXpOnRejection = 2;
}
