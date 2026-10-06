import 'producers.dart';

/// Repeatable upgrades with exponential cost (sections 13.1-13.2, 13.5).
class UpgradeDef {
  final String id;
  final String name;
  final String description;
  final ResourceKind currency;
  final double baseCost;
  final double growth;
  final int maxLevel; // -1 = unlimited

  const UpgradeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.currency,
    required this.baseCost,
    required this.growth,
    this.maxLevel = -1,
  });
}

const List<UpgradeDef> upgradeCatalogList = [
  // Click power: +100% per level, cost 100 x 1.6^n (section 13.2).
  UpgradeDef(
    id: 'study_tools',
    name: 'Study tools',
    description: '+100% click power per level',
    currency: ResourceKind.counting,
    baseCost: 100,
    growth: 1.6,
  ),
  // Cross-upgrades / trade-offs (section 2 and 13.5): each boosts a resource
  // other than the one it costs, so choices compete.
  UpgradeDef(
    id: 'scholarship',
    name: 'Scholarship',
    description: '+50% Counting production per level',
    currency: ResourceKind.proofing,
    baseCost: 500,
    growth: 1.3,
  ),
  UpgradeDef(
    id: 'collaborator',
    name: 'Collaborator',
    description: '+50% Proofing production per level',
    currency: ResourceKind.fame,
    baseCost: 250,
    growth: 1.35,
  ),
  UpgradeDef(
    id: 'seminar',
    name: 'Seminar',
    description: '+50% Fame per level',
    currency: ResourceKind.counting,
    baseCost: 2000,
    growth: 1.3,
  ),
];

final Map<String, UpgradeDef> upgradeCatalog = {
  for (final u in upgradeCatalogList) u.id: u,
};
