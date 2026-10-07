import 'dart:math';

import '../../domain/models/career.dart';
import '../../domain/models/conjecture.dart';
import '../../domain/models/game_state.dart';
import '../../domain/services/subject_service.dart';

/// Outcome of a resolution roll once progress reaches 100%.
enum ConjectureOutcome { proved, refuted }

/// Discovery loop over completed branches (plan sections 4, 7, 13.7):
/// formulate once, fund work sessions, roll at 100%, learn from failure.
class ConjectureSystem {
  ConjectureSystem({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;
  final SubjectService _subjects = const SubjectService();

  /// Hard caps (section 4 rules table).
  static const int maxActiveGlobal = 2;

  /// Intuition events (v0 draft): completing Stochastic Processes gives each
  /// session a chance of free extra progress — the "aha!" moment.
  static const double intuitionChance = 0.10;
  static const double intuitionProgressMult = 1.5;

  ConjectureDef? def(String id) => conjectureCatalog[id];

  ConjectureState? stateOf(GameState s, String id) {
    for (final c in s.conjectures) {
      if (c.defId == id) return c;
    }
    return null;
  }

  bool isFormulated(GameState s, String id) => stateOf(s, id) != null;

  /// Postdoc gate (section 5), professor-only gate for open problems
  /// (section 3 endgame) plus every required branch COMPLETED.
  bool canFormulate(GameState s, String id) {
    final d = conjectureCatalog[id];
    if (d == null || stateOf(s, id) != null) return false;
    if (s.career.stage.index < CareerStage.postdoc.index) return false;
    if (endgameLocked(s, d)) return false;
    return d.subjects.every((b) => _subjects.isCompleted(s, b));
  }

  /// Open problems stay sealed until the player reaches Professor.
  bool endgameLocked(GameState s, ConjectureDef d) =>
      d.isEndgame && s.career.stage != CareerStage.professor;

  List<String> missingSubjects(GameState s, String id) {
    final d = conjectureCatalog[id];
    if (d == null) return const [];
    return d.subjects.where((b) => !_subjects.isCompleted(s, b)).toList();
  }

  /// Active OR cooling-down conjectures occupy their slots.
  int activeCount(GameState s) => s.conjectures
      .where(
        (c) =>
            c.status == ConjectureStatus.active ||
            c.status == ConjectureStatus.refuted,
      )
      .length;

  bool _sharesSubject(GameState s, ConjectureDef d) {
    for (final c in s.conjectures) {
      if (c.status != ConjectureStatus.active &&
          c.status != ConjectureStatus.refuted) {
        continue;
      }
      final other = conjectureCatalog[c.defId];
      if (other != null && other.subjects.any(d.subjects.contains)) {
        return true;
      }
    }
    return false;
  }

  /// True when the global/per-branch caps allow starting [id] right now.
  bool slotsAvailable(GameState s, String id) {
    final d = conjectureCatalog[id];
    if (d == null) return false;
    if (activeCount(s) >= maxActiveGlobal) return false;
    return !_sharesSubject(s, d);
  }

  /// Pays the one-time formulation cost and starts the discovery loop.
  bool formulate(GameState s, String id) {
    if (!canFormulate(s, id)) return false;
    final d = conjectureCatalog[id]!;
    if (!slotsAvailable(s, id)) return false;
    if (!s.resources.spend(
      d.formulation.counting,
      d.formulation.proofing,
      d.formulation.fame,
    )) {
      return false;
    }
    s.conjectures.add(
      ConjectureState(defId: id, status: ConjectureStatus.active),
    );
    return true;
  }

  bool canWork(GameState s, String id) {
    final st = stateOf(s, id);
    return st != null && st.status == ConjectureStatus.active;
  }

  /// One paid work session. Returns the outcome when this session pushed
  /// progress to 100% (and rolled), otherwise null. [trendBonus] adds the
  /// trending-branch progress fraction (section 4 rules table).
  /// [ramanujanBonus] raises P(successo) by that fraction and adds a 5%
  /// insight flash per session (prestige perk, section 13.9).
  ConjectureOutcome? workSession(
    GameState s,
    String id, {
    double trendBonus = 0,
    double ramanujanBonus = 0,
  }) {
    final st = stateOf(s, id);
    final d = conjectureCatalog[id];
    if (st == null || d == null || !canWork(s, id)) return null;
    if (!s.resources.spend(
      d.workPerSession.counting,
      d.workPerSession.proofing,
      d.workPerSession.fame,
    )) {
      return null;
    }
    var gain = d.progressPerWork * (1 + trendBonus);
    if (_subjects.isCompleted(s, 'stochastic_processes') &&
        _rng.nextDouble() < intuitionChance) {
      gain *= intuitionProgressMult;
    }
    // Ramanujan's insight flash: occasional doubled session gain.
    if (ramanujanBonus > 0 && _rng.nextDouble() < 0.05) {
      gain *= 2;
    }
    st.lastWorkAt = DateTime.now();
    st.progress += gain;
    if (st.progress >= 100) {
      st.progress = 100;
      return _resolve(s, st, d, ramanujanBonus);
    }
    return null;
  }

  ConjectureOutcome _resolve(
    GameState s,
    ConjectureState st,
    ConjectureDef d,
    double ramanujanBonus,
  ) {
    st.attempts++;
    if (_rng.nextDouble() <
        successProbability(
          s.metodoLevel,
          d.tier,
          ramanujanBonus: ramanujanBonus,
        )) {
      st.status = ConjectureStatus.proven;
      st.resolvedAt = DateTime.now();
      _applyRewards(s, d.successRewards);
      return ConjectureOutcome.proved;
    }
    // Failure keeps half the progress, grants Metodo XP (via caller) and
    // enforces a cooldown before working resumes.
    st.status = ConjectureStatus.refuted;
    st.readyAt = DateTime.now().add(d.retryCooldown);
    st.progress *= 0.5;
    return ConjectureOutcome.refuted;
  }

  /// P(successo) = clamp(0.50 + 0.08·(metodo − tier) + bonusRamanujan,
  /// 0.15, 0.95) — section 4. The Ramanujan bonus lands with prestige.
  double successProbability(
    int metodoLevel,
    int tier, {
    double ramanujanBonus = 0,
  }) {
    return (0.50 + 0.08 * (metodoLevel - tier) + ramanujanBonus).clamp(
      0.15,
      0.95,
    );
  }

  void _applyRewards(GameState s, List<ConjectureReward> rewards) {
    for (final r in rewards) {
      switch (r.type) {
        case RewardType.productionMultiplier:
          switch (r.target) {
            case 'counting':
              s.conjectureCountingMult *= 1 + r.value;
            case 'proofing':
              s.conjectureProofingMult *= 1 + r.value;
            default: // 'all' scales every channel
              s.conjectureGlobalMult *= 1 + r.value;
          }
        case RewardType.fameBurst:
          s.gain(0, 0, r.value);
        case RewardType.legacyBonus:
          s.prestige.legacy += r.value.round();
          s.prestige.legacyAllTime += r.value.round();
        case RewardType.cosmeticTitle:
          if (r.title.isNotEmpty && !s.titles.contains(r.title)) {
            s.titles.add(r.title);
          }
      }
    }
  }

  /// Cooldown bookkeeping: refuted conjectures become workable again.
  void update(GameState s, [DateTime? now]) {
    final t = now ?? DateTime.now();
    for (final c in s.conjectures) {
      if (c.status == ConjectureStatus.refuted &&
          c.readyAt != null &&
          !t.isBefore(c.readyAt!)) {
        c.status = ConjectureStatus.active;
        c.readyAt = null;
      }
    }
  }
}
