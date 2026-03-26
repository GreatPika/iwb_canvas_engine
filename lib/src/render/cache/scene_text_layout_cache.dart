import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../core/numeric_clamp.dart';
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

  /// Returns a render-ready [TextPainter] derived only from [node] and
  /// [textDirection].
  ///
  /// The cache owns `TextStyle` and normalized width derivation so callers
  /// cannot provide a second source of truth for the cached object.
  TextPainter getOrBuild({
    required TextNodeSnapshot node,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final textStyle = _buildTextStyle(node);
    final safeFontSize = normalizeTextLayoutFontSize(node.fontSize);
    final safeLineHeight = normalizeTextLayoutLineHeight(node.lineHeight);
    final layoutMaxWidth = normalizeTextLayoutMaxWidth(node.maxWidth);
    final key = _TextLayoutKey(
      text: node.text,
      fontSize: safeFontSize,
      fontFamily: node.fontFamily,
      isBold: node.isBold,
      isItalic: node.isItalic,
      isUnderline: node.isUnderline,
      align: node.align,
      lineHeight: safeLineHeight,
      maxWidth: layoutMaxWidth,
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
    _layoutTextPainter(textPainter, layoutMaxWidth);
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

  TextStyle _buildTextStyle(TextNodeSnapshot node) {
    return buildTextStyleForTextLayout(
      color: _renderReadyTextColor(node),
      fontSize: node.fontSize,
      isBold: node.isBold,
      isItalic: node.isItalic,
      isUnderline: node.isUnderline,
      fontFamily: node.fontFamily,
      lineHeight: node.lineHeight,
    );
  }
}

TextPainter buildSceneTextPainter({
  required TextNodeSnapshot node,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final textStyle = buildTextStyleForTextLayout(
    color: _renderReadyTextColor(node),
    fontSize: node.fontSize,
    isBold: node.isBold,
    isItalic: node.isItalic,
    isUnderline: node.isUnderline,
    fontFamily: node.fontFamily,
    lineHeight: node.lineHeight,
  );
  final textPainter = TextPainter(
    text: TextSpan(text: node.text, style: textStyle),
    textAlign: node.align,
    textDirection: textDirection,
    maxLines: null,
  );
  _layoutTextPainter(textPainter, normalizeTextLayoutMaxWidth(node.maxWidth));
  return textPainter;
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

Color _renderReadyTextColor(TextNodeSnapshot node) {
  final alpha = (_textOpacity01(node.opacity) * 255.0).round().clamp(0, 255);
  return node.color.withAlpha(alpha);
}

void _layoutTextPainter(TextPainter textPainter, double? layoutMaxWidth) {
  if (layoutMaxWidth == null) {
    textPainter.layout();
  } else {
    textPainter.layout(maxWidth: layoutMaxWidth);
  }
}

double _textOpacity01(double opacity) {
  return clampNonNegativeFinite(opacity).clamp(0.0, 1.0);
}
