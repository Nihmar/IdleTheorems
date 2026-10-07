import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/game_state.dart';
import 'package:idle_theorems/domain/models/save_data.dart';
import 'package:idle_theorems/game/systems/challenge_service.dart';
import 'package:idle_theorems/game/systems/friction_system.dart';
import 'package:idle_theorems/game/systems/prestige_service.dart';
import 'package:idle_theorems/game/systems/production_system.dart';

GameState _state({String? completed}) => GameState()
  ..resources.gain(1e12, 1e12, 1e12)
  ..branches = {?completed: BranchProgress(completed: true)};

void main() {
  final svc = const ChallengeService();

  group('unlocking and entry rules', () {
    test('the encrypted run stays sealed until cryptography is done', () {
      expect(svc.unlocked(_state(), ChallengeService.encryptedRun), isFalse);
      expect(
          svc.unlocked(_state(completed: 'cryptography'),
              ChallengeService.encryptedRun),
          isTrue);
      expect(svc.enter(_state(), ChallengeService.encryptedRun), isFalse);
    });

    test('only one challenge runs at a time', () {
      final s = _state();
      expect(svc.enter(s, ChallengeService.constructivistRun), isTrue);
      expect(svc.enter(s, ChallengeService.noPaperRun), isFalse);
      expect(s.activeChallenge, ChallengeService.constructivistRun);
    });

    test('abandoning clears the slot without any reward', () {
      final s = _state();
      svc.enter(s, ChallengeService.constructivistRun);
      svc.abandon(s);
      expect(s.activeChallenge, '');
      expect(s.completedChallenges, isEmpty);
      expect(s.titles, isEmpty);
    });

    test('a completed challenge cannot be re-entered', () {
      final s = _state();
      svc.enter(s, ChallengeService.constructivistRun);
      svc.completeAtPrestige(s);
      expect(svc.enter(s, ChallengeService.constructivistRun), isFalse);
    });
  });

  group('completion rewards', () {
    test('completing pays legacy, title and multiplier exactly once', () {
      final s = _state(completed: 'cryptography');
      svc.enter(s, ChallengeService.encryptedRun);
      final d = svc.completeAtPrestige(s);
      expect(d, isNotNull);
      expect(s.prestige.legacy, 100);
      expect(s.prestige.legacyAllTime, 100);
      expect(s.titles, contains('Cipher Keeper'));
      expect(s.challengeGlobalMult, closeTo(1.05, 1e-9));
      expect(s.activeChallenge, '');
      // Re-completing the same definition pays nothing new.
      s.activeChallenge = ChallengeService.encryptedRun;
      svc.completeAtPrestige(s);
      expect(s.prestige.legacy, 100);
      expect(s.challengeGlobalMult, closeTo(1.05, 1e-9));
    });
  });

  group('rule modifiers', () {
    test('constructivist halves passive output and doubles paper Fame', () {
      final prod = const ProductionSystem();
      final plain = prod.compute(_state()..producerLevels['guided_exercises'] = 3);
      final lean = prod.compute(_state()
        ..activeChallenge = ChallengeService.constructivistRun
        ..producerLevels['guided_exercises'] = 3);
      expect(lean.countingPerSec / plain.countingPerSec, closeTo(0.5, 1e-9));
      expect(
          svc.paperFameFactor(_state()
            ..activeChallenge = ChallengeService.constructivistRun),
          closeTo(2, 1e-9));
    });

    test('no-paper run closes the desk and pays click Fame', () {
      final s = _state()..activeChallenge = ChallengeService.noPaperRun;
      expect(svc.blocksNewPapers(s), isTrue);
      expect(svc.clickFame(s), closeTo(5, 1e-9));
      expect(svc.clickFame(_state()), 0);
    });

    test('encrypted run doubles stress build-up in the friction tick', () {
      final friction = const FrictionSystem();
      final calm = _state();
      final secret = _state()..activeChallenge = ChallengeService.encryptedRun;
      for (final s in [calm, secret]) {
        for (var i = 0; i < FrictionSystem.overloadPaperThreshold; i++) {
          s.activePapers.add(PaperJob(60));
        }
      }
      friction.tick(calm, 60);
      friction.tick(secret, 60);
      expect(secret.stress / calm.stress, closeTo(2, 1e-9));
    });

    test('prestige conversion scales with the given factor', () {
      final s = _state()..lifetime['fame'] = 1e6; // -> floor(sqrt(1e4)) = 100
      const PrestigeService().applyPrestige(s, 2);
      expect(s.prestige.legacy, 200);
      expect(svc.prestigeLegacyFactor(_state()), closeTo(1, 1e-9));
    });

    test('completed-challenge boost feeds every production channel', () {
      final prod = const ProductionSystem();
      final base = prod.compute(_state()..papersInRun = 10);
      final boosted = prod.compute(_state()
        ..papersInRun = 10
        ..challengeGlobalMult = 1.05);
      expect(boosted.famePerSec / base.famePerSec, closeTo(1.05, 1e-9));
    });
  });
}
