import '../../domain/models/career.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/producers.dart';

/// Career stage thresholds (plan section 13.8). Gates use cumulative Fame
/// earned over the whole run — it never resets inside a cycle.
class CareerSystem {
  static const double phdFameThreshold = 1000;
  static const double thesisCostProofing = 500;
  static const double postdocFameThreshold = 25000;
  static const double professorFameThreshold = 500000;

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
