import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/providers/game_state_provider.dart';
import 'package:idle_theorems/ui/overlays/main_overlay.dart';

Widget wrap(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: const MainOverlay()),
    );

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
  });
}
