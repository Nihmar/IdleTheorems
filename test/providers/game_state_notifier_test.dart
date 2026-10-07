import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/career.dart';
import 'package:idle_theorems/domain/models/conjecture.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/domain/models/producers.dart';
import 'package:idle_theorems/domain/models/save_data.dart';
import 'package:idle_theorems/domain/models/subject.dart';
import 'package:idle_theorems/domain/services/balance_service.dart';
import 'package:idle_theorems/domain/services/subject_service.dart';
import 'package:idle_theorems/game/systems/production_system.dart';
import 'package:idle_theorems/game/systems/friction_system.dart';
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

  test('cannot exceed concurrent paper slots', () {
    notifier.state.resources.proofing = 1e9;
    expect(notifier.startPaper(), isTrue);
    expect(notifier.startPaper(), isFalse); // default single slot busy
  });

  test('completed geometry discounts the paper cost', () {
    const balance = BalanceService();
    final base = balance.paperCost(0);
    notifier.state.branches['geometry'] =
        BranchProgress(completed: true, theoremsMastered: 8);
    notifier.state.resources.proofing = base * 0.95; // covers discount only
    expect(notifier.startPaper(), isTrue);
    expect(container.read(gameStateProvider).resources.proofing,
        closeTo(base * 0.05, 1e-9));
  });

  test('completed logic & sets multiplies click power by 1.10', () {
    notifier.state.branches['logic_sets'] =
        BranchProgress(completed: true, theoremsMastered: 4);
    final before = container.read(gameStateProvider).resources.counting;
    notifier.solveExercise();
    final after = container.read(gameStateProvider).resources.counting;
    expect(after - before, closeTo(const BalanceService().clickPower(0) * 1.10, 1e-9));
  });

  test('focusing a subject masters it through accepted papers', () {
    const svc = SubjectService();
    notifier.focusSubject('logic_sets');
    expect(container.read(gameStateProvider).activeSubjectId, 'logic_sets');

    notifier.state.resources.proofing = 1e9; // rewrites always affordable
    var guard = 0;
    while (!svc.isCompleted(notifier.state, 'logic_sets') && guard < 200) {
      notifier.startPaper(); // no-op while all slots are busy
      notifier.tick(PaperConfig.writeDurationSeconds);
      guard++;
    }

    final s = container.read(gameStateProvider);
    expect(svc.isCompleted(s, 'logic_sets'), isTrue);
    expect(s.activeSubjectId, isEmpty); // focus cleared at mastery
    expect(s.stats.papersPublished, greaterThanOrEqualTo(masteryNeeded(0)));
  });

  test('resuming after an absence credits gains at half rate', () {
    notifier.state.producerLevels['guided_exercises'] = 5;
    final t0 = DateTime.utc(2026, 1, 1, 12);
    final snapshot = notifier.snapshotForSave(t0);
    final before = container.read(gameStateProvider).resources.counting;

    notifier.applyAwayEarnings(snapshot, t0.add(const Duration(hours: 1)));

    final expected = const ProductionSystem()
        .compute(notifier.state)
        .countingPerSec *
        3600 *
        0.5;
    expect(container.read(gameStateProvider).resources.counting - before,
        closeTo(expected, 1e-6));
    expect(notifier.lastAwayReport, isNotNull);
    notifier.dismissAwayReport();
    expect(notifier.lastAwayReport, isNull);
  });

  group('frictions', () {
    test('takeSabbatical pays Fame, clears stress and posts a notice', () {
      notifier.state.resources.gain(0, 0, 1000);
      notifier.state.stress = 0.7;
      expect(notifier.takeSabbatical(), isTrue);
      final s = container.read(gameStateProvider);
      expect(s.resources.fame, closeTo(900, 1e-9));
      expect(s.stress, 0);
      expect(s.transientNotice, contains('break'));
    });

    test('a fired retraction grants Metodo XP', () {
      notifier.state.resources.gain(0, 0, 1000);
      notifier.state.scheduledRetractions
          .add(ScheduledRetraction(DateTime.now()));
      notifier.tick(1);
      final s = container.read(gameStateProvider);
      expect(s.stats.retractions, 1);
      expect(s.metodoXp,
          greaterThanOrEqualTo(FrictionSystem.retractionMethodXp));
    });
  });

  group('conjectures', () {
    late GameState postdoc;

    setUp(() {
      postdoc = GameState()
        ..career.stage = CareerStage.postdoc
        ..branches = {'discrete_algebra': BranchProgress(completed: true)}
        ..resources.gain(1e12, 1e12, 1e12);
      notifier.bootstrap(postdoc);
    });

    test('formulateConjecture pays once and opens the discovery loop', () {
      expect(notifier.formulateConjecture('double_counting_lemmas'), isTrue);
      final s = container.read(gameStateProvider);
      expect(s.conjectures.single.defId, 'double_counting_lemmas');
      expect(s.conjectures.single.status, ConjectureStatus.active);
      expect(notifier.formulateConjecture('double_counting_lemmas'), isFalse);
    });

    test('workOnConjecture eventually resolves and rewards or teaches', () {
      notifier.formulateConjecture('double_counting_lemmas');
      // Bounded loop: tier 1 needs ~8 sessions; rolls resolve within that.
      for (var i = 0; i < 30; i++) {
        notifier.workOnConjecture('double_counting_lemmas');
        final st = container.read(gameStateProvider).conjectures.single;
        if (st.status == ConjectureStatus.proven) break;
        if (st.status == ConjectureStatus.refuted) {
          // Failure must have granted Metodo XP (10 x tier).
          expect(container.read(gameStateProvider).metodoXp,
              greaterThanOrEqualTo(10));
          // Jump past the cooldown and keep working until proven.
          st.readyAt = DateTime.now();
          notifier.tick(0.001);
        }
      }
      expect(
          container.read(gameStateProvider).conjectures.single.status,
          ConjectureStatus.proven);
      expect(container.read(gameStateProvider).stats.conjecturesSolved, 1);
    });
  });

  group('prestige conversion', () {
    test('completed Algebraic Topology boosts the Fame-to-Legacy conversion',
        () {
      final s = container.read(gameStateProvider);
      s.lifetime['fame'] = 1e6; // -> floor(sqrt(1e4)) = 100 base gain
      s.branches['algebraic_topology'] = BranchProgress(completed: true);
      expect(notifier.legacyGainNow, 125);
      final bankBefore = s.prestige.legacy;
      expect(notifier.prestige(), isTrue);
      expect(container.read(gameStateProvider).prestige.legacy, bankBefore + 125);
    });

    test('without completed subjects the conversion stays at baseline', () {
      final s = container.read(gameStateProvider);
      s.lifetime['fame'] = 1e6;
      expect(notifier.legacyGainNow, 100);
    });

    test('Algebraic Topology and Cryptography bonuses multiply together', () {
      final s = container.read(gameStateProvider);
      s.branches['algebraic_topology'] = BranchProgress(completed: true);
      s.branches['cryptography'] = BranchProgress(completed: true);
      expect(notifier.prestigeLegacyFactor(), closeTo(1.25 * 1.10, 1e-9));
    });
  });
}
