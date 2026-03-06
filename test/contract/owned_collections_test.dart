import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/owned_collections.dart';

void main() {
  test('OwnedList detaches from mutable input and stays read-only', () {
    final source = <Offset>[const Offset(1, 2), const Offset(3, 4)];

    final owned = OwnedList<Offset>.of(source);
    source[1] = const Offset(30, 40);

    expect(owned, const <Offset>[Offset(1, 2), Offset(3, 4)]);
    expect(() => owned.add(const Offset(5, 6)), throwsUnsupportedError);
  });

  test('OwnedList uses value-based equality only for owned lists', () {
    final emptyA = OwnedList<Offset>.of(const <Offset>[]);
    final emptyB = OwnedList<Offset>.of(const <Offset>[]);
    final valuesA = OwnedList<Offset>.of(const <Offset>[
      Offset(1, 1),
      Offset(2, 2),
    ]);
    final valuesB = OwnedList<Offset>.of(const <Offset>[
      Offset(1, 1),
      Offset(2, 2),
    ]);

    expect(emptyA, emptyB);
    expect(emptyA.hashCode, emptyB.hashCode);
    expect(valuesA, valuesB);
    expect(valuesA.hashCode, valuesB.hashCode);
    expect(valuesA == const <Offset>[Offset(1, 1), Offset(2, 2)], isFalse);
    expect(emptyA == const <Offset>[], isFalse);
  });

  test('OwnedList reuses an already owned input instance', () {
    final source = OwnedList<Offset>.of(const <Offset>[
      Offset(1, 2),
      Offset(3, 4),
    ]);

    final reused = OwnedList<Offset>.of(source);

    expect(identical(reused, source), isTrue);
  });

  test('OwnedList compares non-list iterables by element values', () {
    final owned = OwnedList<Offset>.of(const <Offset>[
      Offset(1, 2),
      Offset(3, 4),
    ]);

    expect(
      owned.hasSameElements(
        const <Offset>[Offset(1, 2), Offset(3, 4)].where((_) => true),
      ),
      isTrue,
    );
    expect(
      owned.hasSameElements(const <Offset>[Offset(1, 2)].where((_) => true)),
      isFalse,
    );
    expect(
      owned.hasSameElements(
        const <Offset>[Offset(1, 2), Offset(30, 40)].where((_) => true),
      ),
      isFalse,
    );
  });
}
