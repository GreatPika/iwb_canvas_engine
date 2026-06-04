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
      layout: _measuredLayoutFor(painter, input),
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

MeasuredTextLayout _measuredLayoutFor(
  TextPainter painter,
  MeasuredTextLayoutInput input,
) {
  final bounds = _alignedTextBoundsFor(
    width: painter.width,
    height: painter.height,
    align: input.align,
    direction: input.direction,
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

Rect _alignedTextBoundsFor({
  required double width,
  required double height,
  required TextAlign align,
  required TextDirection direction,
}) {
  final top = -height / 2;
  final left = switch (_resolvedHorizontalTextAnchor(align, direction)) {
    _HorizontalTextAnchor.left => 0.0,
    _HorizontalTextAnchor.center => -width / 2,
    _HorizontalTextAnchor.right => -width,
  };

  return Rect.fromLTWH(left, top, width, height);
}

_HorizontalTextAnchor _resolvedHorizontalTextAnchor(
  TextAlign align,
  TextDirection direction,
) {
  return switch (align) {
    TextAlign.left => _HorizontalTextAnchor.left,
    TextAlign.right => _HorizontalTextAnchor.right,
    TextAlign.center => _HorizontalTextAnchor.center,
    TextAlign.justify || TextAlign.start => switch (direction) {
      TextDirection.ltr => _HorizontalTextAnchor.left,
      TextDirection.rtl => _HorizontalTextAnchor.right,
    },
    TextAlign.end => switch (direction) {
      TextDirection.ltr => _HorizontalTextAnchor.right,
      TextDirection.rtl => _HorizontalTextAnchor.left,
    },
  };
}

enum _HorizontalTextAnchor { left, center, right }
