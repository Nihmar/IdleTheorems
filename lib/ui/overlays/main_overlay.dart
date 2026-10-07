import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:katex/katex.dart';

import '../../domain/models/career.dart';
import '../../domain/models/conjecture.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/producers.dart';
import '../../domain/models/resources.dart';
import '../../domain/models/subject.dart';
import '../../domain/models/upgrade.dart';
import '../../domain/services/balance_service.dart';
import '../../domain/services/offline_service.dart';
import '../../domain/services/subject_service.dart';
import '../../game/systems/apprentice_service.dart';
import '../../game/systems/career_system.dart';
import '../../game/systems/challenge_service.dart';
import '../../game/systems/conjecture_system.dart';
import '../../game/systems/friction_system.dart';
import '../../game/systems/prestige_service.dart';
import '../../game/systems/trend_service.dart';
import '../../game/systems/production_system.dart';
import '../../providers/game_state_provider.dart';
import '../../utils/number_format.dart';
import '../theme/palette.dart';
import '../widgets/resource_counter.dart';
import '../widgets/shop_card.dart';

/// Chalk formulas scribbled on the board, rendered with real KaTeX.
const List<(String, double, double)> _chalkFormulas = [
  (r'\int_0^\infty e^{-x^2}\,dx = \sqrt{\pi}', 0.08, 0.30),
  (r'a^{2} + b^{2} = c^{2}', 0.66, 0.27),
  (r'P(A \mid B) = \frac{P(B \mid A)\,P(A)}{P(B)}', 0.25, 0.52),
  (r'\zeta(s) = \sum_{n=1}^{\infty} n^{-s}', 0.68, 0.55),
  (r'e^{i\pi} + 1 = 0', 0.10, 0.78),
  (r'F = m \cdot a', 0.58, 0.80),
];

/// Derives the current guided hint for "The first semester" onboarding
/// (plan section 8). Stateless: progress is read from game state directly.
String? onboardingHint(GameState s) {
  if (s.stats.totalClicks == 0) {
    return 'Tap the board to solve your first exercise.';
  }
  var producersOwned = countingProducers.fold<int>(
    0,
    (acc, p) => acc + (s.producerLevels[p.id] ?? 0),
  );
  if (producersOwned == 0) {
    return 'Open the shop and buy Guided exercises to automate Counting.';
  }
  if (!s.techniques.contains('elementary_formalization')) {
    return 'Learn Elementary formalization in the shop to start producing Proofing.';
  }
  if (s.papersInRun == 0 && s.activePapers.isEmpty) {
    return 'Publish your first paper in the shop to earn Fame.';
  }
  return null;
}

/// Root Flutter overlay: HUD counters, career chip, onboarding banner,
/// bottom action bar and the research shop panel.
/// Confirmation dialog for the prestige reboot.
void _confirmPrestige(BuildContext context, int gain, VoidCallback doIt) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Begin a new chapter?'),
      content: Text(
        'Lifetime Fame converts into $gain Eredità. Producers, branches, '
        'upgrades, trends and active conjectures all reset.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            doIt();
          },
          child: const Text('Prestige'),
        ),
      ],
    ),
  );
}

