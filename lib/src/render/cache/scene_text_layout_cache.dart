import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../core/text_layout.dart';
import '../../contract/snapshot.dart';

int _requirePositiveCacheEntries(int maxEntries) {
  if (maxEntries <= 0) {
    throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be > 0.');
  }
  return maxEntries;
}

class SceneTextLayoutCache {
  SceneTextLayoutCache({int maxEntries = 256})
    : maxEntries = _requirePositiveCacheEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<_TextLayoutKey, ResolvedTextLayout> _entries =
      LinkedHashMap<_TextLayoutKey, ResolvedTextLayout>();

  int _debugBuildCount = 0;
  int _debugHitCount = 0;
  int _debugEvictCount = 0;

  @visibleForTesting
  int get debugBuildCount => _debugBuildCount;
  @visibleForTesting
  int get debugHitCount => _debugHitCount;
  @visibleForTesting
  int get debugEvictCount => _debugEvictCount;
  @visibleForTesting
  int get debugSize => _entries.length;

  ({int buildCount, int hitCount, int evictCount}) captureProbe() {
    return (
      buildCount: _debugBuildCount,
      hitCount: _debugHitCount,
      evictCount: _debugEvictCount,
    );
  }

  void clear() => _entries.clear();

  /// Returns a render-ready [ResolvedTextLayout] derived only from [node] and
  /// node-owned layout semantics.
  ///
  /// The cache owns `TextStyle` and normalized width derivation so callers
  /// cannot provide a second source of truth for the cached object.
  ResolvedTextLayout getOrBuild({required TextNodeSnapshot node}) {
    final request = _createTextLayoutRequest(node);
    final textStyle = request.buildTextStyle();
    final key = _TextLayoutKey(
      text: request.text,
      fontSize: request.normalizedFontSize,
      fontFamily: request.fontFamily,
      isBold: request.isBold,
      isItalic: request.isItalic,
      isUnderline: request.isUnderline,
      align: request.textAlign,
      lineHeight: request.normalizedLineHeight,
      maxWidth: request.normalizedMaxWidth,
      color: textStyle.color ?? const Color(0xFF000000),
      textDirection: request.textDirection,
    );

    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      _debugHitCount += 1;
      return cached;
    }

    final resolvedTextLayout = request.resolve();
    _entries[key] = resolvedTextLayout;
    _debugBuildCount += 1;
    _evictIfNeeded();
    return resolvedTextLayout;
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
      _debugEvictCount += 1;
    }
  }
}

class _TextLayoutKey {
  const _TextLayoutKey({
    required this.text,
    required this.fontSize,
    required this.fontFamily,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.align,
    required this.lineHeight,
    required this.maxWidth,
    required this.color,
    required this.textDirection,
  }) : _signature = (
         text: text,
         fontSize: fontSize,
         fontFamily: fontFamily,
         isBold: isBold,
         isItalic: isItalic,
         isUnderline: isUnderline,
         align: align,
         lineHeight: lineHeight,
         maxWidth: maxWidth,
         color: color,
         textDirection: textDirection,
       );

  final String text;
  final double fontSize;
  final String? fontFamily;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final TextAlign align;
  final double? lineHeight;
  final double? maxWidth;
  final Color color;
  final TextDirection textDirection;
  final ({
    TextAlign align,
    Color color,
    String? fontFamily,
    double fontSize,
    bool isBold,
    bool isItalic,
    bool isUnderline,
    double? lineHeight,
    double? maxWidth,
    String text,
    TextDirection textDirection,
  })
  _signature;

  @override
  bool operator ==(Object other) =>
      other is _TextLayoutKey && other._signature == _signature;

  @override
  int get hashCode => _signature.hashCode;
}

TextLayoutRequest _createTextLayoutRequest(TextNodeSnapshot node) {
  return TextLayoutRequest.forRenderSnapshot(node);
}
