bool canvasListEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}

int canvasListHash<T>(List<T> values) {
  return Object.hashAll(values);
}

bool canvasJsonMapEquals(
  Map<String, Object?> left,
  Map<String, Object?> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key)) {
      return false;
    }
    if (!_canvasJsonValueEquals(entry.value, right[entry.key])) {
      return false;
    }
  }

  return true;
}

int canvasJsonMapHash(Map<String, Object?> values) {
  final keys = values.keys.toList()..sort();

  return Object.hashAll(
    keys.map((key) => Object.hash(key, _jsonHash(values[key]))),
  );
}

bool _canvasJsonValueEquals(Object? left, Object? right) {
  if (left is Map<String, Object?> && right is Map<String, Object?>) {
    return canvasJsonMapEquals(left, right);
  }
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (!_canvasJsonValueEquals(left[index], right[index])) {
        return false;
      }
    }

    return true;
  }

  return left == right;
}

int _jsonHash(Object? value) {
  if (value is Map<String, Object?>) {
    return canvasJsonMapHash(value);
  }
  if (value is List<Object?>) {
    return Object.hashAll(value.map(_jsonHash));
  }

  return value.hashCode;
}
