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
import '../game/systems/apprentice_service.dart';
import '../game/systems/career_system.dart';
import '../game/systems/challenge_service.dart';
import '../game/systems/conjecture_system.dart';
import '../game/systems/friction_system.dart';
import '../game/systems/prestige_service.dart';
import '../game/systems/trend_service.dart';
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
  final FrictionSystem _friction = const FrictionSystem();
  final ApprenticeService _apprentices = const ApprenticeService();
  final ChallengeService _challenges = const ChallengeService();
  final TrendService _trend = const TrendService();
  final PrestigeService _prestige = const PrestigeService();
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
    // No-Paper Run: every solved exercise also earns Fame directly (§7).
    final clickFame = _challenges.clickFame(state);
    if (clickFame > 0) state.gain(0, 0, clickFame);
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
    // No-Paper Run closes the publication desk (section 7).
    if (_challenges.blocksNewPapers(state)) return false;
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

  /// Sabbatical: pay 10% of current Fame to clear stress instantly (§13.10).
  bool takeSabbatical() {
    if (!_friction.takeSabbatical(state)) return false;
    _notice('A well-earned break. Stress cleared.');
    _afterMutation();
    return true;
  }

  /// Recruit the next apprentice into the laboratory (sections 5, 13.8).
  bool hireApprentice() {
    final def = _apprentices.hire(state);
    if (def == null) return false;
    _notice(
        '${def.name} joins your laboratory (+${def.countingPerSec.toStringAsFixed(0)} Counting/s).');
    _afterMutation();
    return true;
  }

  // ------------------------------------------------------------ prestige

  /// Combined Fame->Eredità conversion factor: completed-subject bonuses
  /// (e.g. Algebraic Topology +25%) times any active challenge factor.
  double prestigeLegacyFactor() =>
      _challenges.prestigeLegacyFactor(state) *
          _subjects.modifiers(state).legacyGainMult;

  int get legacyGainNow =>
      (_prestige.legacyGain(state) * prestigeLegacyFactor()).round();

  /// Reboots the run into Legacy points (sections 6 and 13.9). Completes
  /// any active challenge on the way out (section 7).
  bool prestige() {
    if (!_prestige.canPrestige(state)) return false;
    final factor = prestigeLegacyFactor();
    final gain = (_prestige.legacyGain(state) * factor).round();
    _prestige.applyPrestige(state, factor);
    var message = '+$gain Eredità — a new chapter begins.';
    final completed = _challenges.completeAtPrestige(state);
    if (completed != null) {
      message += ' ${completed.name} complete!';
    }
    _notice(message);
    _afterMutation();
    return true;
  }

  // ---------------------------------------------------------- challenges

  /// Starts an optional challenge for this run (section 7).
  bool enterChallenge(String id) {
    if (!_challenges.enter(state, id)) return false;
    final d = _challenges.def(id)!;
    _notice('${d.name} accepted. It completes when you prestige.');
    _afterMutation();
    return true;
  }

  /// Gives up on the active challenge without its reward.
  bool abandonChallenge() {
    if (state.activeChallenge.isEmpty) return false;
    _challenges.abandon(state);
    _notice('You set the challenge aside.');
    _afterMutation();
    return true;
  }

  /// Hires a historical mathematician with Legacy points.
  bool hireMathematician(String id) {
    final def = mathematicianById(id);
    if (def == null || !_prestige.hireMathematician(state, id)) return false;
    _notice(def.lore);
    _afterMutation();
    return true;
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
    // Trending branch: +25% progress on its conjectures (section 4).
    final trendBonus = d.subjects.any((b) => _trend.isTrending(state, b))
        ? TrendService.conjectureProgressBonus
        : 0.0;
    final ramanujanBonus = state.prestige.mathematicians.contains('ramanujan')
        ? 0.10
        : 0.0;
    final titlesBefore = state.titles.length;
    final outcome = _conjectures.workSession(
        state, id,
        trendBonus: trendBonus, ramanujanBonus: ramanujanBonus);
    if (outcome != null) {
      if (outcome == ConjectureOutcome.refuted) {
        _gainMethodXp(d.failureMethodXp);
      } else {
        state.stats.conjecturesSolved++;
        if (state.titles.length > titlesBefore) {
          _notice(
              '${d.name} is PROVEN — "${state.titles.last}" joins your legend.');
        } else {
          _notice('You proved ${d.name}!');
        }
      }
    }
    _afterMutation();
  }

  /// Per-frame tick: passive production, paper pipeline, frictions, gates.
  void tick(double dt) {
    _production.tick(state, dt, _subjects.modifiers(state));
    _advancePapers(dt);
    final retractionsBefore = state.stats.retractions;
    for (final msg in _friction.tick(state, dt)) {
      _notice(msg);
    }
    if (state.stats.retractions > retractionsBefore) {
      _gainMethodXp(FrictionSystem.retractionMethodXp *
          (state.stats.retractions - retractionsBefore));
    }
    _expireNotice();
    _trend.update(state);
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
        // Constructivist Run: hand-written results carry double weight (§7).
        fame *= _challenges.paperFameFactor(state);
        // Papers earn half Fame until the thesis is defended (section 5).
        fame *= CareerSystem.paperFameFactor(state.career);
        // Focusing the trending field doubles paper Fame (sections 3/13.10).
        if (_trend.isTrending(state, state.activeSubjectId)) {
          fame *= TrendService.paperFameMult;
        }
        if (_rng.nextDouble() < mods.fameBurstChance) {
          fame *= mods.fameBurstMult;
        }
        state.gain(0, 0, fame);
        state.stats.papersPublished++;
        _friction.maybeScheduleRetraction(state, _rng);
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

  /// Short-lived HUD notice (retractions, burnout, breaks).
  void _notice(String message) {
    state.transientNotice = message;
    state.transientNoticeUntil = DateTime.now().add(const Duration(seconds: 8));
  }

  void _expireNotice() {
    final until = state.transientNoticeUntil;
    if (until != null && !DateTime.now().isBefore(until)) {
      state.transientNotice = null;
      state.transientNoticeUntil = null;
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
