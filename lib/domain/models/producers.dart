import 'resources.dart';

/// Which resource an item is paid with / produces.
enum ResourceKind { counting, proofing, fame }

extension ResourceKindKey on ResourceKind {
  String get key => name;
}

/// Static definition of a repeatable producer (cost grows per unit owned).
/// Numbers are v0 balance draft (plan section 13.1-13.3).
class ProducerDef {
  final String id;
  final String name;
  final String description;
  final ResourceKind currency;
  final double baseCost;
  final double growth;
  final double outputPerSec;

  const ProducerDef({
    required this.id,
    required this.name,
    required this.description,
    required this.currency,
    required this.baseCost,
    required this.growth,
    required this.outputPerSec,
  });
}

/// Counting producers (section 13.2). Growth 1.15 for the whole family.
const List<ProducerDef> countingProducers = [
  ProducerDef(
    id: 'guided_exercises',
    name: 'Guided exercises',
    description: '+0.1 C/s',
    currency: ResourceKind.counting,
    baseCost: 15,
    growth: 1.15,
    outputPerSec: 0.1,
  ),
  ProducerDef(
    id: 'problem_sets',
    name: 'Problem sets',
    description: '+1 C/s',
    currency: ResourceKind.counting,
    baseCost: 100,
    growth: 1.15,
    outputPerSec: 1,
  ),
  ProducerDef(
    id: 'advanced_problems',
    name: 'Advanced problems',
    description: '+8 C/s',
    currency: ResourceKind.counting,
    baseCost: 1100,
    growth: 1.15,
    outputPerSec: 8,
  ),
  ProducerDef(
    id: 'research_problems',
    name: 'Research problems',
    description: '+47 C/s',
    currency: ResourceKind.counting,
    baseCost: 12000,
    growth: 1.15,
    outputPerSec: 47,
  ),
  ProducerDef(
    id: 'doctoral_seminars',
    name: 'Doctoral seminars',
    description: '+260 C/s',
    currency: ResourceKind.counting,
    baseCost: 130000,
    growth: 1.15,
    outputPerSec: 260,
  ),
  ProducerDef(
    id: 'laboratory',
    name: 'Laboratory',
    description: '+1400 C/s',
    currency: ResourceKind.counting,
    baseCost: 1400000,
    growth: 1.15,
    outputPerSec: 1400,
  ),
];

/// "Dimostrazioni in corso" — Proofing producers (section 13.3).
const List<ProducerDef> proofingProducers = [
  ProducerDef(
    id: 'simple_lemma',
    name: 'Simple lemma',
    description: '+0.5 P/s',
    currency: ResourceKind.proofing,
    baseCost: 50,
    growth: 1.15,
    outputPerSec: 0.5,
  ),
  ProducerDef(
    id: 'proposition',
    name: 'Proposition',
    description: '+3 P/s',
    currency: ResourceKind.proofing,
    baseCost: 600,
    growth: 1.15,
    outputPerSec: 3,
  ),
  ProducerDef(
    id: 'minor_theorem',
    name: 'Minor theorem',
    description: '+15 P/s',
    currency: ResourceKind.proofing,
    baseCost: 7000,
    growth: 1.15,
    outputPerSec: 15,
  ),
  ProducerDef(
    id: 'major_theorem',
    name: 'Major theorem',
    description: '+90 P/s',
    currency: ResourceKind.proofing,
    baseCost: 80000,
    growth: 1.15,
    outputPerSec: 90,
  ),
  ProducerDef(
    id: 'monograph',
    name: 'Monograph',
    description: '+500 P/s',
    currency: ResourceKind.proofing,
    baseCost: 900000,
    growth: 1.15,
    outputPerSec: 500,
  ),
  ProducerDef(
    id: 'opus_magnum',
    name: 'Opus magnum',
    description: '+3000 P/s',
    currency: ResourceKind.proofing,
    baseCost: 10000000,
    growth: 1.15,
    outputPerSec: 3000,
  ),
];

final Map<String, ProducerDef> producerCatalog = {
  for (final p in [...countingProducers, ...proofingProducers]) p.id: p,
};

/// One-time techniques paid in Counting — this is where the C -> P gate is
/// felt (section 13.3). The first one unlocks base Proofing production;
/// the rest multiply it.
class TechniqueDef {
  final String id;
  final String name;
  final String description;
  final double costCounting;
  /// True only for `elementary_formalization`: enables base 0.5 P/s.
  final bool unlocksBaseProofing;
  /// Multiplicative effect on total Proofing rate.
  final double proofingMultiplier;

  const TechniqueDef({
    required this.id,
    required this.name,
    required this.description,
    required this.costCounting,
    this.unlocksBaseProofing = false,
    this.proofingMultiplier = 1,
  });
}

const List<TechniqueDef> techniqueCatalogList = [
  TechniqueDef(
    id: 'elementary_formalization',
    name: 'Elementary formalization',
    description: 'Unlocks base Proofing production (0.5 P/s)',
    costCounting: 200,
    unlocksBaseProofing: true,
  ),
  TechniqueDef(
    id: 'standard_notation',
    name: 'Standard notation',
    description: 'Proofing x2',
    costCounting: 5000,
    proofingMultiplier: 2,
  ),
  TechniqueDef(
    id: 'induction_recursion',
    name: 'Induction & recursion',
    description: 'Proofing x2',
    costCounting: 50000,
    proofingMultiplier: 2,
  ),
  TechniqueDef(
    id: 'modern_methods',
    name: 'Modern methods',
    description: 'Proofing x3',
    costCounting: 500000,
    proofingMultiplier: 3,
  ),
  TechniqueDef(
    id: 'theory_applied_to_proofs',
    name: 'Theory applied to proofs',
    description: 'Proofing x3',
    costCounting: 5000000,
    proofingMultiplier: 3,
  ),
];

final Map<String, TechniqueDef> techniqueCatalog = {
  for (final t in techniqueCatalogList) t.id: t,
};
