import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Internal immutable owned list used by contract payloads.
///
/// This keeps collection ownership semantics separate from `PatchField`
/// tri-state semantics and from runtime mutable storage.
@internal
final class OwnedList<T> extends UnmodifiableListView<T> {
  OwnedList._(this._values) : super(_values);

  factory OwnedList.of(Iterable<T> values) {
    if (values is OwnedList<T>) {
      return values;
    }
    return OwnedList._(
      List<T>.unmodifiable(List<T>.from(values, growable: false)),
    );
  }

  final List<T> _values;

  bool hasSameElements(Iterable<T> other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is List<T>) {
      if (_values.length != other.length) {
        return false;
      }
      for (var index = 0; index < _values.length; index++) {
        if (_values[index] != other[index]) {
          return false;
        }
      }
      return true;
    }

    var index = 0;
    for (final value in other) {
      if (index >= _values.length || _values[index] != value) {
        return false;
      }
      index += 1;
    }
    return index == _values.length;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OwnedList<T> && hasSameElements(other);
  }

  @override
  int get hashCode => Object.hashAll(_values);
}
