import 'dart:math';

import '../../domain/models/game_state.dart';
import '../../domain/models/save_data.dart';
import '../../domain/models/subject.dart';
import '../../domain/services/subject_service.dart';

/// Rotating research climate (plan sections 3 and 13.10): every 72 h one
/// field becomes fashionable. Papers written while focusing the trending
/// field earn double Fame; working its conjectures gains +25% progress
/// (section 4 rules table). The change is telegraphed 24 h ahead so the
/// player plans instead of reacting.
class TrendService {
  const TrendService();

  static const Duration rotation = Duration(hours: 72);
  static const Duration telegraphWindow = Duration(hours: 24);
  static const double paperFameMult = 2.0;
  static const double conjectureProgressBonus = 0.25;

  final SubjectService _subjects = const SubjectService();

  bool isActive(GameState s, [DateTime? now]) {
    final t = s.trend;
    return t.activeSubject.isNotEmpty &&
        t.endsAt != null &&
        !(now ?? DateTime.now()).isAfter(t.endsAt!);
  }

  /// True when [subjectId] is the currently trending field.
  bool isTrending(GameState s, String subjectId, [DateTime? now]) =>
      subjectId.isNotEmpty && s.trend.activeSubject == subjectId && isActive(s, now);

  /// True when the next rotation should be announced: inside the 24 h
  /// telegraph window, or always once Statistics is mastered (it reveals
  /// the whole calendar).
  bool shouldAnnounceNext(GameState s, [DateTime? now]) {
    if (s.trend.nextSubject.isEmpty) return false;
    if (_subjects.isCompleted(s, 'statistics')) return true;
    final starts = s.trend.nextStartsAt;
    if (starts == null) return false;
    final gap = starts.difference(now ?? DateTime.now());
    return !gap.isNegative && gap <= telegraphWindow;
  }

  /// Candidate pool: completed fields first; brand-new players trend over
  /// the entry-level fields they can already study.
  List<String> _candidates(GameState s) {
    final completed = <String>[];
    for (final id in subjectCatalog.keys) {
      if (_subjects.isCompleted(s, id)) completed.add(id);
    }
    if (completed.isNotEmpty) return completed..sort();
    return subjectsByLevel()
        .where((d) => d.level <= 1)
        .map((d) => d.id)
        .toList()
      ..sort();
  }

  /// Deterministic pick keyed on the slot start instant.
  String _pick(List<String> candidates, DateTime slotStart) {
    if (candidates.isEmpty) return '';
    final rng = Random(slotStart.millisecondsSinceEpoch);
    return candidates[rng.nextInt(candidates.length)];
  }

  /// Keeps the schedule current: fills an empty calendar and rolls the
  /// chain forward whenever the active slot expired. At most one missed
  /// window honours its scheduled boundary; once a whole rotation or more
  /// has been missed (long absence) the schedule resyncs to "now" instead
  /// of replaying every missed slot frame by frame.
  void update(GameState s, [DateTime? now]) {
    final t = s.trend;
    final tNow = now ?? DateTime.now();
    if (!isActive(s, tNow)) {
      final start = t.nextStartsAt;
      final stale = start != null && start.isBefore(tNow.subtract(rotation));
      final begin = (start == null || start.isAfter(tNow) || stale) ? tNow : start;
      t.activeSubject =
          t.nextSubject.isNotEmpty ? t.nextSubject : _pick(_candidates(s), begin);
      t.endsAt = begin.add(rotation);
      _assignNext(s, t, tNow); // re-anchor the telegraph to the new window
    } else if (t.nextSubject.isEmpty || t.nextStartsAt == null) {
      _assignNext(s, t, tNow);
    }
  }

  void _assignNext(GameState s, TrendState t, DateTime now) {
    // The next window opens exactly when the active one closes.
    final start = t.endsAt ?? now;
    t.nextStartsAt = start;
    t.nextSubject = _pick(_candidates(s), start);
  }
}
