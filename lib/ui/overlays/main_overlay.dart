import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:katex/katex.dart';

import '../../domain/models/game_state.dart';
import '../../domain/models/producers.dart';
import '../../domain/models/upgrade.dart';
import '../../domain/services/balance_service.dart';
import '../../game/systems/career_system.dart';
import '../../game/systems/production_system.dart';
import '../../providers/game_state_provider.dart';
import '../../utils/number_format.dart';
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

const Color _chalkColor = Color(0xFFAFC0B8);
const Color _gold = Color(0xE6FFD75E);

/// Derives the current guided hint for "The first semester" onboarding
/// (plan section 8). Stateless: progress is read from game state directly.
String? onboardingHint(GameState s) {
  if (s.stats.totalClicks == 0) {
    return 'Tap the board to solve your first exercise.';
  }
  var producersOwned = countingProducers.fold<int>(
      0, (acc, p) => acc + (s.producerLevels[p.id] ?? 0));
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
class MainOverlay extends ConsumerWidget {
  const MainOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameStateProvider);
    final rates = const ProductionSystem().compute(s);

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
                child: Math(tex, color: _chalkColor, fontSize: 17),
              ),
            // Top HUD.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Idle Theorems',
                            style: TextStyle(
                                color: _gold,
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                fontFamily: 'serif')),
                        const Spacer(),
                        if (s.playerName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child:
                                _Chip(label: s.playerName, icon: Icons.badge_outlined),
                          ),
                        _Chip(label: s.career.stage.label, icon: Icons.school_outlined),
                        const SizedBox(width: 8),
                        _Chip(label: 'Metodo Lv ${s.metodoLevel}', icon: Icons.psychology_alt),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: ResourceCounter(
                                label: 'Counting',
                                icon: Icons.edit_note,
                                value: s.resources.counting,
                                perSecond: rates.countingPerSec)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ResourceCounter(
                                label: 'Proofing',
                                icon: Icons.menu_book,
                                value: s.resources.proofing,
                                perSecond: rates.proofingPerSec)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: ResourceCounter(
                                label: 'Fame',
                                icon: Icons.star,
                                value: s.resources.fame,
                                perSecond: rates.famePerSec)),
                      ]),
                      if (onboardingHint(s) != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _gold.withValues(alpha: 0.5)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.lightbulb_outline, size: 16, color: _gold),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(onboardingHint(s)!,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13))),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Bottom action bar + slide-up research shop.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(h: h),
            ),
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
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameStateProvider);
    final balance = const BalanceService();
    final papersInProgress = s.activePapers.length;
    final nextPaperDoneIn = papersInProgress == 0
        ? null
        : s.activePapers.map((j) => j.remainingSeconds).reduce(min);

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
              color: const Color(0xE61E2B28),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
            ),
            child: _shopOpen
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Row(children: [
                        const Text('Research shop',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (papersInProgress > 0)
                          Flexible(
                              child: Text(
                                  '$papersInProgress paper(s) in progress — next done in ~${nextPaperDoneIn!.ceil()}s',
                                  style:
                                      const TextStyle(color: Colors.white70, fontSize: 12))),
                        IconButton(
                            onPressed: () => setState(() => _shopOpen = false),
                            icon: const Icon(Icons.close, color: Colors.white70)),
                      ]),
                      const SizedBox(height: 8),
                      _sectionHeader('Counting'),
                      for (final p in countingProducers)
                        _producerRow(p),
                      _sectionHeader('Techniques (one-time)'),
                      for (final t in techniqueCatalogList)
                        ShopCard(
                          name: t.name,
                          description: t.description,
                          costLabel:
                              s.techniques.contains(t.id) ? 'Owned' : formatCost(t.costCounting, ResourceKind.counting),
                          canAfford: !s.techniques.contains(t.id) &&
                              s.resources.canAfford(t.costCounting),
                          onBuy: () => ref.read(gameStateProvider.notifier).buyTechnique(t.id),
                        ),
                      _sectionHeader('Proofing'),
                      for (final p in proofingProducers)
                        _producerRow(p),
                      _sectionHeader('Upgrades'),
                      for (final u in upgradeCatalogList)
                        ShopCard(
                          name: u.name,
                          description: u.description,
                          owned: s.levelOf(u.id),
                          costLabel: formatCost(balance.upgradeCost(u, s.levelOf(u.id)), u.currency),
                          canAfford: s.resources.canAfford(_costForKind(u.currency, balance.upgradeCost(u, s.levelOf(u.id)))),
                          onBuy: () => ref.read(gameStateProvider.notifier).buyUpgrade(u.id),
                        ),
                      _sectionHeader('Publication desk'),
                      ShopCard(
                        name: 'Publish paper',
                        description: '~60s writing, then peer review. Fame on acceptance.',
                        costLabel: formatCost(balance.paperCost(s.papersInRun), ResourceKind.proofing),
                        canAfford: s.resources.canAfford(0, balance.paperCost(s.papersInRun)),
                        onBuy: () => ref.read(gameStateProvider.notifier).startPaper(),
                      ),
                      if (CareerSystem().canDefendThesis(s))
                        ShopCard(
                          name: 'Defend thesis',
                          description: 'Advance to PhD (requires 1K cumulative Fame).',
                          costLabel: formatCost(CareerSystem.thesisCostProofing, ResourceKind.proofing),
                          canAfford: s.resources.canAfford(0, CareerSystem.thesisCostProofing),
                          onBuy: () => ref.read(gameStateProvider.notifier).defendThesis(),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => ref.read(gameStateProvider.notifier).solveExercise(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9CCC65),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 48),
                    textStyle:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  icon: const Icon(Icons.edit_note),
                  label: Text(
                      'Solve exercise (+${formatNumber(balance.clickPower(s.levelOf('study_tools')))})'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => _shopOpen = !_shopOpen),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  minimumSize: const Size(110, 48),
                ),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Shop'),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  double _costForKind(ResourceKind kind, double amount) {
    switch (kind) {
      case ResourceKind.counting:
        return amount;
      case ResourceKind.proofing:
        return amount;
      case ResourceKind.fame:
        return amount;
    }
  }

  Widget _producerRow(ProducerDef p) {
    final owned = ref.read(gameStateProvider).levelOf(p.id);
    final cost = const BalanceService().producerCost(p, owned);
    return ShopCard(
      name: p.name,
      description: p.description,
      owned: owned,
      costLabel: formatCost(cost, p.currency),
      canAfford: ref.read(gameStateProvider).resources.canAfford(_costForKind(p.currency, cost)),
      onBuy: () => ref.read(gameStateProvider.notifier).buyProducer(p.id),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF9CCC65), fontSize: 12, letterSpacing: 1.2)),
      );
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
    'Ada', 'Blaise', 'Emmy', 'Srinivasa', 'Karl', 'Sophie',
    'Maryam', 'Per', 'Léonore', 'Évariste',
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
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: const Color(0xF21E2B28),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.badge_outlined, color: _gold, size: 28),
                  const SizedBox(width: 10),
                  Flexible(
                      child: Text('A new career begins',
                          style: TextStyle(
                              color: _gold,
                              fontSize: 20,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'serif')))
                ]),
                const SizedBox(height: 12),
                const Text(
                    'Every great mathematician starts with a name.\nWhat shall your colleagues call you?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                const SizedBox(height: 16),
                Row(children: [
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
                        fillColor: Colors.black.withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _randomize,
                    tooltip: 'Roll a famous first name',
                    icon: const Icon(Icons.casino, color: Colors.white70),
                  ),
                ]),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _confirm(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9CCC65),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 48),
                    textStyle:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
