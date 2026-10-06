import 'career.dart';
import 'conjecture.dart';
import 'resources.dart';

/// Persisted branch progress (phase 2+ populates this).
class BranchProgress {
  int theoremsMastered = 0;
  bool completed = false;

  BranchProgress({this.theoremsMastered = 0, this.completed = false});

  factory BranchProgress.fromJson(Map<String, dynamic> json) => BranchProgress(
        theoremsMastered: json['theorems_mastered'] as int,
        completed: json['completed'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'theorems_mastered': theoremsMastered,
        'completed': completed,
      };
}

class PrestigeState {
  int legacy = 0;
  int prestigesCount = 0;
  List<String> mathematicians = [];

  PrestigeState({this.legacy = 0, this.prestigesCount = 0, List<String>? mathematicians})
      : mathematicians = mathematicians ?? [];

  factory PrestigeState.fromJson(Map<String, dynamic> json) => PrestigeState(
        legacy: json['legacy'] as int,
        prestigesCount: json['prestiges_count'] as int,
        mathematicians: (json['mathematicians'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'legacy': legacy,
        'prestiges_count': prestigesCount,
        'mathematicians': mathematicians,
      };
}

class TrendState {
  /// Empty string = no trend active (rotating trends arrive in phase 3).
  String activeSubject;
  DateTime? endsAt;
  String nextSubject;
  DateTime? nextStartsAt;

  TrendState({this.activeSubject = '', this.endsAt, this.nextSubject = '', this.nextStartsAt});

  factory TrendState.fromJson(Map<String, dynamic> json) => TrendState(
        activeSubject: json['active_subject'] as String? ?? '',
        endsAt: json['ends_at_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['ends_at_ms'] as int),
        nextSubject: json['next_subject'] as String? ?? '',
        nextStartsAt: json['next_starts_at_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['next_starts_at_ms'] as int),
      );

  Map<String, dynamic> toJson() => {
        'active_subject': activeSubject,
        'ends_at_ms': endsAt?.millisecondsSinceEpoch,
        'next_subject': nextSubject,
        'next_starts_at_ms': nextStartsAt?.millisecondsSinceEpoch,
      };
}

class Settings {
  /// 'chalkboard' | 'notebook'
  String theme;
  bool sound;
  bool reducedMotion;

  Settings({this.theme = 'chalkboard', this.sound = true, this.reducedMotion = false});

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        theme: json['theme'] as String? ?? 'chalkboard',
        sound: json['sound'] as bool? ?? true,
        reducedMotion: json['reduced_motion'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'sound': sound,
        'reduced_motion': reducedMotion,
      };
}

/// Flavor/export only — never read by game logic (plan section 14.2).
class Stats {
  int totalClicks;
  int papersPublished; // lifetime across prestiges
  int papersRejected;
  int retractions;
  int conjecturesSolved;
  int playtimeMs;

  Stats({
    this.totalClicks = 0,
    this.papersPublished = 0,
    this.papersRejected = 0,
    this.retractions = 0,
    this.conjecturesSolved = 0,
    this.playtimeMs = 0,
  });

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
        totalClicks: json['total_clicks'] as int? ?? 0,
        papersPublished: json['papers_published'] as int? ?? 0,
        papersRejected: json['papers_rejected'] as int? ?? 0,
        retractions: json['retractions'] as int? ?? 0,
        conjecturesSolved: json['conjectures_solved'] as int? ?? 0,
        playtimeMs: json['playtime_ms'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'total_clicks': totalClicks,
        'papers_published': papersPublished,
        'papers_rejected': papersRejected,
        'retractions': retractions,
        'conjectures_solved': conjecturesSolved,
        'playtime_ms': playtimeMs,
      };
}

/// Full save schema (plan section 14.2), hand-rolled JSON so it stays
/// testable without codegen. Dates are epoch milliseconds.
///
/// Fields marked "addition" go beyond the v4 doc draft and are needed for a
/// playable loop; they are additive (no breaking change to existing keys).
class SaveData {
  static const int currentVersion = 3;

  int version;
  /// Player-chosen mathematician name; empty until chosen (additive field).
  String playerName;
  DateTime savedAt;
  DateTime lastLoadedAt;
  Resources resources;
  Map<String, double> lifetime;
  CareerState career;
  Map<String, BranchProgress> branches;
  /// Focused research target id ('' = none); additive field.
  String activeSubjectId;
  Map<String, int> producerLevels;
  Map<String, int> upgradeLevels;
  /// Owned technique ids (addition vs doc draft).
  List<String> techniques;
  List<ConjectureState> conjectures;
  PrestigeState prestige;
  TrendState trend;
  int metodoLevel;
  /// XP towards the next Metodo level (addition vs doc draft).
  int metodoXp;
  /// Papers started this run: drives paper cost scaling and citations.
  int papersInRun;
  Settings settings;
  Stats stats;

  SaveData({
    required this.version,
    this.playerName = '',
    required this.savedAt,
    required this.lastLoadedAt,
    required this.resources,
    required this.lifetime,
    required this.career,
    required this.branches,
    this.activeSubjectId = '',
    required this.producerLevels,
    required this.upgradeLevels,
    required this.techniques,
    required this.conjectures,
    required this.prestige,
    required this.trend,
    required this.metodoLevel,
    required this.metodoXp,
    required this.papersInRun,
    required this.settings,
    required this.stats,
  });

  factory SaveData.fresh([DateTime? now]) {
    final t = now ?? DateTime.now();
    return SaveData(
      version: currentVersion,
      savedAt: t,
      lastLoadedAt: t,
      resources: Resources(),
      lifetime: {'counting': 0, 'proofing': 0, 'fame': 0},
      career: CareerState(),
      branches: {},
      producerLevels: {},
      upgradeLevels: {},
      techniques: [],
      conjectures: [],
      prestige: PrestigeState(),
      trend: TrendState(),
      metodoLevel: 1,
      metodoXp: 0,
      papersInRun: 0,
      settings: Settings(),
      stats: Stats(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'player_name': playerName,
        'saved_at_ms': savedAt.millisecondsSinceEpoch,
        'last_loaded_at_ms': lastLoadedAt.millisecondsSinceEpoch,
        'resources': {
          'counting': resources.counting,
          'proofing': resources.proofing,
          'fame': resources.fame,
        },
        'lifetime': lifetime,
        'career': {
          'stage': career.stage.name,
          'thesis_defended': career.thesisDefended,
          'apprentices': career.apprentices,
        },
        'branches': branches.map((k, v) => MapEntry(k, v.toJson())),
        'active_subject_id': activeSubjectId,
        'producer_levels': producerLevels,
        'upgrade_levels': upgradeLevels,
        'techniques': techniques,
        'conjectures': conjectures.map((c) => c.toJson()).toList(),
        'prestige': prestige.toJson(),
        'trend': trend.toJson(),
        'metodo_level': metodoLevel,
        'metodo_xp': metodoXp,
        'papers_in_run': papersInRun,
        'settings': settings.toJson(),
        'stats': stats.toJson(),
      };

  factory SaveData.fromJson(Map<String, dynamic> json) {
    final raw = migrate(json);
    return SaveData(
      version: raw['version'] as int,
      playerName: raw['player_name'] as String? ?? '',
      savedAt: DateTime.fromMillisecondsSinceEpoch(raw['saved_at_ms'] as int),
      lastLoadedAt: DateTime.fromMillisecondsSinceEpoch(raw['last_loaded_at_ms'] as int),
      resources: Resources(
        counting: (raw['resources']['counting'] as num).toDouble(),
        proofing: (raw['resources']['proofing'] as num).toDouble(),
        fame: (raw['resources']['fame'] as num).toDouble(),
      ),
      lifetime: (raw['lifetime'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      career: CareerState(
        stage: CareerStage.values.byName(raw['career']['stage'] as String),
        thesisDefended: raw['career']['thesis_defended'] as bool,
        apprentices: raw['career']['apprentices'] as int,
      ),
      branches: (raw['branches'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, BranchProgress.fromJson(v as Map<String, dynamic>))),
      activeSubjectId: raw['active_subject_id'] as String? ?? '',
      producerLevels: (raw['producer_levels'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
      upgradeLevels: (raw['upgrade_levels'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
      techniques: (raw['techniques'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      conjectures: (raw['conjectures'] as List<dynamic>? ?? [])
          .map((e) => ConjectureState.fromJson(e as Map<String, dynamic>))
          .toList(),
      prestige: PrestigeState.fromJson(raw['prestige'] as Map<String, dynamic>),
      trend: TrendState.fromJson(raw['trend'] as Map<String, dynamic>),
      metodoLevel: raw['metodo_level'] as int? ?? 1,
      metodoXp: raw['metodo_xp'] as int? ?? 0,
      papersInRun: raw['papers_in_run'] as int? ?? 0,
      settings: Settings.fromJson(raw['settings'] as Map<String, dynamic>),
      stats: Stats.fromJson(raw['stats'] as Map<String, dynamic>),
    );
  }

  /// Migration chain N -> N+1; never skip versions (section 14.4).
  static Map<String, dynamic> migrate(Map<String, dynamic> raw) {
    switch (raw['version'] as int? ?? -1) {
      case currentVersion:
        return raw;
      default:
        // No older schema exists yet (first shipped version is 3).
        throw FormatException('Unsupported save version: ${raw['version']}');
    }
  }
}
