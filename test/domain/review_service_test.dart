import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/game/systems/review_service.dart';

void main() {
  final review = ReviewService();

  group('paperReward (§13.4)', () {
    test('base Fame without any published paper', () {
      expect(review.paperReward(0, fameMultiplier: 1), closeTo(25, 1e-9));
    });

    test('Fame scales with papers published this run', () {
      // 25 * (1 + 0.1 * 5) = 37.5
      expect(review.paperReward(5, fameMultiplier: 1), closeTo(37.5, 1e-9));
    });

    test('subject fame multipliers apply before the per-paper scaling', () {
      // 25 * 2 * (1 + 0.1 * 10) = 100
      expect(review.paperReward(10, fameMultiplier: 2), closeTo(100, 1e-9));
    });

    test('a survived revision round pays the one-time x1.25 bonus', () {
      expect(
        review.paperReward(0, fameMultiplier: 1, afterRevision: true),
        closeTo(25 * 1.25, 1e-9),
      );
    });
  });
}
