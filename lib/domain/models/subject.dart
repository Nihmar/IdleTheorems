/// Static definition of a math subject node in the tech tree
/// (plan section 3). Subjects form a DAG: a node unlocks only when all of
/// its prerequisites are COMPLETED. Mastering a subject requires
/// publishing enough theorems into it ([masteryNeeded]).
class SubjectDef {
  final String id;
  final String name;
  final int level; // 0..4
  final List<String> prereqs;
  final SubjectEffects effects;
  final String effectText; // short player-facing summary

  const SubjectDef({
    required this.id,
    required this.name,
    required this.level,
    required this.prereqs,
    required this.effects,
    required this.effectText,
  });
}

/// Numeric levers a completed subject applies to the game. All values are
/// neutral by default so unused effects stay invisible. Effects of several
/// completed subjects combine multiplicatively (multipliers) or additively
/// (flat rates / probability bonuses).
class SubjectEffects {
  /// x on click power.
  final double clickMultiplier;

  /// Flat Counting/s added to total output.
  final double countingRateAdd;

  /// Flat Proofing/s added to total output.
  final double proofingRateAdd;

  /// x on total Counting rate.
  final double countingMultiplier;

  /// x on total Proofing rate.
  final double proofingMultiplier;

  /// x on Fame granted by accepted papers.
  final double famePerPaperMult;

  /// Chance (0..1) that an accepted paper pays a burst instead.
  final double fameBurstChance;

  /// Multiplier applied during a burst.
  final double fameBurstMult;

  /// x on paper session cost (< 1 = discount).
  final double paperCostFactor;

  /// x on upgrade costs (< 1 = discount).
  final double upgradeCostFactor;

  /// Additive shift toward peer-review acceptance.
  final double acceptanceBonus;

  /// Extra concurrent paper slots.
  final int extraPapers;

  /// x on the offline progression cap duration.
  final double offlineCapMult;

  /// x on Legacy gained at prestige.
  final double legacyGainMult;

  /// Production compounds while playing (+0.5%/min, capped at x2).
  final bool sessionCompounding;

  /// x on every resource gain (rates and clicks).
  final double globalResourceMult;

  /// Counting multiplier grows by this much per total theorem mastered.
  final double countingPerTheorem;

  const SubjectEffects({
    this.clickMultiplier = 1,
    this.countingRateAdd = 0,
    this.proofingRateAdd = 0,
    this.countingMultiplier = 1,
    this.proofingMultiplier = 1,
    this.famePerPaperMult = 1,
    this.fameBurstChance = 0,
    this.fameBurstMult = 1,
    this.paperCostFactor = 1,
    this.upgradeCostFactor = 1,
    this.acceptanceBonus = 0,
    this.extraPapers = 0,
    this.offlineCapMult = 1,
    this.legacyGainMult = 1,
    this.sessionCompounding = false,
    this.globalResourceMult = 1,
    this.countingPerTheorem = 0,
  });
}

/// Theorems required to master a subject, by tree level (v0 draft):
/// LV0 needs 4 for pacing, then 8/12/16/20 as the doc specifies.
int masteryNeeded(int level) => switch (level) {
  0 => 4,
  1 => 8,
  2 => 12,
  _ => level == 3 ? 16 : 20,
};

