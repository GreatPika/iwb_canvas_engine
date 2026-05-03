import 'package:flutter/painting.dart';

import '../contract/snapshot.dart';
import 'numeric_clamp.dart';

const TextDirection kDerivedTextLayoutDirection = TextDirection.ltr;

class ResolvedTextLayout {
  const ResolvedTextLayout({
    required this.textPainter,
    required this.measuredSize,
  });

  final TextPainter textPainter;
  final Size measuredSize;
}

class TextLayoutRequest {
  const TextLayoutRequest({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.textAlign,
    required this.fontFamily,
    required this.lineHeight,
    required this.maxWidth,
    this.textDirection = kDerivedTextLayoutDirection,
  });

  factory TextLayoutRequest.forSnapshot(TextNodeSnapshot node) {
    return TextLayoutRequest(
      text: node.text,
      color: node.color,
      fontSize: node.fontSize,
      isBold: node.isBold,
      isItalic: node.isItalic,
      isUnderline: node.isUnderline,
      textAlign: node.align,
      fontFamily: node.fontFamily,
      lineHeight: node.lineHeight,
      maxWidth: node.maxWidth,
      textDirection: node.textDirection,
    );
  }

  factory TextLayoutRequest.forRenderSnapshot(TextNodeSnapshot node) {
    return TextLayoutRequest(
      text: node.text,
      color: _renderReadyTextColor(node.color, node.opacity),
      fontSize: node.fontSize,
      isBold: node.isBold,
      isItalic: node.isItalic,
      isUnderline: node.isUnderline,
      textAlign: node.align,
      fontFamily: node.fontFamily,
      lineHeight: node.lineHeight,
      maxWidth: node.maxWidth,
      textDirection: node.textDirection,
    );
  }

  final String text;
  final Color color;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final TextAlign textAlign;
  final String? fontFamily;
  final double? lineHeight;
  final double? maxWidth;
  final TextDirection textDirection;

  double get normalizedFontSize => normalizeTextLayoutFontSize(fontSize);
  double? get normalizedLineHeight => normalizeTextLayoutLineHeight(lineHeight);
  double? get normalizedMaxWidth => normalizeTextLayoutMaxWidth(maxWidth);

  TextStyle buildTextStyle() {
    final safeFontSize = normalizedFontSize;
    final safeLineHeight = normalizedLineHeight;
    return TextStyle(
      color: color,
      fontSize: safeFontSize,
      fontFamily: fontFamily,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
      // lineHeight is stored in logical units, TextStyle.height expects factor.
      height: safeLineHeight == null ? null : safeLineHeight / safeFontSize,
    );
  }

  ResolvedTextLayout resolve() {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: buildTextStyle()),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: null,
    );
    final safeMaxWidth = normalizedMaxWidth;
    if (safeMaxWidth == null) {
      textPainter.layout();
    } else {
      textPainter.layout(maxWidth: safeMaxWidth);
    }
    return ResolvedTextLayout(
      textPainter: textPainter,
      measuredSize: Size(textPainter.width, textPainter.height),
    );
  }

  Size measure() {
    return resolve().measuredSize;
  }
}

double normalizeTextLayoutFontSize(double fontSize) {
  return clampPositiveFinite(fontSize, fallback: 24);
}

double? normalizeTextLayoutLineHeight(double? lineHeight) {
  if (lineHeight == null) return null;
  if (!lineHeight.isFinite || lineHeight <= 0) return null;
  return lineHeight;
}

double? normalizeTextLayoutMaxWidth(double? maxWidth) {
  if (maxWidth == null) return null;
  if (!maxWidth.isFinite || maxWidth <= 0) return null;
  return maxWidth;
}

Color _renderReadyTextColor(Color color, double opacity) {
  final alpha = (_textOpacity01(opacity) * 255.0).round().clamp(0, 255);
  return color.withAlpha(alpha);
}

double _textOpacity01(double opacity) {
  return clampNonNegativeFinite(opacity).clamp(0.0, 1.0);
}
