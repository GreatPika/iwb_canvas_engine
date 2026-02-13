import 'package:flutter/painting.dart';

import 'nodes.dart';
import 'numeric_clamp.dart';

const TextDirection kDerivedTextLayoutDirection = TextDirection.ltr;

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

TextStyle buildTextStyleForTextLayout({
  required Color color,
  required double fontSize,
  required bool isBold,
  required bool isItalic,
  required bool isUnderline,
  required String? fontFamily,
  required double? lineHeight,
}) {
  final safeFontSize = normalizeTextLayoutFontSize(fontSize);
  final safeLineHeight = normalizeTextLayoutLineHeight(lineHeight);
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

Size measureTextLayoutSize({
  required String text,
  required TextStyle textStyle,
  required TextAlign textAlign,
  required double? maxWidth,
  TextDirection textDirection = kDerivedTextLayoutDirection,
}) {
  final safeMaxWidth = normalizeTextLayoutMaxWidth(maxWidth);
  final painter = TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textAlign: textAlign,
    textDirection: textDirection,
    maxLines: null,
  );
  if (safeMaxWidth == null) {
    painter.layout();
  } else {
    painter.layout(maxWidth: safeMaxWidth);
  }
  return Size(painter.width, painter.height);
}

void recomputeDerivedTextSize(
  TextNode node, {
  TextDirection textDirection = kDerivedTextLayoutDirection,
}) {
  final style = buildTextStyleForTextLayout(
    color: node.color,
    fontSize: node.fontSize,
    isBold: node.isBold,
    isItalic: node.isItalic,
    isUnderline: node.isUnderline,
    fontFamily: node.fontFamily,
    lineHeight: node.lineHeight,
  );
  node.size = measureTextLayoutSize(
    text: node.text,
    textStyle: style,
    textAlign: node.align,
    maxWidth: node.maxWidth,
    textDirection: textDirection,
  );
}
