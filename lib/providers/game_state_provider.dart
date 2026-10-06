import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/game_state.dart';
import '../domain/models/producers.dart';
import '../domain/models/resources.dart';
import '../domain/models/save_data.dart';
import '../domain/models/upgrade.dart';
import '../domain/services/balance_service.dart';
import '../domain/services/offline_service.dart';
import '../domain/services/subject_service.dart';
import '../game/systems/career_system.dart';
import '../game/systems/conjecture_system.dart';
import '../game/systems/production_system.dart';
import '../game/systems/review_service.dart';

final gameStateProvider =
    NotifierProvider<GameStateNotifier, GameState>(GameStateNotifier.new);

/// Central mutable game state. All gameplay actions funnel through this
/// notifier; systems stay pure and are injected here.
class GameStateNotifier extends Notifier<GameState> {
  final ProductionSystem _production = const ProductionSystem();
  final ReviewService _review = ReviewService();
  final CareerSystem _career = CareerSystem();
  final BalanceService _balance = const BalanceService();
  final SubjectService _subjects = const SubjectService();
  final ConjectureSystem _conjectures = ConjectureSystem();
  final Random _rng = Random();

  VoidCallback? _saveHook;

  /// Transient report fed to the HUD "while you were away" banner.
  OfflineReport? lastAwayReport;

  @override
  GameState build() => GameState();

  /// The state object mutates in place, so tell Riverpod 3.x to notify
  /// listeners on every assignment (see [_refresh]).
  @override
  bool updateShouldNotify(GameState previous, GameState next) => true;

  /// Re-assigning the same instance triggers the notification pipeline.
  void _refresh() => state = state;

  /// Wires the persistence hook set up by main() after Hive init.
  void setSaveHook(VoidCallback saveNow) => _saveHook = saveNow;

  void requestSave() => _saveHook?.call();

  /// Replaces the fresh state with a loaded one (plus offline gains).
  void bootstrap(GameState loaded, {Resources? offlineGains}) {
    state = loaded..sessionStartedAt = DateTime.now();
    if (offlineGains != null && offlineGains.total > 0) {
      state.gain(offlineGains.counting, offlineGains.proofing, offlineGains.fame);
    }
    _refresh();
  }

  /// Public accessor for the persistence wiring in main().
  SaveData snapshotForSave([DateTime? now]) => state.toSaveData(now);

  /// Credits the gap between [awaySince] and [now] at offline rates
  /// (plan section 13.10): half speed, capped window (doubled by Measure
  /// Theory once completed). Called when the app returns to the foreground;
  /// [frozenSnapshot] is the state as saved at the moment of leaving.
  void applyAwayEarnings(SaveData frozenSnapshot, DateTime now) {
    final report = const OfflineService().compute(
        frozenSnapshot,
        now,
        capMultiplier: _subjects.modifiers(state).offlineCapMult);
    if (report.secondsApplied <= 0 || report.gained.total <= 0) return;
    state.gain(report.gained.counting, report.gained.proofing, report.gained.fame);
    if (report.secondsApplied >= 1) lastAwayReport = report;
    _refresh();
  }

  void dismissAwayReport() {
    if (lastAwayReport == null) return;
    lastAwayReport = null;
    _refresh();
  }

  // ---------------------------------------------------------------- actions

