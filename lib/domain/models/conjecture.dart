/// Conjecture lifecycle state (plan sections 4 and 13.7). Static balancing
/// data lives in [ConjectureDef]/[conjectureCatalog]; only the dynamic
/// state below is persisted in the save file.
enum ConjectureStatus { available, active, proven, refuted }

extension ConjectureStatusKey on ConjectureStatus {
  String get key => name;
}

/// Kind of permanent reward granted when a conjecture is PROVEN.
enum RewardType { productionMultiplier, fameBurst, legacyBonus, cosmeticTitle }

class ConjectureReward {
  final RewardType type;

  /// Multiplier delta (0.25 = +25%) for production rewards; flat Fame for
  /// bursts; flat Legacy points for legacy bonuses.
  final double value;

  /// 'counting' | 'proofing' | 'all' — only meaningful for multipliers.
  final String target;

  /// Title name — only meaningful for [RewardType.cosmeticTitle].
  final String title;

  const ConjectureReward({
    required this.type,
    required this.value,
    this.target = '',
    this.title = '',
  });
}

class ConjectureState {
  final String defId;
  ConjectureStatus status;
  double progress; // 0..100
  DateTime lastWorkAt;
  int attempts;
  DateTime? resolvedAt;

  /// When a refuted conjecture may be worked again after its cooldown.
  DateTime? readyAt;

  ConjectureState({
    required this.defId,
    this.status = ConjectureStatus.available,
    this.progress = 0,
    DateTime? lastWorkAt,
    this.attempts = 0,
    this.resolvedAt,
    this.readyAt,
  }) : lastWorkAt = lastWorkAt ?? DateTime.now();

  factory ConjectureState.fromJson(Map<String, dynamic> json) =>
      ConjectureState(
        defId: json['def_id'] as String,
        status: ConjectureStatus.values.byName(
          json['status'] as String? ?? ConjectureStatus.available.name,
        ),
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        lastWorkAt: DateTime.fromMillisecondsSinceEpoch(
          json['last_work_at_ms'] as int? ?? 0,
        ),
        attempts: json['attempts'] as int? ?? 0,
        resolvedAt: json['resolved_at_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                json['resolved_at_ms'] as int,
              ),
        readyAt: json['ready_at_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['ready_at_ms'] as int),
      );

  Map<String, dynamic> toJson() => {
    'def_id': defId,
    'status': status.key,
    'progress': progress,
    'last_work_at_ms': lastWorkAt.millisecondsSinceEpoch,
    'attempts': attempts,
    'resolved_at_ms': resolvedAt?.millisecondsSinceEpoch,
    'ready_at_ms': readyAt?.millisecondsSinceEpoch,
  };
}

/// One-time cost to formulate (pay once, then work sessions drive it).
class ConjectureCosts {
  final double counting;
  final double proofing;
  final double fame;

  const ConjectureCosts(this.counting, this.proofing, this.fame);
}

/// Static definition of a conjecture / open problem (plan sections 4, 7,
/// 13.7). Endgame problems reuse the same engine with bigger numbers.
class ConjectureDef {
  final String id;
  final String name;

  /// Branches that must be COMPLETED before formulation.
  final List<String> subjects;
  final int tier; // 1..5
  final ConjectureCosts formulation;
  final ConjectureCosts workPerSession;

  /// Base progress gained per session, in percent.
  final double progressPerWork;
  final List<ConjectureReward> successRewards;
  final Duration retryCooldown;
  final bool isEndgame;

  const ConjectureDef({
    required this.id,
    required this.name,
    required this.subjects,
    required this.tier,
    required this.formulation,
    required this.workPerSession,
    required this.progressPerWork,
    required this.successRewards,
    required this.retryCooldown,
    this.isEndgame = false,
  });

  /// Metodo XP granted on failure: 10 x tier (section 13.7).
  int get failureMethodXp => 10 * tier;

