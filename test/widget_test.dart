import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/career.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/domain/models/save_data.dart';
import 'package:idle_theorems/providers/game_state_provider.dart';
import 'package:idle_theorems/ui/overlays/main_overlay.dart';

Widget wrap(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: const MainOverlay()),
    );

/// Opens the shop and scrolls until the Laboratory section is on screen.
Future<void> scrollToLaboratory(WidgetTester tester) async {
  await tester.tap(find.text('Shop'));
  await tester.pumpAndSettle();
  // The laboratory sits mid-list in the lazy shop.
  for (var i = 0;
      i < 10 && find.text('LABORATORY').evaluate().isEmpty;
      i++) {
    await tester.dragFrom(const Offset(400, 500), const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('new player picks their name on first launch', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(gameStateProvider.notifier).bootstrap(GameState());

    await tester.pumpWidget(wrap(container));

    // The name entry panel blocks the board until confirmed.
    expect(find.text('A new career begins'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ada Lovelace');
    await tester.tap(find.text('Begin my career'));
    await tester.pumpAndSettle();

    // Panel gone, name shown in the HUD chip.
    expect(find.text('Begin my career'), findsNothing);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(container.read(gameStateProvider).playerName, 'Ada Lovelace');
  });

  testWidgets('solving exercises gains counting resources', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameStateProvider.notifier)
        .bootstrap(GameState()..playerName = 'Blaise');

    await tester.pumpWidget(wrap(container));

    expect(find.textContaining('Solve exercise'), findsOneWidget);
    await tester.tap(find.textContaining('Solve exercise'));
    await tester.pump();

    expect(container.read(gameStateProvider).resources.counting,
        closeTo(1, 1e-9));
    expect(container.read(gameStateProvider).stats.totalClicks, 1);
  });

  testWidgets('shop opens and lists producers', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameStateProvider.notifier)
        .bootstrap(GameState()..playerName = 'Emmy');

    await tester.pumpWidget(wrap(container));

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();

    expect(find.text('Research shop'), findsOneWidget);
    // The Legacy section pushes producers below the fold: scroll down.
    for (var i = 0;
        i < 10 && find.textContaining('Guided exercises').evaluate().isEmpty;
        i++) {
      await tester.dragFrom(const Offset(400, 500), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Guided exercises'), findsWidgets);
  });

  testWidgets('away earnings show a dismissible banner on resume', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(gameStateProvider.notifier);
    notifier.bootstrap(GameState()..playerName = 'Ada');
    notifier.state.producerLevels['guided_exercises'] = 5;

    await tester.pumpWidget(wrap(container));

    notifier.applyAwayEarnings(
        notifier.snapshotForSave(DateTime.now().subtract(const Duration(hours: 2))),
        DateTime.now());
    await tester.pumpAndSettle();

    expect(find.textContaining('While you were away'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.textContaining('While you were away'), findsNothing);
  });

  testWidgets('conjectures tab lists discoveries with their gates', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameStateProvider.notifier)
        .bootstrap(GameState()..playerName = 'Blaise');

    await tester.pumpWidget(wrap(container));

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conjectures'));
    await tester.pumpAndSettle();

    expect(find.text('DISCOVERY'), findsOneWidget);
    expect(find.text('Double Counting Lemmas'), findsOneWidget);
    // A fresh student cannot formulate yet.
    expect(find.text('Unlocks at Postdoc'), findsWidgets);
    // Endgame frontiers sit below the fold of the lazy list.
    for (var i = 0;
        i < 10 && find.text('FRONTIERS').evaluate().isEmpty;
        i++) {
      await tester.dragFrom(const Offset(400, 500), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(find.text('FRONTIERS'), findsOneWidget);
    expect(find.text('Goldbach\u2019s Conjecture'), findsOneWidget);
    expect(find.text('Unlocks at Professor'), findsWidgets);
  });

  testWidgets('stressed state offers a sabbatical in the shop', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(gameStateProvider.notifier);
    notifier.bootstrap(GameState()
      ..playerName = 'Blaise'
      ..stress = 0.6);

    await tester.pumpWidget(wrap(container));

    expect(find.textContaining('Stressed'), findsOneWidget);
    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    // The sabbatical card sits below the fold of the lazy shop list.
    for (var i = 0;
        i < 15 && find.textContaining('Sabbatical').evaluate().isEmpty;
        i++) {
      await tester.dragFrom(const Offset(400, 500), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Sabbatical'), findsOneWidget);
  });

  testWidgets('challenges section lists runs and their gates', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameStateProvider.notifier)
        .bootstrap(GameState()..playerName = 'Blaise');

    await tester.pumpWidget(wrap(container));
    await scrollToLaboratory(tester);
    // Scroll until the first challenge card is built.
    for (var i = 0;
        i < 15 &&
            find.textContaining('Constructivist Run').evaluate().isEmpty;
        i++) {
      await tester.dragFrom(const Offset(400, 500), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(find.text('CHALLENGES'), findsOneWidget);
    expect(find.textContaining('Constructivist Run'), findsOneWidget);
    // Keep scrolling until the encrypted run's gate label is built.
    for (var i = 0;
        i < 15 &&
            find.text('Unlocks after completing Cryptography')
                .evaluate()
                .isEmpty;
        i++) {
      await tester.dragFrom(const Offset(400, 500), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(find.text('Unlocks after completing Cryptography'), findsOneWidget);
  });

  testWidgets('an active challenge wears its HUD chip', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(gameStateProvider.notifier);
    notifier.bootstrap(GameState()..playerName = 'Blaise');

    await tester.pumpWidget(wrap(container));
    notifier.enterChallenge('constructivist_run');
    await tester.pumpAndSettle();

    expect(find.text('Constructivist Run'), findsOneWidget);
  });

  testWidgets('laboratory stays sealed below Professor', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gameStateProvider.notifier)
        .bootstrap(GameState()..playerName = 'Blaise');

    await tester.pumpWidget(wrap(container));
    await scrollToLaboratory(tester);

    expect(find.text('LABORATORY'), findsOneWidget);
    expect(find.text('Unlocks at Professor'), findsOneWidget);
  });

  testWidgets('professors see their next laboratory recruit', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(gameStateProvider.notifier).bootstrap(
        GameState()
          ..playerName = 'Blaise'
          ..career.stage = CareerStage.professor);

    await tester.pumpWidget(wrap(container));
    await scrollToLaboratory(tester);

    expect(find.textContaining('Recruit María'), findsOneWidget);
  });

  testWidgets('prestige reboots the run through the confirmation dialog',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(gameStateProvider.notifier);
    notifier.bootstrap(GameState()
      ..playerName = 'Blaise'
      ..gain(0, 0, 1e4)
      ..career.stage = CareerStage.postdoc);

    await tester.pumpWidget(wrap(container));

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(find.text('Gauss'), findsOneWidget);

    await tester.tap(find.text('Needs 10+ from this run'));
    await tester.pumpAndSettle();
    expect(find.text('Begin a new chapter?'), findsOneWidget);
    await tester.tap(find.text('Prestige').last);
    await tester.pumpAndSettle();

    final s = container.read(gameStateProvider);
    expect(s.prestige.legacy, 10);
    expect(s.career.stage, CareerStage.student);
    expect(s.resources.fame, 0);
  });

  testWidgets('active trend shows its chip and the telegraphed successor',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final now = DateTime.now();
    container.read(gameStateProvider.notifier).bootstrap(
        GameState()
          ..playerName = 'Blaise'
          ..trend = TrendState(
            activeSubject: 'analysis',
            endsAt: now.add(const Duration(hours: 10)),
            nextSubject: 'topology',
            nextStartsAt: now.add(const Duration(hours: 10)),
          ));

    await tester.pumpWidget(wrap(container));

    expect(find.textContaining('Trend: Analysis'), findsOneWidget);
    expect(find.textContaining('Up next: Topology'), findsOneWidget);
  });
}