class MainOverlay extends ConsumerWidget {
  const MainOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameStateProvider);
    final rates = const ProductionSystem().compute(
      s,
      const SubjectService().modifiers(s),
    );
    final services = const SubjectService();
    final trendSvc = const TrendService();
    final focusDef = s.activeSubjectId.isEmpty
        ? null
        : subjectCatalog[s.activeSubjectId];
    final lastAwayReport = ref.watch(gameStateProvider.notifier).lastAwayReport;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            // Decorative chalk formulas (real TeX).
            for (final (tex, fx, fy) in _chalkFormulas)
              Positioned(
                left: fx * w,
                top: fy * h,
                child: Math(tex, color: Palette.ink, fontSize: 17),
              ),
            // Top HUD.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Idle Theorems',
                            style: TextStyle(
                              color: Palette.accent,
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'serif',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (s.playerName.isNotEmpty)
                                    _Chip(
                                      label: s.playerName,
                                      icon: Icons.badge_outlined,
                                    ),
                                  const SizedBox(width: 8),
                                  _Chip(
                                    label: s.career.stage.label,
                                    icon: Icons.school_outlined,
                                  ),
                                  const SizedBox(width: 8),
                                  _Chip(
                                    label: 'Metodo Lv ${s.metodoLevel}',
                                    icon: Icons.psychology_alt,
                                  ),
                                  for (final title in s.titles)
                                    _Chip(
                                      label: title,
                                      icon: Icons.emoji_events,
                                    ),
                                  if (focusDef != null) ...[
                                    const SizedBox(width: 8),
                                    _Chip(
                                      label:
                                          '${focusDef.name} ${services.theoremsOf(s, focusDef.id)}/${masteryNeeded(focusDef.level)}',
                                      icon: Icons.category_outlined,
                                    ),
                                  ],
                                  if (trendSvc.isActive(s)) ...[
                                    const SizedBox(width: 8),
                                    _Chip(
                                      label:
                                          'Trend: ${subjectCatalog[s.trend.activeSubject]?.name ?? ''}'
                                          ' · ${s.trend.endsAt!.difference(DateTime.now()).inHours}h',
                                      icon: Icons.trending_up,
                                    ),
                                  ],
                                  if (trendSvc.shouldAnnounceNext(s)) ...[
                                    const SizedBox(width: 8),
                                    _Chip(
                                      label:
                                          'Up next: ${subjectCatalog[s.trend.nextSubject]?.name ?? ''}',
                                      icon: Icons.schedule,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ResourceCounter(
                              label: 'Counting',
                              icon: Icons.edit_note,
                              value: s.resources.counting,
                              perSecond: rates.countingPerSec,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ResourceCounter(
                              label: 'Proofing',
                              icon: Icons.menu_book,
                              value: s.resources.proofing,
                              perSecond: rates.proofingPerSec,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ResourceCounter(
                              label: 'Fame',
                              icon: Icons.star,
                              value: s.resources.fame,
                              perSecond: rates.famePerSec,
                            ),
                          ),
                        ],
                      ),
                      if (lastAwayReport != null) ...[
                        const SizedBox(height: 8),
                        _AwayBanner(
                          report: lastAwayReport,
                          onDismiss: () => ref
                              .read(gameStateProvider.notifier)
                              .dismissAwayReport(),
                        ),
                      ],
                      if (s.transientNotice != null ||
                          const FrictionSystem().isBurnedOut(s) ||
                          s.stress > 0.1 ||
                          s.activeChallenge.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (const FrictionSystem().isBurnedOut(s))
                              _Chip(
                                label: 'Burned out',
                                icon: Icons.battery_alert,
                              ),
                            if (!const FrictionSystem().isBurnedOut(s) &&
                                s.stress > 0.1)
                              _Chip(
                                label: 'Stressed ${(s.stress * 100).round()}%',
                                icon: Icons.sentiment_dissatisfied,
                              ),
                            if (s.activeChallenge.isNotEmpty)
                              _Chip(
                                label: ChallengeService
                                    .catalog[s.activeChallenge]!
                                    .name,
                                icon: Icons.verified_outlined,
                              ),
                            if (s.transientNotice != null)
                              Expanded(
                                child: Text(
                                  s.transientNotice!,
                                  style: const TextStyle(
                                    color: Palette.accent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (onboardingHint(s) != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Palette.accent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_outline,
                                size: 16,
                                color: Palette.accent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  onboardingHint(s)!,
                                  style: const TextStyle(
                                    color: Palette.ink,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Bottom action bar + slide-up research shop.
            Positioned(left: 0, right: 0, bottom: 0, child: _BottomBar(h: h)),
            // First launch: pick your mathematician's name. Blocks the board.
            if (s.playerName.isEmpty)
              const Positioned.fill(child: _NameEntryPanel()),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Palette.inkSoft),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Palette.ink, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Slide-up research shop panel plus the bottom action bar
/// (solve button + shop toggle). Owns the open/closed state of the shop.
class _BottomBar extends ConsumerStatefulWidget {
  const _BottomBar({required this.h});

  final double h;

  @override
  ConsumerState<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends ConsumerState<_BottomBar> {
  bool _shopOpen = false;
  String _tab = 'shop'; // 'shop' | 'subjects' | 'conjectures'

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameStateProvider);
    final balance = const BalanceService();
    final services = const SubjectService();
    final mods = services.modifiers(s);
    final maxSlots = services.maxConcurrentPapers(s);
    final maxDiscoveries = services.maxActiveConjectures(s);
    final papersInProgress = s.activePapers.length;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: _shopOpen ? widget.h * 0.72 : 0,
            decoration: BoxDecoration(
              color: Palette.surfaceAlt,
              border: Border(top: BorderSide(color: Palette.border)),
            ),
            child: _shopOpen
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Row(
                        children: [
                          Text(
                            _tab == 'shop'
                                ? 'Research shop'
                                : _tab == 'subjects'
                                ? 'Subject tree'
                                : 'Conjectures',
                            style: const TextStyle(
                              color: Palette.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          _TabButton(
                            label: 'Shop',
                            selected: _tab == 'shop',
                            onTap: () => setState(() => _tab = 'shop'),
                          ),
                          const SizedBox(width: 6),
                          _TabButton(
                            label: 'Subjects',
                            selected: _tab == 'subjects',
                            onTap: () => setState(() => _tab = 'subjects'),
                          ),
                          const SizedBox(width: 6),
                          _TabButton(
                            label: 'Conjectures',
                            selected: _tab == 'conjectures',
                            onTap: () => setState(() => _tab = 'conjectures'),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _shopOpen = false),
                            icon: const Icon(
                              Icons.close,
                              color: Palette.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_tab == 'shop') ...[
                        if (CareerSystem.nextStageHint(s).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              CareerSystem.nextStageHint(s),
                              style: const TextStyle(
                                color: Palette.inkSoft,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        _sectionHeader('Legacy'),
                        Row(
                          children: [
                            Text(
                              'Eredità ${s.prestige.legacy}',
                              style: const TextStyle(
                                color: Palette.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '+${((const PrestigeService().productionMultiplier(s) - 1) * 100).toStringAsFixed(0)}% production',
                              style: const TextStyle(
                                color: Palette.inkSoft,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        ShopCard(
                          name: 'Prestige',
                          description:
                              'Reboot the run for ${ref.read(gameStateProvider.notifier).legacyGainNow} Eredità. Keeps Metodo level, proven conjectures and mathematicians.',
                          costLabel:
                              'Needs ${PrestigeService.minLegacyForPrestige}+ from this run',
                          canAfford: const PrestigeService().canPrestige(s),
                          onBuy: () => _confirmPrestige(
                            context,
                            ref.read(gameStateProvider.notifier).legacyGainNow,
                            () =>
                                ref.read(gameStateProvider.notifier).prestige(),
                          ),
                        ),
                        for (final m in mathematicians)
                          ShopCard(
                            name: m.name,
                            description: m.perk,
                            costLabel: s.prestige.mathematicians.contains(m.id)
                                ? 'Hired'
                                : '${m.cost} Eredità',
                            canAfford:
                                !s.prestige.mathematicians.contains(m.id) &&
                                s.prestige.legacy >= m.cost,
                            onBuy: () => ref
                                .read(gameStateProvider.notifier)
                                .hireMathematician(m.id),
                          ),
                        _sectionHeader('Counting'),
                        for (final p in countingProducers) _producerRow(p),
                        _sectionHeader('Techniques (one-time)'),
                        for (final t in techniqueCatalogList)
                          ShopCard(
                            name: t.name,
                            description: t.description,
                            costLabel: s.techniques.contains(t.id)
                                ? 'Owned'
                                : formatCost(
                                    t.costCounting,
                                    ResourceKind.counting,
                                  ),
                            canAfford:
                                !s.techniques.contains(t.id) &&
                                s.resources.canAfford(t.costCounting),
                            onBuy: () => ref
                                .read(gameStateProvider.notifier)
                                .buyTechnique(t.id),
                          ),
                        _sectionHeader('Proofing'),
                        for (final p in proofingProducers) _producerRow(p),
                        _sectionHeader('Upgrades'),
                        for (final u in upgradeCatalogList)
                          _upgradeRow(u, mods.upgradeCostFactor),
                        _sectionHeader('Laboratory'),
                        _laboratoryRow(s),
                        _sectionHeader('Challenges'),
                        for (final def in ChallengeService.catalog.values)
                          _challengeCard(def, s),
                        _sectionHeader('Publication desk'),
                        _paperDeskRow(
                          balance,
                          mods.paperCostFactor,
                          maxSlots,
                          papersInProgress,
                        ),
                        if (CareerSystem().canDefendThesis(s))
                          ShopCard(
                            name: 'Defend thesis',
                            description:
                                'Advance to PhD (requires 1K cumulative Fame).',
                            costLabel: formatCost(
                              CareerSystem.thesisCostProofing,
                              ResourceKind.proofing,
                            ),
                            canAfford: s.resources.canAfford(
                              0,
                              CareerSystem.thesisCostProofing,
                            ),
                            onBuy: () => ref
                                .read(gameStateProvider.notifier)
                                .defendThesis(),
                          ),
                        if (s.stress > 0 ||
                            const FrictionSystem().isBurnedOut(s))
                          ShopCard(
                            name: 'Sabbatical',
                            description: 'Take a break: clears all stress instantly (costs 10% of current Fame).',
                            costLabel: formatCost(
                              s.resources.fame *
                                  FrictionSystem.sabbaticalCostFraction,
                              ResourceKind.fame,
                            ),
                            canAfford: s.resources.fame > 0,
                            onBuy: () => ref
                                .read(gameStateProvider.notifier)
                                .takeSabbatical(),
                          ),
                      ] else if (_tab == 'conjectures') ...[
                        _sectionHeader('Discovery'),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Formulate in completed fields, fund work sessions, roll at 100%. Failing teaches Metodo — and half the progress survives. Max $maxDiscoveries active discoveries.',
                            style: const TextStyle(
                              color: Palette.inkSoft,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                        for (final def in conjecturesByTier().where(
                          (d) => !d.isEndgame,
                        ))
                          _conjectureRow(def),
                        _sectionHeader('Frontiers'),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'The great open problems. Sealed until you reach Professor — then they wait forever.',
                            style: TextStyle(
                              color: Palette.inkSoft,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                        for (final def in conjecturesByTier().where(
                          (d) => d.isEndgame,
                        ))
                          _conjectureRow(def),
                      ] else ...[
                        _sectionHeader('Your fields of study'),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Focus a subject: every accepted paper masters one theorem inside it. Mastering a field activates its effect and unlocks the fields that build on it.',
                            style: TextStyle(
                              color: Palette.inkSoft,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                        for (final def in subjectsByLevel())
                          _subjectRow(def, services, s),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        ref.read(gameStateProvider.notifier).solveExercise(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.action,
                      foregroundColor: Palette.paper,
                      minimumSize: const Size(0, 48),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    icon: const Icon(Icons.edit_note),
                    label: Text(
                      'Solve exercise (+${formatNumber(balance.clickPower(s.levelOf('study_tools')) * mods.clickMultiplier * mods.globalResourceMult)})',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _shopOpen = !_shopOpen),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.ink,
                    side: BorderSide(color: Palette.border),
                    minimumSize: const Size(110, 48),
                  ),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Shop'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _producerRow(ProducerDef p) {
    final owned = ref.read(gameStateProvider).levelOf(p.id);
    final cost = const BalanceService().producerCost(p, owned);
    return ShopCard(
      name: p.name,
      description: p.description,
      owned: owned,
      costLabel: formatCost(cost, p.currency),
      canAfford: ref
          .read(gameStateProvider)
          .resources
          .canAffordOf(p.currency, cost),
      onBuy: () => ref.read(gameStateProvider.notifier).buyProducer(p.id),
    );
  }

  Widget _upgradeRow(UpgradeDef u, double discount) {
    final owned = ref.read(gameStateProvider).levelOf(u.id);
    final cost = const BalanceService().upgradeCost(u, owned) * discount;
    return ShopCard(
      name: u.name,
      description: u.description,
      owned: owned,
      costLabel: formatCost(cost, u.currency),
      canAfford: ref
          .read(gameStateProvider)
          .resources
          .canAffordOf(u.currency, cost),
      onBuy: () => ref.read(gameStateProvider.notifier).buyUpgrade(u.id),
    );
  }

  Widget _paperDeskRow(
    BalanceService balance,
    double discount,
    int maxSlots,
    int busy,
  ) {
    final s = ref.watch(gameStateProvider);
    final allBusy = busy >= maxSlots;
    final cost = balance.paperCost(s.papersInRun) * discount;
    return ShopCard(
      name: 'Publish paper ($busy/$maxSlots slots)',
      description: allBusy
          ? 'All writing slots are busy — wait for a review outcome.'
          : '~60s writing, then peer review. Fame on acceptance.',
      costLabel: formatCost(cost, ResourceKind.proofing),
      canAfford: !allBusy && s.resources.canAfford(0, cost),
      onBuy: () => ref.read(gameStateProvider.notifier).startPaper(),
    );
  }

  Widget _subjectRow(SubjectDef def, SubjectService svc, GameState s) {
    final done = svc.isCompleted(s, def.id);
    final unlocked = svc.isUnlocked(s, def.id);
    final focused = svc.isActive(s, def.id);
    final mastered = svc.theoremsOf(s, def.id);
    final need = masteryNeeded(def.level);
    final missing = svc
        .missingPrereqs(s, def.id)
        .map((id) => subjectCatalog[id]?.name ?? id)
        .join(', ');
    late final String status;
    late final Color statusColor;
    if (done) {
      status = 'Mastered';
      statusColor = Palette.accent;
    } else if (!unlocked) {
      status = 'Locked — needs $missing';
      statusColor = Palette.inkFaint;
    } else if (focused) {
      status = 'Focused — $mastered/$need theorems';
      statusColor = Palette.accent;
    } else {
      status = '$mastered/$need theorems';
      statusColor = Palette.inkSoft;
    }
    final enabled = unlocked && !done;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: focused
            ? Palette.accent.withValues(alpha: 0.12)
            : Palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: focused
              ? Palette.accent.withValues(alpha: 0.8)
              : Palette.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  final n = ref.read(gameStateProvider.notifier);
                  if (focused) {
                    n.clearFocus();
                  } else {
                    n.focusSubject(def.id);
                  }
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle
                      : unlocked
                      ? Icons.category_outlined
                      : Icons.lock_outline,
                  size: 20,
                  color: statusColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.name,
                        style: TextStyle(
                          color: unlocked || done
                              ? Palette.ink
                              : Palette.inkSoft,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        def.effectText,
                        style: const TextStyle(
                          color: Palette.inkSoft,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conjectureRow(ConjectureDef def) {
    final s = ref.watch(gameStateProvider);
    final svc = ConjectureSystem();
    final st = svc.stateOf(s, def.id);
    final missing = svc.missingSubjects(s, def.id);
    final endgameLocked = svc.endgameLocked(s, def);
    final careerLocked =
        !endgameLocked && s.career.stage.index < CareerStage.postdoc.index;
    final proven = st?.status == ConjectureStatus.proven;
    final cooling = st?.status == ConjectureStatus.refuted;
    final active = st?.status == ConjectureStatus.active;

    late final String statusText;
    late final Color statusColor;
    if (proven) {
      statusText = 'Proven · ${def.rewardSummary}';
      statusColor = Palette.accent;
    } else if (cooling) {
      statusText =
          'Refuted · retry in ${_fmtCooldown(st!.readyAt!)} (${st.progress.toStringAsFixed(0)}% kept)';
      statusColor = Palette.inkSoft;
    } else if (active) {
      statusText = '${st!.progress.toStringAsFixed(0)}% done';
      statusColor = Palette.accent;
    } else if (endgameLocked) {
      statusText = 'Unlocks at Professor';
      statusColor = Palette.inkFaint;
    } else if (careerLocked) {
      statusText = 'Unlocks at Postdoc';
      statusColor = Palette.inkFaint;
    } else if (missing.isNotEmpty) {
      statusText =
          'Needs: ${missing.map((id) => subjectCatalog[id]?.name ?? id).join(', ')}';
      statusColor = Palette.inkFaint;
    } else {
      statusText = '';
      statusColor = Palette.inkSoft;
    }

    final branches = def.subjects
        .map((id) => subjectCatalog[id]?.name ?? id)
        .join(', ');
    final subLine = [
      'Tier ${def.tier}${def.isEndgame ? ' · open problem' : ''}',
      branches,
      'Reward: ${def.rewardSummary}',
    ].join('  ·  ');

    final canStart =
        !proven && !cooling && !active && svc.canFormulate(s, def.id);
    final slotsFree = svc.slotsAvailable(s, def.id);
    final formCost = _costLabel(
      def.formulation.counting,
      def.formulation.proofing,
      def.formulation.fame,
    );
    final workCost = _costLabel(
      def.workPerSession.counting,
      def.workPerSession.proofing,
      def.workPerSession.fame,
    );
    final n = ref.read(gameStateProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: proven ? Palette.surfaceAlt : Palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: proven
              ? Palette.accent.withValues(alpha: 0.8)
              : Palette.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  proven
                      ? Icons.verified
                      : cooling
                      ? Icons.hourglass_bottom
                      : active
                      ? Icons.edit_note
                      : Icons.science_outlined,
                  size: 20,
                  color: statusColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.name,
                        style: const TextStyle(
                          color: Palette.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subLine,
                        style: const TextStyle(
                          color: Palette.inkSoft,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    statusText,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (active && st != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: st.progress / 100,
                  minHeight: 6,
                  backgroundColor: Palette.surfaceAlt,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Palette.action,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed:
                      s.resources.canAfford(
                        def.workPerSession.counting,
                        def.workPerSession.proofing,
                        def.workPerSession.fame,
                      )
                      ? () => n.workOnConjecture(def.id)
                      : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    foregroundColor: Palette.ink,
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text('Work session ($workCost)'),
                ),
              ),
            ],
            if (canStart) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed:
                      slotsFree &&
                          s.resources.canAfford(
                            def.formulation.counting,
                            def.formulation.proofing,
                            def.formulation.fame,
                          )
                      ? () => n.formulateConjecture(def.id)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.action,
                    foregroundColor: Palette.paper,
                    minimumSize: const Size(0, 34),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(
                    slotsFree ? 'Formulate ($formCost)' : 'Slots full',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The next laboratory recruit (sections 5, 13.8): professors may hire
  /// students who grind Counting automatically.
  Widget _laboratoryRow(GameState s) {
    final svc = const ApprenticeService();
    final owned = s.career.apprentices;
    if (s.career.stage != CareerStage.professor) {
      return ShopCard(
        name: 'Your laboratory',
        description: 'As a Professor you may recruit students who grind Counting automatically.',
        costLabel: 'Unlocks at Professor',
        canAfford: false,
        onBuy: () {},
      );
    }
    final next = svc.nextHire(owned);
    if (next == null) {
      return ShopCard(
        name: 'A full laboratory',
        description:
            'Five researchers under your name: +${svc.outputOf(owned).toStringAsFixed(0)} Counting/s.',
        costLabel: 'Complete',
        canAfford: false,
        onBuy: () {},
      );
    }
    return ShopCard(
      name: 'Recruit ${next.name}',
      description:
          '${next.bio} Adds +${next.countingPerSec.toStringAsFixed(0)} Counting/s.',
      costLabel: _costLabel(
        next.costCounting,
        next.costProofing,
        next.costFame,
      ),
      canAfford: s.resources.canAfford(
        next.costCounting,
        next.costProofing,
        next.costFame,
      ),
      onBuy: () => ref.read(gameStateProvider.notifier).hireApprentice(),
    );
  }

  /// One optional rule modifier for the current run (section 7).
  Widget _challengeCard(ChallengeDef def, GameState s) {
    final svc = const ChallengeService();
    final n = ref.read(gameStateProvider.notifier);
    final completed = s.completedChallenges.contains(def.id);
    final locked = !svc.unlocked(s, def.id);
    final active = s.activeChallenge == def.id;

    late final String costLabel;
    late final bool canAfford;
    late final VoidCallback buy;
    if (active) {
      costLabel = 'Abandon';
      canAfford = true;
      buy = () => n.abandonChallenge();
    } else if (completed) {
      costLabel = 'Completed';
      canAfford = false;
      buy = () {};
    } else if (locked) {
      costLabel = 'Locked';
      canAfford = false;
      buy = () {};
    } else {
      costLabel = 'Enter';
      canAfford = true;
      buy = () => n.enterChallenge(def.id);
    }

    return ShopCard(
      name: def.name,
      description: '${def.description} Reward: ${def.rewardSummary}.',
      costLabel: costLabel,
      canAfford: canAfford,
      onBuy: buy,
      lockedReason: locked && !completed
          ? 'Unlocks after completing Cryptography'
          : null,
    );
  }

  String _costLabel(double c, double p, double f) {
    final parts = <String>[
      if (c > 0) '${formatNumber(c)} C',
      if (p > 0) '${formatNumber(p)} P',
      if (f > 0) '${formatNumber(f)} F',
    ];
    return parts.isEmpty ? '—' : parts.join(' + ');
  }

  String _fmtCooldown(DateTime readyAt) {
    final d = readyAt.difference(DateTime.now());
    if (d.isNegative) return '0s';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} min';
    return '${d.inMinutes} min';
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Palette.action,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    ),
  );
}

/// Transient banner listing what was earned while the app stayed in the
/// background (plan section 13.10). Dismissed manually from the HUD.
class _AwayBanner extends StatelessWidget {
  const _AwayBanner({required this.report, required this.onDismiss});

  final OfflineReport report;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty, size: 16, color: Palette.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'While you were away: +${formatNumber(report.gained.counting)} C \u00b7 +${formatNumber(report.gained.proofing)} P \u00b7 +${formatNumber(report.gained.fame)} F',
              style: const TextStyle(color: Palette.ink, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 16, color: Palette.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Small pill-style tab switcher used by the research panel header.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? Palette.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Palette.accent.withValues(alpha: 0.6)
                : Palette.ink.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Palette.accent : Palette.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Full-screen first-launch prompt where the player picks their
/// mathematician's name (onboarding, plan section 8). Blocks the board until
/// confirmed, then persists via the notifier.
class _NameEntryPanel extends ConsumerStatefulWidget {
  const _NameEntryPanel();

  @override
  ConsumerState<_NameEntryPanel> createState() => _NameEntryPanelState();
}

class _NameEntryPanelState extends ConsumerState<_NameEntryPanel> {
  final TextEditingController _controller = TextEditingController();

  static const List<String> _suggestions = [
    'Ada',
    'Blaise',
    'Emmy',
    'Srinivasa',
    'Karl',
    'Sophie',
    'Maryam',
    'Per',
    'Léonore',
    'Évariste',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    ref.read(gameStateProvider.notifier).setName(_controller.text);
  }

  void _randomize() {
    _controller.text = _suggestions[Random().nextInt(_suggestions.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.scrim,
      alignment: Alignment.center,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.accent.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      color: Palette.accent,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'A new career begins',
                        style: TextStyle(
                          color: Palette.accent,
                          fontSize: 20,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'serif',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Every great mathematician starts with a name.\nWhat shall your colleagues call you?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Palette.inkSoft,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: (_) => _confirm(),
                        decoration: InputDecoration(
                          hintText: 'e.g. Ada Lovelace',
                          counterText: '',
                          filled: true,
                          fillColor: Palette.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _randomize,
                      tooltip: 'Roll a famous first name',
                      icon: const Icon(Icons.casino, color: Palette.inkSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _confirm(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.action,
                    foregroundColor: Palette.paper,
                    minimumSize: const Size(0, 48),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  child: const Text('Begin my career'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