/// Full subject catalog — the table in plan section 3 is the source of
/// truth. Effects that depend on systems landing later (trends, intuition
/// events, challenge runs, endgame problems) carry their text but no numeric
/// lever yet.
const Map<String, SubjectDef> subjectCatalog = {
  'logic_sets': SubjectDef(
    id: 'logic_sets',
    name: 'Logic & Sets',
    level: 0,
    prereqs: [],
    effects: SubjectEffects(clickMultiplier: 1.10),
    effectText: '+10% Counting from clicks',
  ),
  'discrete_algebra': SubjectDef(
    id: 'discrete_algebra',
    name: 'Discrete Algebra',
    level: 1,
    prereqs: ['logic_sets'],
    effects: SubjectEffects(countingRateAdd: 0.5),
    effectText: '+0.5 C/s base output',
  ),
  'analysis': SubjectDef(
    id: 'analysis',
    name: 'Analysis',
    level: 1,
    prereqs: ['logic_sets'],
    effects: SubjectEffects(proofingRateAdd: 0.2),
    effectText: '+0.2 P/s rigor',
  ),
  'geometry': SubjectDef(
    id: 'geometry',
    name: 'Geometry',
    level: 1,
    prereqs: ['logic_sets'],
    effects: SubjectEffects(paperCostFactor: 0.90),
    effectText: '-10% paper session cost',
  ),
  'probability': SubjectDef(
    id: 'probability',
    name: 'Probability',
    level: 1,
    prereqs: ['logic_sets'],
    effects: SubjectEffects(acceptanceBonus: 0.10),
    effectText: '+10% peer review acceptance',
  ),
  'number_theory': SubjectDef(
    id: 'number_theory',
    name: 'Number Theory',
    level: 2,
    prereqs: ['discrete_algebra'],
    effects: SubjectEffects(countingPerTheorem: 0.02),
    effectText: '+2% Counting per theorem mastered (all subjects)',
  ),
  'abstract_algebra': SubjectDef(
    id: 'abstract_algebra',
    name: 'Abstract Algebra',
    level: 2,
    prereqs: ['discrete_algebra'],
    effects: SubjectEffects(proofingRateAdd: 1.0),
    effectText: '+1 P/s — core of advanced fields',
  ),
  'multivariable_calculus': SubjectDef(
    id: 'multivariable_calculus',
    name: 'Multivariable Calculus',
    level: 2,
    prereqs: ['analysis', 'geometry'],
    effects: SubjectEffects(famePerPaperMult: 1.25),
    effectText: '+25% Fame per paper',
  ),
  'topology': SubjectDef(
    id: 'topology',
    name: 'Topology',
    level: 2,
    prereqs: ['analysis', 'geometry'],
    effects: SubjectEffects(extraPapers: 1),
    effectText: '+1 concurrent paper slot',
  ),
  'statistics': SubjectDef(
    id: 'statistics',
    name: 'Statistics',
    level: 2,
    prereqs: ['probability', 'discrete_algebra'],
    effects: SubjectEffects(),
    effectText: 'Reveals the next research trend early (coming soon)',
  ),
  'stochastic_processes': SubjectDef(
    id: 'stochastic_processes',
    name: 'Stochastic Processes',
    level: 2,
    prereqs: ['probability', 'analysis'],
    effects: SubjectEffects(),
    effectText: 'More intuition events during proofs (coming soon)',
  ),
  'measure_theory': SubjectDef(
    id: 'measure_theory',
    name: 'Measure Theory',
    level: 2,
    prereqs: ['analysis', 'logic_sets'],
    effects: SubjectEffects(offlineCapMult: 2),
    effectText: 'Offline progression cap x2',
  ),
  'information_theory': SubjectDef(
    id: 'information_theory',
    name: 'Information Theory',
    level: 2,
    prereqs: ['probability', 'discrete_algebra'],
    effects: SubjectEffects(upgradeCostFactor: 0.90),
    effectText: '-10% upgrade costs (compression)',
  ),
  'dynamical_systems': SubjectDef(
    id: 'dynamical_systems',
    name: 'Dynamical Systems',
    level: 2,
    prereqs: ['analysis', 'geometry'],
    effects: SubjectEffects(sessionCompounding: true),
    effectText: 'Production compounds while you play (+0.5%/min, max x2)',
  ),
  'complex_analysis': SubjectDef(
    id: 'complex_analysis',
    name: 'Complex Analysis',
    level: 3,
    prereqs: ['abstract_algebra', 'analysis'],
    effects: SubjectEffects(famePerPaperMult: 2),
    effectText: 'x2 Fame from analytic papers',
  ),
  'algebraic_geometry': SubjectDef(
    id: 'algebraic_geometry',
    name: 'Algebraic Geometry',
    level: 3,
    prereqs: ['abstract_algebra', 'topology'],
    effects: SubjectEffects(countingMultiplier: 1.25, proofingMultiplier: 1.25),
    effectText: 'Rare double effect: +25% Counting AND Proofing',
  ),
  'algebraic_topology': SubjectDef(
    id: 'algebraic_topology',
    name: 'Algebraic Topology',
    level: 3,
    prereqs: ['topology', 'abstract_algebra'],
    effects: SubjectEffects(legacyGainMult: 1.25),
    effectText: '+25% Legacy gained at prestige',
  ),
  'analytic_number_theory': SubjectDef(
    id: 'analytic_number_theory',
    name: 'Analytic Number Theory',
    level: 3,
    prereqs: ['number_theory', 'analysis'],
    effects: SubjectEffects(fameBurstChance: 0.15, fameBurstMult: 5),
    effectText: '15% chance an accepted paper pays x5 Fame',
  ),
  'cryptography': SubjectDef(
    id: 'cryptography',
    name: 'Cryptography',
    level: 3,
    prereqs: ['number_theory', 'probability'],
    effects: SubjectEffects(legacyGainMult: 1.10),
    effectText:
        'Unlocks encrypted challenge runs; +10% Legacy gained at prestige',
  ),
  'functional_analysis': SubjectDef(
    id: 'functional_analysis',
    name: 'Functional Analysis',
    level: 3,
    prereqs: ['analysis', 'topology'],
    effects: SubjectEffects(proofingMultiplier: 2),
    effectText: 'x2 total Proofing rate',
  ),
  'pde': SubjectDef(
    id: 'pde',
    name: 'Partial Differential Equations',
    level: 4,
    prereqs: ['multivariable_calculus', 'functional_analysis'],
    effects: SubjectEffects(famePerPaperMult: 2),
    effectText: 'Strong Fame engine; opens Navier-Stokes endgame',
  ),
  'computational_complexity': SubjectDef(
    id: 'computational_complexity',
    name: 'Computational Complexity',
    level: 4,
    prereqs: ['information_theory', 'discrete_algebra'],
    effects: SubjectEffects(upgradeCostFactor: 0.85),
    effectText: '-15% upgrade costs; opens P vs NP endgame',
  ),
  'category_theory': SubjectDef(
    id: 'category_theory',
    name: 'Category Theory',
    level: 4,
    prereqs: ['abstract_algebra', 'algebraic_topology'],
    effects: SubjectEffects(globalResourceMult: 1.05),
    effectText: 'Grand unification: +5% to all resources',
  ),
};

/// Subjects ordered by tree level for UI grouping and iteration.
List<SubjectDef> subjectsByLevel() {
  final list = subjectCatalog.values.toList()
    ..sort((a, b) => a.level.compareTo(b.level));
  return list;
}
