import 'package:flutter/foundation.dart';

final class FrameCacheProbe {
  const FrameCacheProbe({
    required this.entries,
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.writes,
  });

  final int entries;
  final int hits;
  final int misses;
  final int evictions;
  final int writes;
}

base class FrameLruCache<K extends Object, V extends Object> {
  FrameLruCache({required this.capacity}) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'must be positive');
    }
  }

  final int capacity;
  final Map<K, V> _entries = {};
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _writes = 0;

  V? read(K key) {
    final value = _entries.remove(key);
    if (value == null) {
      _misses += 1;

      return null;
    }
    _hits += 1;
    _entries[key] = value;

    return value;
  }

  void write(K key, V value) {
    if (_entries.remove(key) != null) {
      _entries[key] = value;
      _writes += 1;

      return;
    }
    if (_entries.length >= capacity) {
      _entries.remove(_entries.keys.first);
      _evictions += 1;
    }
    _entries[key] = value;
    _writes += 1;
  }

  bool containsKey(K key) => _entries.containsKey(key);

  FrameCacheProbe get probe {
    return FrameCacheProbe(
      entries: _entries.length,
      hits: _hits,
      misses: _misses,
      evictions: _evictions,
      writes: _writes,
    );
  }
}

base class FrameScanResistantLruCache<K extends Object, V extends Object> {
  FrameScanResistantLruCache({required this.capacity}) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'must be positive');
    }
  }

  final int capacity;
  final Map<K, V> _protected = {};
  final Map<K, V> _probationary = {};
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _writes = 0;

  V? read(K key) {
    final protectedValue = _protected.remove(key);
    if (protectedValue != null) {
      _protected[key] = protectedValue;
      _hits += 1;

      return protectedValue;
    }
    final probationaryValue = _probationary.remove(key);
    if (probationaryValue == null) {
      _misses += 1;

      return null;
    }
    _hits += 1;
    _protected[key] = probationaryValue;
    _rebalanceProtectedEntries();

    return probationaryValue;
  }

  void write(K key, V value) {
    if (_protected.remove(key) != null) {
      _protected[key] = value;
      _writes += 1;

      return;
    }
    if (_probationary.remove(key) != null) {
      _probationary[key] = value;
      _writes += 1;

      return;
    }
    _probationary[key] = value;
    _writes += 1;
    _evictUntilBounded();
  }

  bool containsKey(K key) {
    return _protected.containsKey(key) || _probationary.containsKey(key);
  }

  FrameCacheProbe get probe {
    return FrameCacheProbe(
      entries: _protected.length + _probationary.length,
      hits: _hits,
      misses: _misses,
      evictions: _evictions,
      writes: _writes,
    );
  }

  int get protectedEntryCount => _protected.length;
  int get probationaryEntryCount => _probationary.length;

  void _rebalanceProtectedEntries() {
    final maxProtected = capacity ~/ 2;
    while (_protected.length > maxProtected) {
      final oldestKey = _protected.keys.first;
      final oldestValue = _protected.remove(oldestKey);
      if (oldestValue != null) {
        _probationary[oldestKey] = oldestValue;
      }
    }
    _evictUntilBounded();
  }

  void _evictUntilBounded() {
    while (_protected.length + _probationary.length > capacity) {
      if (_probationary.isNotEmpty) {
        _probationary.remove(_probationary.keys.first);
        _evictions += 1;

        continue;
      }
      _protected.remove(_protected.keys.first);
      _evictions += 1;
    }
  }
}

final class TextLayoutCache
    extends
        FrameScanResistantLruCache<TextLayoutCacheKey, TextLayoutCacheEntry> {
  TextLayoutCache() : super(capacity: 1024);
}

final class PathGeometryCache
    extends
        FrameScanResistantLruCache<
          PathGeometryCacheKey,
          PathGeometryCacheEntry
        > {
  PathGeometryCache() : super(capacity: 1024);
}

final class StrokePathCache
    extends
        FrameScanResistantLruCache<StrokePathCacheKey, StrokePathCacheEntry> {
  StrokePathCache() : super(capacity: 1024);
}

@immutable
final class TextLayoutCacheKey {
  const TextLayoutCacheKey({
    required this.text,
    required this.fontSize,
    required this.colorValue,
    required this.alignName,
    required this.directionName,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.fontFamily,
    required this.maxWidth,
    required this.lineHeight,
  });

  final String text;
  final double fontSize;
  final int colorValue;
  final String alignName;
  final String directionName;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;

  @override
  bool operator ==(Object other) {
    return other is TextLayoutCacheKey &&
        other.text == text &&
        other.fontSize == fontSize &&
        other.colorValue == colorValue &&
        other.alignName == alignName &&
        other.directionName == directionName &&
        other.isBold == isBold &&
        other.isItalic == isItalic &&
        other.isUnderline == isUnderline &&
        other.fontFamily == fontFamily &&
        other.maxWidth == maxWidth &&
        other.lineHeight == lineHeight;
  }

  @override
  int get hashCode {
    return Object.hash(
      text,
      fontSize,
      colorValue,
      alignName,
      directionName,
      isBold,
      isItalic,
      isUnderline,
      fontFamily,
      maxWidth,
      lineHeight,
    );
  }
}

@immutable
final class PathGeometryCacheKey {
  const PathGeometryCacheKey({
    required this.pathData,
    required this.fillRuleName,
    required this.strokeWidth,
  });

  final String pathData;
  final String fillRuleName;
  final double strokeWidth;

  @override
  bool operator ==(Object other) {
    return other is PathGeometryCacheKey &&
        other.pathData == pathData &&
        other.fillRuleName == fillRuleName &&
        other.strokeWidth == strokeWidth;
  }

  @override
  int get hashCode => Object.hash(pathData, fillRuleName, strokeWidth);
}

@immutable
final class StrokePathCacheKey {
  const StrokePathCacheKey({
    required this.pointsKey,
    required this.thickness,
    required this.transformScaleKey,
  });

  final String pointsKey;
  final double thickness;
  final String transformScaleKey;

  @override
  bool operator ==(Object other) {
    return other is StrokePathCacheKey &&
        other.pointsKey == pointsKey &&
        other.thickness == thickness &&
        other.transformScaleKey == transformScaleKey;
  }

  @override
  int get hashCode => Object.hash(pointsKey, thickness, transformScaleKey);
}

final class TextLayoutCacheEntry {
  const TextLayoutCacheEntry({required this.debugLabel});

  final String debugLabel;
}

final class PathGeometryCacheEntry {
  const PathGeometryCacheEntry({required this.debugLabel});

  final String debugLabel;
}

final class StrokePathCacheEntry {
  const StrokePathCacheEntry({required this.debugLabel});

  final String debugLabel;
}
