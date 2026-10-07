import '../../domain/models/game_state.dart';
import '../../domain/services/subject_service.dart';

/// One rule modifier for the current prestige cycle (plan section 7).
/// A challenge is entered voluntarily, reshapes the rules while active,
/// and pays out when the player prestigises with it still on. Abandoning
/// early forfeits the reward. Each challenge can be completed once.
class ChallengeDef {
  final String id;
  final String name;
  final String description;

  /// Encrypted Run stays sealed until Cryptography is completed (§3).
  final bool requiresCryptography;

  /// Flat Legacy points granted on completion.
  final int legacyOnComplete;

  /// Cosmetic title granted on completion (null = none).
  final String? title;

  /// Permanent global production multiplier granted on completion (1 = none).
  final double globalMultOnComplete;

  const ChallengeDef({
    required this.id,
    required this.name,
    required this.description,
    this.requiresCryptography = false,
    this.legacyOnComplete = 0,
    this.title,
    this.globalMultOnComplete = 1,
  });

  /// Player-facing summary of the completion reward.
  String get rewardSummary {
    final parts = <String>[
      '+$legacyOnComplete Legacy',
      if (title != null) '"$title" title',
      if (globalMultOnComplete > 1)
        '+${((globalMultOnComplete - 1) * 100).round()}% all production',
    ];
    return parts.join(', ');
  }
}

class ChallengeService {
  const ChallengeService();

  static const String constructivistRun = 'constructivist_run';
  static const String noPaperRun = 'no_paper_run';
  static const String encryptedRun = 'encrypted_run';

  static const Map<String, ChallengeDef> catalog = {
    constructivistRun: ChallengeDef(
      id: constructivistRun,
      name: 'Constructivist Run',
      description: 'Your laboratory runs lean: passive production drops by half, but your own papers earn double Fame.',
      legacyOnComplete: 25,
      title: 'The Constructivist',
    ),
    noPaperRun: ChallengeDef(
      id: noPaperRun,
      name: 'No-Paper Run',
      description: 'You never submit another paper — the desk closes. Every solved exercise earns +5 Fame directly instead.',
      legacyOnComplete: 50,
      title: 'Oral Tradition',
    ),
    encryptedRun: ChallengeDef(
      id: encryptedRun,
      name: 'Encrypted Run',
      description: 'Work in secret: stress builds twice as fast, but prestigising yields double Eredità.',
      requiresCryptography: true,
      legacyOnComplete: 100,
      title: 'Cipher Keeper',
      globalMultOnComplete: 1.05,
    ),
  };

  /// Flat Fame per manual exercise while the No-Paper Run is active.
  static const double clickFameNoPaper = 5;

  final SubjectService _subjects = const SubjectService();

  ChallengeDef? def(String id) => catalog[id];

  bool isActive(GameState s, String id) => s.activeChallenge == id;

  bool unlocked(GameState s, String id) {
    final d = catalog[id];
    if (d == null) return false;
    if (!d.requiresCryptography) return true;
    return _subjects.isCompleted(s, 'cryptography');
  }

  /// Starts a challenge; one at a time, each completable only once.
  bool enter(GameState s, String id) {
    final d = catalog[id];
    if (d == null || !unlocked(s, id)) return false;
    if (s.completedChallenges.contains(id)) return false;
    if (s.activeChallenge.isNotEmpty) return false;
    s.activeChallenge = id;
    return true;
  }

  void abandon(GameState s) => s.activeChallenge = '';

  /// Applies the completion rewards right before the prestige reset and
  /// clears the slot. Returns the definition that just completed, or null.
  ChallengeDef? completeAtPrestige(GameState s) {
    final d = catalog[s.activeChallenge];
    if (d == null) return null;
    // Rewards pay exactly once per account, even if re-entered somehow.
    if (!s.completedChallenges.contains(d.id)) {
      s.completedChallenges.add(d.id);
      if (d.title != null && !s.titles.contains(d.title!)) {
        s.titles.add(d.title!);
      }
      s.prestige.legacy += d.legacyOnComplete;
      s.prestige.legacyAllTime += d.legacyOnComplete;
      s.challengeGlobalMult *= d.globalMultOnComplete;
    }
    s.activeChallenge = '';
    return d;
  }

  // ------------------------------------------------------- rule modifiers

  /// Passive (lab) output factor: the Constructivist lab runs lean.
  double passiveProductionFactor(GameState s) =>
      isActive(s, constructivistRun) ? 0.5 : 1.0;

  /// Paper Fame factor: hand-written results carry extra weight.
  double paperFameFactor(GameState s) =>
      isActive(s, constructivistRun) ? 2.0 : 1.0;

  /// Stress accumulation factor: secrecy has a cost.
  double stressFactor(GameState s) => isActive(s, encryptedRun) ? 2.0 : 1.0;

  /// Prestige Legacy conversion multiplier.
  double prestigeLegacyFactor(GameState s) =>
      isActive(s, encryptedRun) ? 2.0 : 1.0;

  /// Flat Fame granted per manual exercise (0 outside the No-Paper Run).
  double clickFame(GameState s) =>
      isActive(s, noPaperRun) ? clickFameNoPaper : 0;

  /// New papers cannot be started during the No-Paper Run.
  bool blocksNewPapers(GameState s) => isActive(s, noPaperRun);
}
