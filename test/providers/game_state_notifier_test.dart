import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/domain/models/producers.dart';
import 'package:idle_theorems/domain/services/balance_service.dart';
import 'package:idle_theorems/providers/game_state_provider.dart';

void main() {
  late ProviderContainer container;
  late GameStateNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(gameStateProvider.notifier);
    notifier.bootstrap(GameState());
  });

  tearDown(() => container.dispose());

  test('solveExercise grants click power and counts clicks', () {
    final before = container.read(gameStateProvider).resources.counting;
    notifier.solveExercise();
    final after = container.read(gameStateProvider);
    expect(after.resources.counting - before,
        closeTo(const BalanceService().clickPower(0), 1e-9));
    expect(after.stats.totalClicks, 1);
  });

  test('buyProducer spends currency and levels up, triggering a save', () {
    final def = producerCatalog['guided_exercises']!;
    final cost = const BalanceService().producerCost(def, 0);
    notifier.state.resources.counting += cost + 1; // seed funds for the test
    var saves = 0;
    notifier.setSaveHook(() => saves++);

    expect(notifier.buyProducer(def.id), isTrue);
    final s = container.read(gameStateProvider);
    expect(s.levelOf(def.id), 1);
    expect(s.resources.counting, closeTo(1, 1e-9));
    expect(saves, 1);
  });

  test('buyProducer fails when funds are missing', () {
    expect(notifier.buyProducer('guided_exercises'), isFalse);
    expect(container.read(gameStateProvider).levelOf('guided_exercises'), 0);
  });

  test('setName trims whitespace and caps length', () {
    notifier.setName('   Ada   Lovelace ');
    expect(container.read(gameStateProvider).playerName, 'Ada Lovelace');

    notifier.setName('a' * 40);
    expect(container.read(gameStateProvider).playerName.length, 24);
  });

  test('startPaper costs proofing and queues a job', () {
    notifier.state.resources.proofing +=
        const BalanceService().paperCost(0) + 1;
    expect(notifier.startPaper(), isTrue);
    final s = container.read(gameStateProvider);
    expect(s.activePapers.length, 1);
    expect(s.papersInRun, 1);
  });

  test('ticking eventually resolves every paper attempt', () {
    notifier.state.resources.proofing = 1e9; // rewrites always affordable
    notifier.startPaper();

    for (var i = 0; i < 200 && container.read(gameStateProvider).activePapers.isNotEmpty; i++) {
      notifier.tick(PaperConfig.writeDurationSeconds);
    }

    final s = container.read(gameStateProvider);
    expect(s.activePapers, isEmpty);
    expect(s.stats.papersPublished + s.stats.papersRejected, greaterThan(0));
  });
}
