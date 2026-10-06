import 'package:flutter_test/flutter_test.dart';
import 'package:idle_theorems/domain/models/producers.dart';
import 'package:idle_theorems/domain/models/resources.dart';

void main() {
  group('Resources.canAffordOf', () {
    // Regression: single-amount costs must be checked against the resource
    // they are denominated in, not always against Counting.
    final r = Resources(counting: 1000, proofing: 0, fame: 0);

    test('counting-denominated cost checks counting', () {
      expect(r.canAffordOf(ResourceKind.counting, 1000), isTrue);
      expect(r.canAffordOf(ResourceKind.counting, 1001), isFalse);
    });

    test('proofing-denominated cost checks proofing, not counting', () {
      expect(r.canAffordOf(ResourceKind.proofing, 50), isFalse);
      expect(Resources(counting: 0, proofing: 50)
          .canAffordOf(ResourceKind.proofing, 50), isTrue);
    });

    test('fame-denominated cost checks fame, not counting', () {
      expect(r.canAffordOf(ResourceKind.fame, 10), isFalse);
      expect(Resources(fame: 10).canAffordOf(ResourceKind.fame, 10), isTrue);
    });
  });
}
