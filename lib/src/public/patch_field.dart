/// Tri-state wrapper for patch fields in the public patch API.
///
/// A field can be:
/// - [PatchFieldState.absent]: no change requested,
/// - [PatchFieldState.value]: set to a concrete value,
/// - [PatchFieldState.nullValue]: explicitly set to null.
enum PatchFieldState { absent, value, nullValue }

class PatchField<T> {
  const PatchField.absent() : state = PatchFieldState.absent, _value = null;

  const PatchField.value(T value)
    : state = PatchFieldState.value,
      _value = value;

  const PatchField.nullValue()
    : state = PatchFieldState.nullValue,
      _value = null;

  final PatchFieldState state;
  final T? _value;

  bool get isAbsent => state == PatchFieldState.absent;

  bool get hasValue => state == PatchFieldState.value;

  bool get isNullValue => state == PatchFieldState.nullValue;

  T get value {
    if (!hasValue) {
      throw StateError('PatchField has no concrete value.');
    }
    return _value as T;
  }

  T? get valueOrNull => _value;
}
