import 'dart:math';

import '../../domain/models/career.dart';
import '../../domain/models/conjecture.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/producers.dart';
import '../../domain/models/resources.dart';
import '../../domain/models/save_data.dart';

/// Historical mathematicians contactable with Legacy points (section 6 /
/// 13.9). Each hire is permanent across prestiges and fires its lore
/// letter once.
class MathematicianDef {
  final String id;
  final String name;
  final int cost;
  final String perk;
  final String lore;

  const MathematicianDef({
    required this.id,
    required this.name,
    required this.cost,
    required this.perk,
    required this.lore,
  });
}

const List<MathematicianDef> mathematicians = [
  MathematicianDef(
    id: 'gauss',
    name: 'Gauss',
    cost: 10,
    perk: 'Counting ×2',
    lore: '"Your exercises remind me of my own youth. Keep counting."',
  ),
  MathematicianDef(
    id: 'noether',
    name: 'Noether',
    cost: 50,
    perk: 'Proofing ×2 in algebraic branches',
    lore: '"Invariance first. Your algebraic proofs will thank you."',
  ),
  MathematicianDef(
    id: 'ramanujan',
    name: 'Ramanujan',
    cost: 200,
    perk: '+10% conjecture success, 5% insight flash per session',
    lore: '"The equations are gifts, Professor. So are the failures."',
  ),
  MathematicianDef(
    id: 'euler',
    name: 'Euler',
    cost: 500,
    perk: 'Citation Fame ×2',
    lore: '"Publish boldly. Citations follow the brave."',
  ),
];

MathematicianDef? mathematicianById(String id) =>
    mathematicians.where((m) => m.id == id).firstOrNull;

/// Branches Noether considers algebraic for her proofing perk.
const Set<String> algebraicBranchIds = {
  'discrete_algebra',
  'abstract_algebra',
  'algebraic_geometry',
  'algebraic_topology',
};

/// Prestige reboot logic (plan sections 6 and 13.9):
/// Eredità guadagnata = floor(sqrt(Fame_al_prestige / 100)); every lifetime
/// point permanently boosts all production by 2%.
class PrestigeService {
  const PrestigeService();

  static const double legacyPointMult = 0.02; // +2% per lifetime point
  static const int minLegacyForPrestige =
      10; // first prestige milestone (§13.11)

  /// Legacy earned by prestigising right now. Lifetime Fame resets with
  /// the run, so the formula reads directly off the current total.
  int legacyGain(GameState s) =>
      (sqrt(max(0.0, s.lifetimeOf(ResourceKind.fame)) / 100)).floor();

  bool canPrestige(GameState s) => legacyGain(s) >= minLegacyForPrestige;

  /// Permanent multiplier applied to every production channel.
  double productionMultiplier(GameState s) =>
      1 + legacyPointMult * s.prestige.legacyAllTime;

  bool hasMathematician(GameState s, String id) =>
      s.prestige.mathematicians.contains(id);

  /// Spends Legacy on a mathematician; returns true when hired.
  bool hireMathematician(GameState s, String id) {
    final def = mathematicianById(id);
    if (def == null || hasMathematician(s, id)) return false;
    if (s.prestige.legacy < def.cost) return false;
    s.prestige.legacy -= def.cost;
    s.prestige.mathematicians.add(id);
    return true;
  }

  /// Reboots the run. Persists: Legacy bank, mathematicians, Metodo level,
  /// proven conjectures (and their multipliers), cosmetics, stats, name.
  /// [legacyFactor] scales the conversion (Encrypted Run, section 7).
  void applyPrestige(GameState s, [double legacyFactor = 1]) {
    if (!canPrestige(s)) return;
    final gain = (legacyGain(s) * legacyFactor).round();
    s.prestige.legacy += gain;
    s.prestige.legacyAllTime += gain;
    s.prestige.prestigesCount++;

    // What resets (section 13.9): balances, producers, upgrades, branches,
    // active/refuted conjectures, trends, career stage.
    s.resources = Resources();
    s.lifetime = {'counting': 0, 'proofing': 0, 'fame': 0};
    s.career = CareerState();
    s.branches = {};
    s.activeSubjectId = '';
    s.producerLevels = {};
    s.upgradeLevels = {};
    s.techniques = {};
    s.conjectures.removeWhere((c) => c.status != ConjectureStatus.proven);
    s.trend = TrendState();
    s.stress = 0;
    s.burnedOutUntil = null;
    s.scheduledRetractions = [];
    s.papersInRun = 0;
    s.activePapers.clear();
  }
}
