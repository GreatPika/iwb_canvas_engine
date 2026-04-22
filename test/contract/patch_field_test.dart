import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('PatchField.absent marks field as absent at runtime', () {
    final field = PatchField<int>.absent();

    expect(field.state, PatchFieldState.absent);
    expect(field.isAbsent, isTrue);
    expect(field.hasValue, isFalse);
    expect(field.isNullValue, isFalse);
    expect(field.valueOrNull, isNull);
  });

  test(
    'PatchField.value(null) canonicalizes to nullValue for nullable fields',
    () {
      final field = PatchField<int?>.value(null);

      expect(field.state, PatchFieldState.nullValue);
      expect(field.isAbsent, isFalse);
      expect(field.hasValue, isFalse);
      expect(field.isNullValue, isTrue);
      expect(field.valueOrNull, isNull);
      expect(() => field.value, throwsStateError);
    },
  );
}