  /// Picks the mathematician's name shown all over the game.
  void setName(String raw) {
    var trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length > 24) trimmed = trimmed.substring(0, 24);
    if (trimmed.isEmpty || trimmed == state.playerName) return;
    state.playerName = trimmed;
    _afterMutation();
  }

  /// One manual exercise solve (the idle "click").
  void solveExercise() {
    final m = _subjects.modifiers(state);
    final power = _balance.clickPower(state.levelOf('study_tools')) *
        m.clickMultiplier * m.globalResourceMult *
        state.conjectureCountingMult * state.conjectureGlobalMult;
    state.gain(power);
    state.stats.totalClicks++;
    _refresh();
  }

  bool buyProducer(String id) {
    final def = producerCatalog[id];
    if (def == null) return false;
    final owned = state.levelOf(id);
    if (!_spendByKind(def.currency, _balance.producerCost(def, owned))) {
      return false;
    }
    state.producerLevels[id] = owned + 1;
    _afterMutation();
    return true;
  }

  bool buyTechnique(String id) {
    final def = techniqueCatalog[id];
    if (def == null || state.techniques.contains(id)) return false;
    if (!state.resources.spend(def.costCounting)) return false;
    state.techniques.add(id);
    _afterMutation();
    return true;
  }

  bool buyUpgrade(String id) {
    final def = upgradeCatalog[id];
    if (def == null) return false;
    final level = state.levelOf(id);
    if (def.maxLevel >= 0 && level >= def.maxLevel) return false;
    final cost =
        _balance.upgradeCost(def, level) * _subjects.modifiers(state).upgradeCostFactor;
    if (!_spendByKind(def.currency, cost)) {
      return false;
    }
    state.upgradeLevels[id] = level + 1;
    _afterMutation();
    return true;
  }

  /// Starts writing the next paper (cost scales with papers started this run).
  bool startPaper() {
    final m = _subjects.modifiers(state);
    if (state.activePapers.length >= _subjects.maxConcurrentPapers(state)) {
      return false; // all slots busy
    }
    final cost = _balance.paperCost(state.papersInRun) * m.paperCostFactor;
    if (!state.resources.spend(0, cost)) return false;
    state.papersInRun++;
    state.activePapers.add(PaperJob(PaperConfig.writeDurationSeconds));
    _afterMutation();
    return true;
  }

  bool defendThesis() {
    final ok = _career.tryDefendThesis(state);
    if (ok) _afterMutation();
    return ok;
  }

  // ---------------------------------------------------------- conjectures

  /// Pays the one-time formulation cost (postdoc gate, §5).
  bool formulateConjecture(String id) {
    if (!_conjectures.canFormulate(state, id)) return false;
    if (!_conjectures.formulate(state, id)) return false;
    _afterMutation();
    return true;
  }

  /// One paid work session; a failed roll grants Metodo XP (§4).
  void workOnConjecture(String id) {
    final d = _conjectures.def(id);
    if (d == null || !_conjectures.canWork(state, id)) return;
    final outcome = _conjectures.workSession(state, id);
    if (outcome != null) {
      if (outcome == ConjectureOutcome.refuted) {
        _gainMethodXp(d.failureMethodXp);
      } else {
        state.stats.conjecturesSolved++;
      }
    }
    _afterMutation();
  }

  /// Per-frame tick: passive production, paper pipeline, career gates.
  void tick(double dt) {
    _production.tick(state, dt, _subjects.modifiers(state));
    _advancePapers(dt);
    _conjectures.update(state);
    _career.update(state);
    _refresh();
  }

  // ------------------------------------------------------- research focus

  /// Completed-subject effects for UI display and other systems.
  SubjectModifiers get subjectModifiers => _subjects.modifiers(state);

  /// Focuses research on a subject: accepted papers credit its theorems.
  void focusSubject(String id) {
    if (_subjects.setFocus(state, id)) _afterMutation();
  }

  void clearFocus() {
    if (state.activeSubjectId.isNotEmpty) {
      _subjects.clearFocus(state);
      _afterMutation();
    }
  }

  // ------------------------------------------------------------- internals

  ProductionRates get rates => _production.compute(state);

  double get fameMultiplier => _production.fameMultiplier(state);

  bool _spendByKind(ResourceKind kind, double amount) {
    switch (kind) {
      case ResourceKind.counting:
        return state.resources.spend(amount);
      case ResourceKind.proofing:
        return state.resources.spend(0, amount);
      case ResourceKind.fame:
        return state.resources.spend(0, 0, amount);
    }
  }

  void _advancePapers(double dt) {
    for (final job in List.of(state.activePapers)) {
      if (job.awaitingRewrite) {
        final rewriteCost = _review.revisionCost(state.papersInRun - 1);
        if (_spendByKind(ResourceKind.proofing, rewriteCost)) {
          job.awaitingRewrite = false;
          job.remainingSeconds = PaperConfig.writeDurationSeconds;
        } else {
          continue; // wait until the rewrite is affordable
        }
      }
      job.remainingSeconds -= dt;
      if (job.remainingSeconds <= 0) {
        final finished = _resolvePaper(job);
        if (finished) state.activePapers.remove(job);
      }
    }
  }

  /// Resolves a finished writing session. Returns true when the paper is
  /// out of the pipeline (accepted or rejected); false while it waits for a
  /// rewrite round.
  bool _resolvePaper(PaperJob job) {
    final mods = _subjects.modifiers(state);
    final outcome = _review.roll(acceptanceBonus: mods.acceptanceBonus);
    switch (outcome) {
      case ReviewOutcome.accepted:
        var fame = _review.paperReward(
          state.papersInRun,
          fameMultiplier: fameMultiplier,
          afterRevision: job.revisionBonus,
        );
        fame *= mods.famePerPaperMult;
        if (_rng.nextDouble() < mods.fameBurstChance) {
          fame *= mods.fameBurstMult;
        }
        state.gain(0, 0, fame);
        state.stats.papersPublished++;
        _subjects.registerAcceptedPaper(state);
        return true;
      case ReviewOutcome.revisionRequested:
        // Rewrite at half cost; the x1.25 bonus applies to the final reward.
        job.revisionBonus = true;
        job.remainingSeconds = PaperConfig.writeDurationSeconds;
        job.awaitingRewrite = true;
        return false;
      case ReviewOutcome.rejected:
        state.stats.papersRejected++;
        _gainMethodXp(ReviewService.methodXpOnRejection);
        return true;
    }
  }

  void _gainMethodXp(int xp) {
    state.metodoXp += xp;
    while (state.metodoXp >= _balance.methodXpToNextLevel(state.metodoLevel)) {
      state.metodoXp -= _balance.methodXpToNextLevel(state.metodoLevel);
      state.metodoLevel++;
    }
  }

  /// Save on purchase/upgrade events (plan section 14.5), then refresh UI.
  void _afterMutation() {
    requestSave();
    _refresh();
  }
}
