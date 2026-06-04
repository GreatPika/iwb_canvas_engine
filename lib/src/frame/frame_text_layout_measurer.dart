import 'package:flutter/painting.dart';

import '../contracts/internal/measured_text_layout.dart';
import 'frame_cache.dart';

final class FrameTextLayoutMeasurer implements MeasuredTextLayoutPort {
  FrameTextLayoutMeasurer({TextLayoutCache? cache})
    : cache = cache ?? TextLayoutCache();

  final TextLayoutCache cache;

  @override
  MeasuredTextLayoutResult measureTextLayout(MeasuredTextLayoutInput input) {
    final validationFailure = _validateInput(input);
    if (validationFailure != null) {
      return MeasuredTextLayoutFailed(reason: validationFailure);
    }

    return MeasuredTextLayoutReady(bindTextLayout(input).layout);
  }

  TextLayoutCacheEntry bindTextLayout(
    MeasuredTextLayoutInput input, {
    String? debugLabel,
  }) {
    final key = textLayoutCacheKeyFor(input);
    final cached = cache.read(key);
    if (cached != null) {
      return cached;
    }

    final painter = _textPainterFor(input);
    final entry = TextLayoutCacheEntry(
      debugLabel: debugLabel ?? input.text,
      painter: painter,
      layout: _measuredLayoutFor(painter),
    );
    cache.write(key, entry);

    return entry;
  }
}

String? _validateInput(MeasuredTextLayoutInput input) {
  if (!input.fontSize.isFinite || input.fontSize < 0) {
    return 'fontSize must be finite and non-negative';
  }
  final maxWidth = input.maxWidth;
  if (maxWidth != null && (!maxWidth.isFinite || maxWidth < 0)) {
    return 'maxWidth must be finite and non-negative when provided';
  }
  final lineHeight = input.lineHeight;
  if (lineHeight != null && (!lineHeight.isFinite || lineHeight < 0)) {
    return 'lineHeight must be finite and non-negative when provided';
  }

  return null;
}

TextLayoutCacheKey textLayoutCacheKeyFor(MeasuredTextLayoutInput input) {
  return TextLayoutCacheKey(
    text: input.text,
    fontSize: input.fontSize,
    colorValue: input.color.toARGB32(),
    alignName: input.align.name,
    directionName: input.direction.name,
    isBold: input.isBold,
    isItalic: input.isItalic,
    isUnderline: input.isUnderline,
    fontFamily: input.fontFamily,
    maxWidth: input.maxWidth,
    lineHeight: input.lineHeight,
  );
}

TextPainter _textPainterFor(MeasuredTextLayoutInput input) {
  return TextPainter(
    text: TextSpan(
      text: input.text,
      style: TextStyle(
        color: input.color,
        fontSize: input.fontSize,
        fontFamily: input.fontFamily,
        fontWeight: input.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: input.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: input.isUnderline ? TextDecoration.underline : null,
        height: input.lineHeight,
      ),
    ),
    textAlign: input.align,
    textDirection: input.direction,
  )..layout(maxWidth: input.maxWidth ?? double.infinity);
}

MeasuredTextLayout _measuredLayoutFor(TextPainter painter) {
  final bounds = Rect.fromCenter(
    center: Offset.zero,
    width: painter.width,
    height: painter.height,
  );

  return MeasuredTextLayout(
    paintBoundsLocal: bounds,
    hitBoundsLocal: bounds,
    selectionBoundsLocal: bounds,
    editBoundsLocal: bounds,
    lines: [
      for (final line in painter.computeLineMetrics())
        MeasuredTextLineMetrics(
          left: line.left,
          baseline: line.baseline,
          width: line.width,
          height: line.height,
        ),
    ],
  );
}
