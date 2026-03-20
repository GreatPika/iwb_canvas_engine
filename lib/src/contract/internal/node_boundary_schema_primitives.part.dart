part of 'node_boundary_schema.dart';

PatchField<T> _validateNonNullablePatchField<T>(
  PatchField<T> patch, {
  required String name,
  required T Function(T value) transformValue,
}) {
  if (patch.isAbsent) return patch;
  if (patch.isNullValue) {
    throw ArgumentError.value(
      null,
      name,
      'PatchField.nullValue() is invalid for non-nullable field.',
    );
  }
  final value = transformValue(patch.value);
  return PatchField<T>.value(value);
}

PatchField<T?> _validateNullablePatchField<T>(
  PatchField<T?> patch, {
  required T Function(T value) transformValue,
}) {
  if (patch.isAbsent || patch.isNullValue) return patch;
  final rawValue = patch.value;
  if (rawValue == null) {
    return PatchField<T?>.value(null);
  }
  final value = transformValue(rawValue);
  return PatchField<T?>.value(value);
}

Transform2D validateFiniteInvertibleTransform2D(
  Transform2D value, {
  required String name,
}) {
  validatedRequireFiniteDouble(value.a, name: '$name.a');
  validatedRequireFiniteDouble(value.b, name: '$name.b');
  validatedRequireFiniteDouble(value.c, name: '$name.c');
  validatedRequireFiniteDouble(value.d, name: '$name.d');
  validatedRequireFiniteDouble(value.tx, name: '$name.tx');
  validatedRequireFiniteDouble(value.ty, name: '$name.ty');
  if (value.invert() == null) {
    throw ArgumentError.value(
      value.toJsonMap(),
      name,
      'Must be invertible (non-singular).',
    );
  }
  return value;
}

Size validateNonNegativeSize(Size value, {required String name}) {
  return Size(
    NonNegativeFiniteDoubleValue.of(value.width, name: '$name.width').value,
    NonNegativeFiniteDoubleValue.of(value.height, name: '$name.height').value,
  );
}

OwnedList<Offset> validateFiniteOffsetList(
  List<Offset> values, {
  required String name,
}) {
  return OwnedList<Offset>.of(
    List<Offset>.generate(
      values.length,
      (index) =>
          FiniteOffsetValue.of(values[index], name: '$name[$index]').value,
      growable: false,
    ),
  );
}

PatchField<List<Offset>> snapshotOffsetListPatchField(
  PatchField<List<Offset>> patch,
) {
  if (patch.isAbsent) return patch;
  return PatchField<List<Offset>>.value(OwnedList<Offset>.of(patch.value));
}
