import 'career.dart';
import 'conjecture.dart';
import 'producers.dart';
import 'resources.dart';
import 'save_data.dart';

/// A paper currently being written or rewritten (section 13.4).
/// Transient only — never persisted (section 14.2 rule).
class PaperJob {
  double remainingSeconds;
  bool revisionBonus;

  /// True while waiting for the half-cost rewrite payment.
  bool awaitingRewrite;

  /// Proofing price paid when the paper was started; a rewrite costs half
  /// of it regardless of how many other papers were queued meanwhile.
  double originalCost;

  PaperJob(
    this.remainingSeconds, {
    this.revisionBonus = false,
    this.awaitingRewrite = false,
    this.originalCost = 0,
  });
}

/// Runtime game state. Everything here maps 1:1 onto [SaveData] except
/// transient fields marked as such. Systems mutate this object through the
/// Riverpod notifier; UI reads it reactively.
class GameState {
  /// Empty until the player picks a name at startup.
  String playerName = '';
  Resources resources = Resources();
  Map<String, double> lifetime = {'counting': 0, 'proofing': 0, 'fame': 0};
  CareerState career = CareerState();
  Map<String, BranchProgress> branches = {};

  /// Id of the subject currently receiving theorem credit; '' = none.
  String activeSubjectId = '';
  Map<String, int> producerLevels = {};
  Map<String, int> upgradeLevels = {};
  Set<String> techniques = {};
  List<ConjectureState> conjectures = [];

  /// Permanent production multipliers granted by PROVEN conjectures (§4).
  double conjectureCountingMult = 1;
  double conjectureProofingMult = 1;
  double conjectureGlobalMult = 1;

  /// Burnout stress 0..1 and active burnout window (section 13.10).
  double stress = 0;
  DateTime? burnedOutUntil;

  /// Accepted papers that may be retracted later (section 2).
  List<ScheduledRetraction> scheduledRetractions = [];
  PrestigeState prestige = PrestigeState();
  TrendState trend = TrendState();
  int metodoLevel = 1;
  int metodoXp = 0;
  int papersInRun = 0;

  /// Papers accepted this run: drives Fame scaling and passive citations
  /// (§13.4). Resets with the run at prestige.
  int papersPublishedInRun = 0;

  /// Cosmetic titles earned by proving open problems (§3 endgame).
  List<String> titles = [];

  /// Active optional challenge id ('' = none) — section 7.
  String activeChallenge = '';

  /// Challenges already completed; each pays out once.
  List<String> completedChallenges = [];

  /// Permanent production boost from completed challenges.
  double challengeGlobalMult = 1;

  /// Transient: active writing jobs. Rebuilt from nothing on load.
  List<PaperJob> activePapers = [];
  Settings settings = Settings();
  Stats stats = Stats();
  DateTime savedAt = DateTime.now();
  DateTime lastLoadedAt = DateTime.now();

  /// Transient: session start for playtime accounting.
  DateTime sessionStartedAt = DateTime.now();

  /// Transient: short-lived HUD notice (never persisted).
  String? transientNotice;
  DateTime? transientNoticeUntil;

  /// Total gained (current + cumulative) helper used by career gates.
  double lifetimeOf(ResourceKind kind) => lifetime[kind.key] ?? 0;

  void gain(
    double countingGain, [
    double proofingGain = 0,
    double fameGain = 0,
  ]) {
    resources.gain(countingGain, proofingGain, fameGain);
    lifetime['counting'] = (lifetime['counting'] ?? 0) + countingGain;
    lifetime['proofing'] = (lifetime['proofing'] ?? 0) + proofingGain;
    lifetime['fame'] = (lifetime['fame'] ?? 0) + fameGain;
  }

  int levelOf(String id) => producerLevels[id] ?? upgradeLevels[id] ?? 0;

