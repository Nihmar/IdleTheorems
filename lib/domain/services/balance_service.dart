import 'dart:math';

import '../models/producers.dart';
import '../models/upgrade.dart';

/// Constants for the paper pipeline (plan section 13.4).
abstract class PaperConfig {
  static const double baseCost = 100; // Proofing
  static const double costGrowth = 1.05;
  static const double writeDurationSeconds = 60;
  static const double baseFame = 25;
  static const double famePerPaperBonus = 0.1; // Fame scales with (1 + 0.1 * papers)
  static const double revisionFameMultiplier = 1.25;
  // Peer review base probabilities.
  static const double pAccept = 0.60;
  static const double pRevision = 0.30;
  static const double pReject = 0.10;
}

/// All exponential cost curves live here (plan section 13.1):
/// `cost(n) = base * growth^n`. Keep balance tuning in this file so the
/// v0 draft numbers stay easy to adjust during playtest.
class BalanceService {
  const BalanceService();

  double producerCost(ProducerDef def, int owned) =>
      def.baseCost * pow(def.growth, owned);

  double upgradeCost(UpgradeDef def, int level) =>
      def.baseCost * pow(def.growth, level);

  /// Cost of the next paper given how many were started this run.
  double paperCost(int papersStartedThisRun) =>
      PaperConfig.baseCost * pow(PaperConfig.costGrowth, papersStartedThisRun);

  /// Click power: 1 C per click, +100% per Study Tools level (section 13.2).
  double clickPower(int studyToolsLevel) => 1.0 * (1 + studyToolsLevel * 1.0);

  /// Metodo XP needed to go from [level] to level+1.
  /// v0 choice: linear ramp (the doc leaves the curve open).
  int methodXpToNextLevel(int level) => 50 * level;

  /// Offline progression defaults (section 13.10). Measure theory doubles cap.
  static const Duration offlineCapDefault = Duration(hours: 4);
  static const double offlineEfficiency = 0.5;
  static const Duration offlineCapMax = Duration(hours: 24);
}
