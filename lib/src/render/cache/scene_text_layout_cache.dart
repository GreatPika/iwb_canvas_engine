import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../core/text_layout.dart';
import '../../public/snapshot.dart';

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
  final LinkedHashMap<_TextLayoutKey, TextPainter> _entries =
      LinkedHashMap<_TextLayoutKey, TextPainter>();

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

  void clear() => _entries.clear();

  TextPainter getOrBuild({
    required TextNodeSnapshot node,
    required TextStyle textStyle,
    required double? maxWidth,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final safeFontSize = normalizeTextLayoutFontSize(node.fontSize);
    final safeLineHeight = normalizeTextLayoutLineHeight(node.lineHeight);
    final key = _TextLayoutKey(
      text: node.text,
      fontSize: safeFontSize,
      fontFamily: node.fontFamily,
      isBold: node.isBold,
      isItalic: node.isItalic,
      isUnderline: node.isUnderline,
      align: node.align,
      lineHeight: safeLineHeight,
      maxWidth: normalizeTextLayoutMaxWidth(maxWidth),
      color: textStyle.color ?? const Color(0xFF000000),
      textDirection: textDirection,
    );

    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      _debugHitCount += 1;
      return cached;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: node.text, style: textStyle),
      textAlign: node.align,
      textDirection: textDirection,
      maxLines: null,
    );
    if (key.maxWidth == null) {
      textPainter.layout();
    } else {
      textPainter.layout(maxWidth: key.maxWidth!);
    }
    _entries[key] = textPainter;
    _debugBuildCount += 1;
    _evictIfNeeded();
    return textPainter;
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
  });

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

  @override
  bool operator ==(Object other) {
    return other is _TextLayoutKey &&
        other.text == text &&
        other.fontSize == fontSize &&
        other.fontFamily == fontFamily &&
        other.isBold == isBold &&
        other.isItalic == isItalic &&
        other.isUnderline == isUnderline &&
        other.align == align &&
        other.lineHeight == lineHeight &&
        other.maxWidth == maxWidth &&
        other.color == color &&
        other.textDirection == textDirection;
  }

  @override
  int get hashCode => Object.hash(
    text,
    fontSize,
    fontFamily,
    isBold,
    isItalic,
    isUnderline,
    align,
    lineHeight,
    maxWidth,
    color,
    textDirection,
  );
}
