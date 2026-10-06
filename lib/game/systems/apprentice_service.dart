import '../../domain/models/career.dart';
import '../../domain/models/game_state.dart';

/// One hireable laboratory member (plan sections 5, 13.8). Apprentices are
/// narrated automation: each adds a fixed stream of Counting once hired.
/// They are recruited one by one, in order, up to [ApprenticeService.max].
class ApprenticeDef {
  /// 1-based position in the hiring order.
  final int index;
  final String name;
  final String bio;
  final double costCounting;
  final double costProofing;
  final double costFame;
  /// Flat Counting per second contributed while employed.
  final double countingPerSec;

  const ApprenticeDef({
    required this.index,
    required this.name,
    required this.bio,
    required this.costCounting,
    required this.costProofing,
    required this.costFame,
    required this.countingPerSec,
  });
}

class ApprenticeService {
  const ApprenticeService();

  static const int max = 5;

  /// The growing laboratory, in hiring order (section 5 flavor table).
  static const List<ApprenticeDef> catalog = [
    ApprenticeDef(
      index: 1,
      name: 'María',
      bio: 'First-year PhD student who re-checks every computation by hand.',
      costCounting: 25e3,
      costProofing: 10e3,
      costFame: 500,
      countingPerSec: 5,
    ),
    ApprenticeDef(
      index: 2,
      name: 'Kenji',
      bio: 'Master’s student automating your exercise pipelines.',
      costCounting: 100e3,
      costProofing: 50e3,
      costFame: 2500,
      countingPerSec: 15,
    ),
    ApprenticeDef(
      index: 3,
      name: 'Sofia',
      bio: 'Postdoc leading the numerical methods group.',
      costCounting: 400e3,
      costProofing: 200e3,
      costFame: 10e3,
      countingPerSec: 45,
    ),
    ApprenticeDef(
      index: 4,
      name: 'Amara',
      bio: 'Visiting researcher bringing her own cohort of students.',
      costCounting: 1.6e6,
      costProofing: 800e3,
      costFame: 40e3,
      countingPerSec: 135,
    ),
    ApprenticeDef(
      index: 5,
      name: 'Viktor',
      bio: 'Senior fellow running a parallel seminar line under your name.',
      costCounting: 6.4e6,
      costProofing: 3.2e6,
      costFame: 160e3,
      countingPerSec: 405,
    ),
  ];

  /// The next apprentice to hire, or null when the lab is full.
  ApprenticeDef? nextHire(int owned) =>
      owned < max ? catalog[owned] : null;

  /// Only professors may run a laboratory (sections 5, 13.8).
  bool canHire(GameState s) =>
      s.career.stage == CareerStage.professor &&
      s.career.apprentices < max;

  /// Total flat Counting per second from the current headcount.
  double outputOf(int owned) {
    var out = 0.0;
    for (var i = 0; i < owned && i < catalog.length; i++) {
      out += catalog[i].countingPerSec;
    }
    return out;
  }

  /// Pays the costs and grows the headcount; returns the new hire, or null.
  ApprenticeDef? hire(GameState s) {
    if (!canHire(s)) return null;
    final def = catalog[s.career.apprentices];
    if (!s.resources.spend(def.costCounting, def.costProofing, def.costFame)) {
      return null;
    }
    s.career.apprentices++;
    return def;
  }
}