  SaveData toSaveData([DateTime? now]) {
    final t = now ?? DateTime.now();
    return SaveData(
      version: SaveData.currentVersion,
      playerName: playerName,
      // Playtime accumulates across sessions (stats is flavor-only data).
      savedAt: t,
      lastLoadedAt: t,
      resources: resources.copy(),
      lifetime: Map.of(lifetime),
      career: career.copy(),
      branches: branches.map((k, v) => MapEntry(k, v)),
      activeSubjectId: activeSubjectId,
      producerLevels: Map.of(producerLevels),
      upgradeLevels: Map.of(upgradeLevels),
      techniques: List.of(techniques),
      conjectures: List.of(conjectures),
      conjCountMult: conjectureCountingMult,
      conjProofMult: conjectureProofingMult,
      conjGlobalMult: conjectureGlobalMult,
      stress: stress,
      burnedOutUntil: burnedOutUntil,
      scheduledRetractions: List.of(scheduledRetractions),
      prestige: PrestigeState(
        legacy: prestige.legacy,
        legacyAllTime: prestige.legacyAllTime,
        prestigesCount: prestige.prestigesCount,
        mathematicians: List.of(prestige.mathematicians),
      ),
      trend: TrendState(
        activeSubject: trend.activeSubject,
        endsAt: trend.endsAt,
        nextSubject: trend.nextSubject,
        nextStartsAt: trend.nextStartsAt,
      ),
      metodoLevel: metodoLevel,
      metodoXp: metodoXp,
      papersInRun: papersInRun,
      papersPublishedInRun: papersPublishedInRun,
      titles: List.of(titles),
      activeChallenge: activeChallenge,
      completedChallenges: List.of(completedChallenges),
      challengeGlobalMult: challengeGlobalMult,
      settings: Settings(
        theme: settings.theme,
        sound: settings.sound,
        reducedMotion: settings.reducedMotion,
      ),
      stats: Stats(
        totalClicks: stats.totalClicks,
        papersPublished: stats.papersPublished,
        papersRejected: stats.papersRejected,
        retractions: stats.retractions,
        conjecturesSolved: stats.conjecturesSolved,
        playtimeMs:
            stats.playtimeMs + t.difference(sessionStartedAt).inMilliseconds,
      ),
    );
  }

  static GameState fromSave(SaveData save) {
    final s = GameState()
      ..playerName = save.playerName
      ..savedAt = save.savedAt
      ..lastLoadedAt = save.lastLoadedAt
      ..resources = Resources(
        counting: save.resources.counting,
        proofing: save.resources.proofing,
        fame: save.resources.fame,
      )
      ..lifetime = Map.of(save.lifetime)
      ..career = CareerState(
        stage: save.career.stage,
        thesisDefended: save.career.thesisDefended,
        apprentices: save.career.apprentices,
      )
      ..branches = Map.of(save.branches)
      ..activeSubjectId = save.activeSubjectId
      ..producerLevels = Map.of(save.producerLevels)
      ..upgradeLevels = Map.of(save.upgradeLevels)
      ..techniques = Set.of(save.techniques)
      ..conjectures = List.of(save.conjectures)
      ..conjectureCountingMult = save.conjCountMult
      ..conjectureProofingMult = save.conjProofMult
      ..conjectureGlobalMult = save.conjGlobalMult
      ..stress = save.stress
      ..burnedOutUntil = save.burnedOutUntil
      ..scheduledRetractions = List.of(save.scheduledRetractions)
      ..prestige = PrestigeState(
        legacy: save.prestige.legacy,
        legacyAllTime: save.prestige.legacyAllTime,
        prestigesCount: save.prestige.prestigesCount,
        mathematicians: List.of(save.prestige.mathematicians),
      )
      ..trend = TrendState(
        activeSubject: save.trend.activeSubject,
        endsAt: save.trend.endsAt,
        nextSubject: save.trend.nextSubject,
        nextStartsAt: save.trend.nextStartsAt,
      )
      ..metodoLevel = save.metodoLevel
      ..metodoXp = save.metodoXp
      ..papersInRun = save.papersInRun
      ..papersPublishedInRun = save.papersPublishedInRun
      ..titles = List.of(save.titles)
      ..activeChallenge = save.activeChallenge
      ..completedChallenges = List.of(save.completedChallenges)
      ..challengeGlobalMult = save.challengeGlobalMult
      ..settings = Settings(
        theme: save.settings.theme,
        sound: save.settings.sound,
        reducedMotion: save.settings.reducedMotion,
      )
      ..stats = Stats(
        totalClicks: save.stats.totalClicks,
        papersPublished: save.stats.papersPublished,
        papersRejected: save.stats.papersRejected,
        retractions: save.stats.retractions,
        conjecturesSolved: save.stats.conjecturesSolved,
        playtimeMs: save.stats.playtimeMs,
      );
    return s;
  }
}
