import '../../domain/models/career.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/producers.dart';
import '../../utils/number_format.dart';

/// Career stage thresholds (plan section 13.8). Gates use cumulative Fame
/// earned over the whole run — it never resets inside a cycle.
class CareerSystem {
  static const double phdFameThreshold = 1000;
  static const double thesisCostProofing = 500;
  static const double postdocFameThreshold = 25000;
  static const double professorFameThreshold = 500000;

  /// Papers grant reduced Fame until the thesis is defended (§5: "Tesi da
  /// difendere prima che i paper dino Fame piena"). v0: half Fame.
  static double paperFameFactor(CareerState c) => c.thesisDefended ? 1.0 : 0.5;

  /// One-line progress hint toward the next stage ('' when none applies).
  static String nextStageHint(GameState s) {
    switch (s.career.stage) {
      case CareerStage.student:
        return s.career.thesisDefended
            ? ''
            : 'PhD: defend your thesis once lifetime Fame reaches '
                '${formatNumber(phdFameThreshold)}.';
      case CareerStage.phd:
        return 'Postdoc at ${formatNumber(postdocFameThreshold)} lifetime Fame '
            '(${formatNumber(s.lifetimeOf(ResourceKind.fame))} so far).';
      case CareerStage.postdoc:
        return 'Professor at ${formatNumber(professorFameThreshold)} lifetime Fame '
            '(${formatNumber(s.lifetimeOf(ResourceKind.fame))} so far).';
      case CareerStage.professor:
        // Apprentices arrive with phase 4 automation.
        return '';
    }
  }

  /// Thesis defense becomes available once the PhD Fame threshold is met.
  bool canDefendThesis(GameState s) =>
      s.career.stage == CareerStage.student &&
      !s.career.thesisDefended &&
      s.lifetimeOf(ResourceKind.fame) >= phdFameThreshold;

  /// Attempts the one-time thesis defense (500 P). Returns true on success.
  bool tryDefendThesis(GameState s) {
    if (!canDefendThesis(s)) return false;
    if (!s.resources.spend(0, thesisCostProofing)) return false;
    s.career.thesisDefended = true;
    update(s);
    return true;
  }

  /// Applies automatic promotions that need no player action.
  void update(GameState s) {
    switch (s.career.stage) {
      case CareerStage.student:
        if (s.career.thesisDefended &&
            s.lifetimeOf(ResourceKind.fame) >= phdFameThreshold) {
          s.career.stage = CareerStage.phd;
        }
      case CareerStage.phd:
        if (s.lifetimeOf(ResourceKind.fame) >= postdocFameThreshold) {
          s.career.stage = CareerStage.postdoc;
        }
      case CareerStage.postdoc:
        if (s.lifetimeOf(ResourceKind.fame) >= professorFameThreshold) {
          s.career.stage = CareerStage.professor;
        }
      case CareerStage.professor:
        break;
    }
  }
}
