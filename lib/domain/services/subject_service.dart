import '../models/game_state.dart';
import '../models/save_data.dart';
import '../models/subject.dart';

/// Combined effect of every COMPLETED subject on the current state.
class SubjectModifiers {
  final double clickMultiplier;
  final double countingRateAdd;
  final double proofingRateAdd;
  final double countingMultiplier;
  final double proofingMultiplier;
  final double famePerPaperMult;
  final double fameBurstChance;
  final double fameBurstMult;
  final double paperCostFactor;
  final double upgradeCostFactor;
  final double acceptanceBonus;
  final int extraPapers;
  final int extraConjectures;
  final double offlineCapMult;
  final double legacyGainMult;
  final bool sessionCompounding;
  final double globalResourceMult;
  final double countingPerTheorem;

  const SubjectModifiers({
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
    this.extraConjectures = 0,
    this.offlineCapMult = 1,
    this.legacyGainMult = 1,
    this.sessionCompounding = false,
    this.globalResourceMult = 1,
    this.countingPerTheorem = 0,
  });

  static const SubjectModifiers none = SubjectModifiers();
}

/// Rules around the subject tree (plan section 3). Pure over [GameState];
/// the notifier mutates state through these helpers.
class SubjectService {
  const SubjectService();

  /// A subject is unlocked when every prerequisite is completed.
  List<String> missingPrereqs(GameState s, String id) {
    final def = subjectCatalog[id];
    if (def == null) return const [];
    return def.prereqs.where((p) => !isCompleted(s, p)).toList();
  }

  bool isUnlocked(GameState s, String id) => missingPrereqs(s, id).isEmpty;

  bool isCompleted(GameState s, String id) =>
      s.branches[id]?.completed ?? false;

  bool isActive(GameState s, String id) => s.activeSubjectId == id;

  int theoremsOf(GameState s, String id) =>
      s.branches[id]?.theoremsMastered ?? 0;

  /// Total theorems mastered across all subjects (drives Number Theory's
  /// scaling multiplier).
  int totalTheorems(GameState s) =>
      s.branches.values.fold(0, (sum, b) => sum + b.theoremsMastered);

  int maxConcurrentPapers(GameState s) {
    var slots = 1;
    for (final def in subjectCatalog.values) {
      if (isCompleted(s, def.id)) slots += def.effects.extraPapers;
    }
    return slots;
  }

  /// Base global cap on active conjectures before subject bonuses (§4).
  static const int baseMaxActiveConjectures = 2;

  /// Global cap right now: base plus every completed subject's bonus.
  int maxActiveConjectures(GameState s) =>
      baseMaxActiveConjectures + modifiers(s).extraConjectures;

  /// Focus research on an unlocked, incomplete subject. Returns false when
  /// the target is locked or already complete.
  bool setFocus(GameState s, String id) {
    final def = subjectCatalog[id];
    if (def == null || isCompleted(s, id) || !isUnlocked(s, id)) return false;
    s.activeSubjectId = id;
    _ensureBranch(s, id);
    return true;
  }

  void clearFocus(GameState s) => s.activeSubjectId = '';

  /// Credits one accepted paper to the focused subject and completes it at
  /// the mastery threshold. Completed subjects keep their focus cleared so
  /// the player must pick the next front.
  void registerAcceptedPaper(GameState s) {
    final id = s.activeSubjectId;
    if (id.isEmpty) return;
    final def = subjectCatalog[id];
    if (def == null || isCompleted(s, id)) {
      s.activeSubjectId = '';
      return;
    }
    final branch = _ensureBranch(s, id);
    branch.theoremsMastered++;
    if (branch.theoremsMastered >= masteryNeeded(def.level)) {
      branch.completed = true;
      s.activeSubjectId = '';
    }
  }

  BranchProgress _ensureBranch(GameState s, String id) {
    final existing = s.branches[id];
    if (existing != null) return existing;
    final created = BranchProgress();
    s.branches[id] = created;
    return created;
  }

  /// Multiplies/adds the effects of all completed subjects.
  SubjectModifiers modifiers(GameState s) {
    var click = 1.0, cAdd = 0.0, pAdd = 0.0, cMult = 1.0, pMult = 1.0;
    var fame = 1.0, burstC = 0.0, burstM = 1.0, paperCost = 1.0, upgCost = 1.0;
    var accept = 0.0, papers = 0, conj = 0, offline = 1.0, legacy = 1.0;
    var global = 1.0;
    var perThm = 0.0;
    var compounding = false;
    for (final def in subjectCatalog.values) {
      if (!isCompleted(s, def.id)) continue;
      final e = def.effects;
      click *= e.clickMultiplier;
      cAdd += e.countingRateAdd;
      pAdd += e.proofingRateAdd;
      cMult *= e.countingMultiplier;
      pMult *= e.proofingMultiplier;
      fame *= e.famePerPaperMult;
      burstC = min(burstC + e.fameBurstChance, 1.0);
      burstM *= e.fameBurstMult;
      paperCost *= e.paperCostFactor;
      upgCost *= e.upgradeCostFactor;
      accept += e.acceptanceBonus;
      papers += e.extraPapers;
      conj += e.extraConjectures;
      offline *= e.offlineCapMult;
      legacy *= e.legacyGainMult;
      global *= e.globalResourceMult;
      perThm += e.countingPerTheorem;
      compounding |= e.sessionCompounding;
    }
    // Number Theory scales Counting with total theorems mastered.
    cMult *= 1 + perThm * totalTheorems(s);
    return SubjectModifiers(
      clickMultiplier: click,
      countingRateAdd: cAdd,
      proofingRateAdd: pAdd,
      countingMultiplier: cMult,
      proofingMultiplier: pMult,
      famePerPaperMult: fame,
      fameBurstChance: burstC,
      fameBurstMult: burstM,
      paperCostFactor: paperCost,
      upgradeCostFactor: upgCost,
      acceptanceBonus: accept.clamp(0.0, 0.45),
      extraPapers: papers,
      extraConjectures: conj,
      offlineCapMult: offline,
      legacyGainMult: legacy,
      sessionCompounding: compounding,
      globalResourceMult: global,
      countingPerTheorem: perThm,
    );
  }
}

// Local helper so the service file stays dependency-light.
double min(double a, double b) => a < b ? a : b;
