import 'dart:collection';

int requirePositiveScanResistantCacheEntries(int maxEntries) {
  if (maxEntries <= 0) {
    throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be > 0.');
  }
  return maxEntries;
}

/// Bounded render-local cache with fixed probationary/protected queues.
///
/// Policy:
/// - new misses enter the probationary queue as the weakest candidate;
/// - a probationary hit promotes the entry into the protected queue;
/// - protected hits refresh protected recency;
/// - when protected exceeds its bounded share, its least-recent entry is
///   demoted back into the strongest side of probationary;
/// - eviction happens only from the probationary tail.
class ScanResistantCache<K extends Object, V> {
  ScanResistantCache({required int maxEntries})
    : maxEntries = requirePositiveScanResistantCacheEntries(maxEntries),
      _protectedCapacity = maxEntries > 1 ? maxEntries - 1 : 0;

  final int maxEntries;
  final int _protectedCapacity;

  /// Ordered from least-recent to most-recent.
  final LinkedHashMap<K, V> _protectedEntries = LinkedHashMap<K, V>();

  /// Ordered from strongest to weakest candidate.
  final LinkedHashMap<K, V> _probationaryEntries = LinkedHashMap<K, V>();

  int _buildCount = 0;
  int _hitCount = 0;
  int _evictCount = 0;

  int get debugBuildCount => _buildCount;
  int get debugHitCount => _hitCount;
  int get debugEvictCount => _evictCount;
  int get debugSize => _protectedEntries.length + _probationaryEntries.length;

  void clear() {
    _protectedEntries.clear();
    _probationaryEntries.clear();
  }

  V getOrBuild({
    required K key,
    required bool Function(V value) isValid,
    required V Function() build,
  }) {
    final protected = _protectedEntries.remove(key);
    if (protected != null && isValid(protected)) {
      _protectedEntries[key] = protected;
      _hitCount += 1;
      return protected;
    }

    final probationary = _probationaryEntries.remove(key);
    if (probationary != null && isValid(probationary)) {
      _promoteToProtected(key, probationary);
      _hitCount += 1;
      return probationary;
    }

    final value = build();
    _buildCount += 1;
    _probationaryEntries[key] = value;
    _evictIfNeeded();
    return value;
  }

  void _promoteToProtected(K key, V value) {
    _protectedEntries[key] = value;

    while (_protectedEntries.length > _protectedCapacity) {
      final demotedKey = _protectedEntries.keys.first;
      final demotedValue = _protectedEntries.remove(demotedKey);
      if (demotedValue == null) {
        break;
      }
      _prependProbationary(demotedKey, demotedValue);
    }

    _evictIfNeeded();
  }

  void _prependProbationary(K key, V value) {
    final rebuilt = <K, V>{key: value, ..._probationaryEntries};
    _probationaryEntries
      ..clear()
      ..addAll(rebuilt);
  }

  void _evictIfNeeded() {
    while (debugSize > maxEntries && _probationaryEntries.isNotEmpty) {
      final evictedKey = _probationaryEntries.keys.last;
      _probationaryEntries.remove(evictedKey);
      _evictCount += 1;
    }

    assert(
      debugSize <= maxEntries,
      'ScanResistantCache exceeded maxEntries without a probationary tail.',
    );
  }
}
