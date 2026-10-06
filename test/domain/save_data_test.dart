import 'package:flutter_test/flutter_test.dart';
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
      original.titles = ['Prime Summarizer', 'Zero Hunter'];
      original.techniques.add('elementary_formalization');
      original.producerLevels['guided_exercises'] = 3;

      final restored =
          SaveData.fromJson(original.toJson());

      expect(restored.version, SaveData.currentVersion);
      expect(restored.playerName, 'Ada Lovelace');
      expect(restored.savedAt.millisecondsSinceEpoch,
          DateTime.utc(2026, 1, 1).millisecondsSinceEpoch);
      expect(restored.resources.counting, 12.5);
      expect(restored.resources.proofing, 3);
      expect(restored.prestige.legacy, 7);
      expect(restored.metodoLevel, 4);
      expect(restored.papersInRun, 2);
      expect(restored.titles, equals(['Prime Summarizer', 'Zero Hunter']));
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

    test('persists the focused research subject and tolerates its absence',
        () {
      final t = DateTime.utc(2026, 1, 1);
      final withFocus = SaveData.fresh(t)..activeSubjectId = 'analysis';
      expect(SaveData.fromJson(withFocus.toJson()).activeSubjectId, 'analysis');

      final legacyJson = SaveData.fresh(t).toJson()..remove('active_subject_id');
      expect(SaveData.fromJson(legacyJson).activeSubjectId, '');
    });

    test('unsupported version is rejected explicitly', () {
      final json = SaveData.fresh().toJson();
      json['version'] = 999;
      expect(() => SaveData.fromJson(json), throwsFormatException);
    });
  });
}
