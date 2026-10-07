import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/career.dart';
import 'package:idle_theorems/domain/models/save_data.dart';

void main() {
  group('SaveData', () {
    test('fresh save roundtrips through JSON', () {
      final original = SaveData.fresh(DateTime.utc(2026, 1, 1));
      original.playerName = 'Ada Lovelace';
      original.resources.counting = 12.5;
      original.resources.proofing = 3;
      original.prestige.legacy = 7;
      original.metodoLevel = 4;
      original.papersInRun = 2;
      original.papersPublishedInRun = 3;
      original.titles = ['Prime Summarizer', 'Zero Hunter'];
      original.activeChallenge = 'constructivist_run';
      original.completedChallenges = ['no_paper_run'];
      original.challengeGlobalMult = 1.05;
      original.techniques.add('elementary_formalization');
      original.producerLevels['guided_exercises'] = 3;

      final restored = SaveData.fromJson(original.toJson());

      expect(restored.version, SaveData.currentVersion);
      expect(restored.playerName, 'Ada Lovelace');
      expect(
        restored.savedAt.millisecondsSinceEpoch,
        DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
      );
      expect(restored.resources.counting, 12.5);
      expect(restored.resources.proofing, 3);
      expect(restored.prestige.legacy, 7);
      expect(restored.metodoLevel, 4);
      expect(restored.papersInRun, 2);
      expect(restored.papersPublishedInRun, 3);
      expect(restored.titles, equals(['Prime Summarizer', 'Zero Hunter']));
      expect(restored.activeChallenge, 'constructivist_run');
      expect(restored.completedChallenges, equals(['no_paper_run']));
      expect(restored.challengeGlobalMult, closeTo(1.05, 1e-9));
      expect(restored.techniques, contains('elementary_formalization'));
      expect(restored.producerLevels['guided_exercises'], 3);
    });

    test('missing additive fields fall back to defaults', () {
      final json = SaveData.fresh().toJson();
      // Simulate an older client that never wrote these keys.
      json.remove('player_name');
      json.remove('metodo_xp');
      json.remove('papers_in_run');

      final restored = SaveData.fromJson(json);
      expect(restored.playerName, '');
      expect(restored.metodoXp, 0);
      expect(restored.papersInRun, 0);
    });

    test('v3 saves load through the migration chain', () {
      final t = DateTime.utc(2026, 1, 1);
      final v4 = SaveData.fresh(t)
        ..playerName = 'Ada Lovelace'
        ..papersInRun = 5;
      final json = v4.toJson()
        ..['version'] = 3
        ..remove('papers_published_in_run');

      final restored = SaveData.fromJson(json);
      expect(restored.version, SaveData.currentVersion);
      expect(restored.papersPublishedInRun, 0); // migrated default
      expect(restored.papersInRun, 5); // untouched by the step
      expect(restored.playerName, 'Ada Lovelace');
    });

    test('missing optional objects and keys degrade to defaults', () {
      final json = SaveData.fresh(DateTime.utc(2026, 1, 1)).toJson()
        ..remove('resources')
        ..remove('lifetime')
        ..remove('career')
        ..remove('prestige')
        ..remove('trend')
        ..remove('settings')
        ..remove('stats')
        ..remove('saved_at_ms')
        ..remove('last_loaded_at_ms');

      final restored = SaveData.fromJson(json);
      expect(restored.resources.counting, 0);
      expect(restored.lifetime['fame'], 0);
      expect(restored.career.stage, CareerStage.student);
      expect(restored.prestige.legacy, 0);
      expect(restored.prestige.mathematicians, isEmpty);
      expect(restored.trend.activeSubject, '');
      expect(restored.settings.sound, isTrue);
      expect(restored.stats.totalClicks, 0);
    });

    test('conjecture entries without a definition id are dropped', () {
      final json = SaveData.fresh().toJson()
        ..['conjectures'] = [
          {'def_id': null},
          {'def_id': '', 'status': 'active'},
        ];
      expect(SaveData.fromJson(json).conjectures, isEmpty);
    });

    test('persists the focused research subject and tolerates its absence', () {
      final t = DateTime.utc(2026, 1, 1);
      final withFocus = SaveData.fresh(t)..activeSubjectId = 'analysis';
      expect(SaveData.fromJson(withFocus.toJson()).activeSubjectId, 'analysis');

      final legacyJson = SaveData.fresh(t).toJson()
        ..remove('active_subject_id');
      expect(SaveData.fromJson(legacyJson).activeSubjectId, '');
    });

    test('unsupported version is rejected explicitly', () {
      final json = SaveData.fresh().toJson();
      json['version'] = 999;
      expect(() => SaveData.fromJson(json), throwsFormatException);
    });
  });
}