  /// Player-facing one-line summary of the success reward(s).
  String get rewardSummary {
    return successRewards
        .map((r) {
          switch (r.type) {
            case RewardType.productionMultiplier:
              final what = r.target == 'all' ? 'all resources' : r.target;
              return '+${(r.value * 100).round()}% $what';
            case RewardType.fameBurst:
              return '+${r.value.round()} Fame burst';
            case RewardType.legacyBonus:
              return '+${r.value.round()} Legacy';
            case RewardType.cosmeticTitle:
              return '"${r.title}" title';
          }
        })
        .join(', ');
  }
}

/// Full conjecture catalog (v0 draft from sections 4, 7 and 13.7). Tier
/// costs follow the §13.7 table; endgame problems reuse the engine with
/// bigger numbers and unique rewards.
const Map<String, ConjectureDef> conjectureCatalog = {
  // ------------------------------------------------------- tiers 1-2
  'double_counting_lemmas': ConjectureDef(
    id: 'double_counting_lemmas',
    name: 'Double Counting Lemmas',
    subjects: ['discrete_algebra'],
    tier: 1,
    formulation: ConjectureCosts(0, 500, 0),
    workPerSession: ConjectureCosts(200, 100, 0),
    progressPerWork: 12.5,
    successRewards: [
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 0.25,
        target: 'counting',
      ),
    ],
    retryCooldown: Duration(minutes: 30),
  ),
  'integral_test_bounds': ConjectureDef(
    id: 'integral_test_bounds',
    name: 'Integral Test Bounds',
    subjects: ['analysis'],
    tier: 1,
    formulation: ConjectureCosts(0, 500, 0),
    workPerSession: ConjectureCosts(200, 100, 0),
    progressPerWork: 12.5,
    successRewards: [
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 0.25,
        target: 'proofing',
      ),
    ],
    retryCooldown: Duration(minutes: 30),
  ),
  'euclid_numbers': ConjectureDef(
    id: 'euclid_numbers',
    name: 'Euclid Numbers',
    subjects: ['number_theory'],
    tier: 2,
    formulation: ConjectureCosts(0, 5000, 0),
    workPerSession: ConjectureCosts(0, 800, 0),
    progressPerWork: 10,
    successRewards: [
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 0.5,
        target: 'counting',
      ),
    ],
    retryCooldown: Duration(hours: 2),
  ),
  'compactness_sequences': ConjectureDef(
    id: 'compactness_sequences',
    name: 'Compactness of Sequences',
    subjects: ['topology'],
    tier: 2,
    formulation: ConjectureCosts(0, 5000, 0),
    workPerSession: ConjectureCosts(0, 800, 0),
    progressPerWork: 10,
    successRewards: [
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 0.5,
        target: 'proofing',
      ),
    ],
    retryCooldown: Duration(hours: 2),
  ),
  'concentration_inequalities': ConjectureDef(
    id: 'concentration_inequalities',
    name: 'Concentration Inequalities',
    subjects: ['statistics'],
    tier: 2,
    formulation: ConjectureCosts(0, 5000, 0),
    workPerSession: ConjectureCosts(0, 800, 0),
    progressPerWork: 10,
    successRewards: [ConjectureReward(type: RewardType.fameBurst, value: 5000)],
    retryCooldown: Duration(hours: 2),
  ),
  // -------------------------------------------------------- tier 3
  'spectral_gap_estimates': ConjectureDef(
    id: 'spectral_gap_estimates',
    name: 'Spectral Gap Estimates',
    subjects: ['functional_analysis'],
    tier: 3,
    formulation: ConjectureCosts(0, 50000, 0),
    workPerSession: ConjectureCosts(500, 6000, 0),
    progressPerWork: 8.3,
    successRewards: [
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 1.0,
        target: 'proofing',
      ),
    ],
    retryCooldown: Duration(hours: 12),
  ),
  'elliptic_curve_heights': ConjectureDef(
    id: 'elliptic_curve_heights',
    name: 'Elliptic Curve Heights',
    subjects: ['algebraic_geometry'],
    tier: 3,
    formulation: ConjectureCosts(0, 50000, 0),
    workPerSession: ConjectureCosts(500, 6000, 0),
    progressPerWork: 8.3,
    successRewards: [
      ConjectureReward(type: RewardType.fameBurst, value: 10000),
    ],
    retryCooldown: Duration(hours: 12),
  ),
  // -------------------------------------------------------- tier 4
  'zero_free_strip': ConjectureDef(
    id: 'zero_free_strip',
    name: 'A Wider Zero-Free Strip',
    subjects: ['analytic_number_theory'],
    tier: 4,
    formulation: ConjectureCosts(0, 500000, 0),
    workPerSession: ConjectureCosts(0, 50000, 1000),
    progressPerWork: 6.25,
    successRewards: [
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 2.0,
        target: 'counting',
      ),
    ],
    retryCooldown: Duration(hours: 48),
  ),
  'modular_symmetries': ConjectureDef(
    id: 'modular_symmetries',
    name: 'Hidden Modular Symmetries',
    subjects: ['complex_analysis'],
    tier: 4,
    formulation: ConjectureCosts(0, 500000, 0),
    workPerSession: ConjectureCosts(0, 50000, 1000),
    progressPerWork: 6.25,
    successRewards: [
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 2.0,
        target: 'proofing',
      ),
    ],
    retryCooldown: Duration(hours: 48),
  ),
  'collatz': ConjectureDef(
    id: 'collatz',
    name: 'The Collatz Conjecture',
    subjects: ['number_theory'],
    tier: 4,
    formulation: ConjectureCosts(0, 500000, 0),
    workPerSession: ConjectureCosts(0, 50000, 1000),
    progressPerWork: 6.25,
    successRewards: [
      ConjectureReward(type: RewardType.fameBurst, value: 10000),
      ConjectureReward(type: RewardType.legacyBonus, value: 100),
      ConjectureReward(
        type: RewardType.cosmeticTitle,
        value: 0,
        title: 'Taming 3n+1',
      ),
    ],
    retryCooldown: Duration(hours: 48),
  ),
  // ------------------------------------------------- endgame (tier 5)
  'goldbach': ConjectureDef(
    id: 'goldbach',
    name: 'Goldbach\u2019s Conjecture',
    subjects: ['number_theory'],
    tier: 5,
    formulation: ConjectureCosts(0, 5e6, 1e4),
    workPerSession: ConjectureCosts(0, 250000, 500),
    progressPerWork: 2,
    successRewards: [
      ConjectureReward(type: RewardType.legacyBonus, value: 500),
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 0.5,
        target: 'all',
      ),
      ConjectureReward(
        type: RewardType.cosmeticTitle,
        value: 0,
        title: 'Prime Summarizer',
      ),
    ],
    retryCooldown: Duration(hours: 72),
    isEndgame: true,
  ),
  'riemann_hypothesis': ConjectureDef(
    id: 'riemann_hypothesis',
    name: 'Riemann Hypothesis',
    subjects: ['analytic_number_theory'],
    tier: 5,
    formulation: ConjectureCosts(0, 5e6, 1e4),
    workPerSession: ConjectureCosts(0, 250000, 500),
    progressPerWork: 2,
    successRewards: [
      ConjectureReward(type: RewardType.legacyBonus, value: 1000),
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 1.0,
        target: 'all',
      ),
      ConjectureReward(
        type: RewardType.cosmeticTitle,
        value: 0,
        title: 'Zero Hunter',
      ),
    ],
    retryCooldown: Duration(hours: 72),
    isEndgame: true,
  ),
  'p_vs_np': ConjectureDef(
    id: 'p_vs_np',
    name: 'P versus NP',
    subjects: ['computational_complexity'],
    tier: 5,
    formulation: ConjectureCosts(0, 5e6, 1e4),
    workPerSession: ConjectureCosts(0, 250000, 500),
    progressPerWork: 2,
    successRewards: [
      ConjectureReward(type: RewardType.legacyBonus, value: 1000),
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 1.0,
        target: 'counting',
      ),
      ConjectureReward(
        type: RewardType.cosmeticTitle,
        value: 0,
        title: 'Complexity Breaker',
      ),
    ],
    retryCooldown: Duration(hours: 72),
    isEndgame: true,
  ),
  'navier_stokes': ConjectureDef(
    id: 'navier_stokes',
    name: 'Navier\u2013Stokes Existence & Smoothness',
    subjects: ['pde'],
    tier: 5,
    formulation: ConjectureCosts(0, 5e6, 1e4),
    workPerSession: ConjectureCosts(0, 250000, 500),
    progressPerWork: 2,
    successRewards: [
      ConjectureReward(type: RewardType.legacyBonus, value: 1000),
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 1.0,
        target: 'proofing',
      ),
      ConjectureReward(
        type: RewardType.cosmeticTitle,
        value: 0,
        title: 'Flow Whisperer',
      ),
    ],
    retryCooldown: Duration(hours: 72),
    isEndgame: true,
  ),
  'hodge_conjecture': ConjectureDef(
    id: 'hodge_conjecture',
    name: 'Hodge Conjecture',
    subjects: ['algebraic_topology', 'algebraic_geometry'],
    tier: 5,
    formulation: ConjectureCosts(0, 5e6, 1e4),
    workPerSession: ConjectureCosts(0, 250000, 500),
    progressPerWork: 2,
    successRewards: [
      ConjectureReward(type: RewardType.legacyBonus, value: 1000),
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 0.5,
        target: 'all',
      ),
      ConjectureReward(
        type: RewardType.cosmeticTitle,
        value: 0,
        title: 'Topologist Supreme',
      ),
    ],
    retryCooldown: Duration(hours: 72),
    isEndgame: true,
  ),
  'birch_swinnerton_dyer': ConjectureDef(
    id: 'birch_swinnerton_dyer',
    name: 'Birch\u2013Swinnerton-Dyer',
    subjects: ['analytic_number_theory', 'algebraic_geometry'],
    tier: 5,
    formulation: ConjectureCosts(0, 5e6, 1e4),
    workPerSession: ConjectureCosts(0, 250000, 500),
    progressPerWork: 2,
    successRewards: [
      ConjectureReward(type: RewardType.legacyBonus, value: 1000),
      ConjectureReward(
        type: RewardType.productionMultiplier,
        value: 1.0,
        target: 'all',
      ),
      ConjectureReward(
        type: RewardType.cosmeticTitle,
        value: 0,
        title: 'Elliptic Sage',
      ),
    ],
    retryCooldown: Duration(hours: 72),
    isEndgame: true,
  ),
};

/// Catalog ordered by tier (then id) for UI grouping and iteration.
List<ConjectureDef> conjecturesByTier() {
  final list = conjectureCatalog.values.toList()
    ..sort(
      (a, b) =>
          a.tier == b.tier ? a.id.compareTo(b.id) : a.tier.compareTo(b.tier),
    );
  return list;
}
