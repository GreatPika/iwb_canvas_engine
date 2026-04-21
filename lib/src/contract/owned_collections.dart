import 'dart:collection';
import 'dart:ui';

/// Internal immutable owned list used by contract payloads.
///
/// This keeps collection ownership semantics separate from `PatchField`
/// tri-state semantics and from runtime mutable storage.
final class OwnedList<T> extends UnmodifiableListView<T> {
  OwnedList._(this._values, this._hashCode) : super(_values);

  factory OwnedList.of(Iterable<T> values) {
    if (values is OwnedList<T>) {
      return values;
    }
    final ownedValues = List<T>.unmodifiable(
      List<T>.from(values, growable: false),
    );
    return OwnedList._(ownedValues, Object.hashAll(ownedValues));
  }

  final List<T> _values;
  final int _hashCode;

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
  int get hashCode => _hashCode;
}

/// Returns a canonical immutable owner for stroke/public offset payloads.
///
/// Equivalent offset sequences reuse the same owned instance so read-side cache
/// freshness can rely on owner identity instead of rescanning point values on
/// every lookup.
OwnedList<Offset> canonicalOwnedOffsetList(Iterable<Offset> values) {
  return _canonicalOwnedOffsetListPool.canonicalize(values);
}

final _CanonicalOwnedOffsetListPool _canonicalOwnedOffsetListPool =
    _CanonicalOwnedOffsetListPool();

final class _CanonicalOwnedOffsetListPool {
  final Map<int, List<_CanonicalOwnedOffsetListEntry>> _entriesByHash =
      <int, List<_CanonicalOwnedOffsetListEntry>>{};
  final Expando<bool> _canonicalMarker = Expando<bool>(
    'canonicalOwnedOffsetList',
  );
  late final Finalizer<_CanonicalOwnedOffsetListEntry> _finalizer =
      Finalizer<_CanonicalOwnedOffsetListEntry>((entry) {
        final bucket = _entriesByHash[entry.hash];
        if (bucket == null) {
          return;
        }
        bucket.remove(entry);
        if (bucket.isEmpty) {
          _entriesByHash.remove(entry.hash);
        }
      });

  OwnedList<Offset> canonicalize(Iterable<Offset> values) {
    if (values is OwnedList<Offset> && _canonicalMarker[values] == true) {
      return values;
    }

    final hash = _offsetIterableHash(values);
    final bucket = _entriesByHash[hash];
    if (bucket != null) {
      for (var index = bucket.length - 1; index >= 0; index--) {
        final existing = bucket[index].reference.target;
        if (existing == null) {
          bucket.removeAt(index);
          continue;
        }
        if (existing.hasSameElements(values)) {
          return existing;
        }
      }
      if (bucket.isEmpty) {
        _entriesByHash.remove(hash);
      }
    }

    final owned = values is OwnedList<Offset>
        ? values
        : OwnedList<Offset>.of(values);
    final entry = _CanonicalOwnedOffsetListEntry(hash, owned);
    (_entriesByHash[hash] ??= <_CanonicalOwnedOffsetListEntry>[]).add(entry);
    _canonicalMarker[owned] = true;
    _finalizer.attach(owned, entry, detach: entry);
    return owned;
  }

  static int _offsetIterableHash(Iterable<Offset> values) {
    if (values is OwnedList<Offset>) {
      return values.hashCode;
    }
    return Object.hashAll(values);
  }
}

final class _CanonicalOwnedOffsetListEntry {
  _CanonicalOwnedOffsetListEntry(this.hash, OwnedList<Offset> target)
    : reference = WeakReference<OwnedList<Offset>>(target);

  final int hash;
  final WeakReference<OwnedList<Offset>> reference;
}
