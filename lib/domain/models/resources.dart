/// The three core resources of the C -> P -> F pipeline (plan section 2).
library;

import 'producers.dart';

/// [Resources] holds the *current* balances. Lifetime (cumulative) gains are
/// tracked separately in [GameState.lifetime] because career gates use them
/// and they must not reset inside a prestige cycle (section 13.8).
class Resources {
  double counting = 0;
  double proofing = 0;
  double fame = 0;

  Resources({this.counting = 0, this.proofing = 0, this.fame = 0});

  double get total => counting + proofing + fame;

  void gain(
    double countingGain, [
    double proofingGain = 0,
    double fameGain = 0,
  ]) {
    counting += countingGain;
    proofing += proofingGain;
    fame += fameGain;
  }

  bool canAfford(
    double countingCost, [
    double proofingCost = 0,
    double fameCost = 0,
  ]) =>
      counting >= countingCost && proofing >= proofingCost && fame >= fameCost;

  /// Deducts the given amounts. Returns false without spending if unaffordable.
  bool spend(
    double countingCost, [
    double proofingCost = 0,
    double fameCost = 0,
  ]) {
    if (!canAfford(countingCost, proofingCost, fameCost)) return false;
    counting -= countingCost;
    proofing -= proofingCost;
    fame -= fameCost;
    return true;
  }

  Resources copy() =>
      Resources(counting: counting, proofing: proofing, fame: fame);

  @override
  String toString() => 'C:$counting P:$proofing F:$fame';
}

/// Affordability check for a single-amount cost denominated in [kind].
extension ResourcesAffordOfKind on Resources {
  bool canAffordOf(ResourceKind kind, double amount) => switch (kind) {
    ResourceKind.counting => canAfford(amount),
    ResourceKind.proofing => canAfford(0, amount),
    ResourceKind.fame => canAfford(0, 0, amount),
  };
}
