import 'dart:ui';

final class MeasuredTextLayoutInput {
  const MeasuredTextLayoutInput({
    required this.text,
    required this.fontSize,
    required this.color,
    required this.align,
    required this.direction,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.fontFamily,
    required this.maxWidth,
    required this.lineHeight,
  });

  final String text;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final TextDirection direction;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
}

final class MeasuredTextLineMetrics {
  const MeasuredTextLineMetrics({
    required this.left,
    required this.baseline,
    required this.width,
    required this.height,
  });

  final double left;
  final double baseline;
  final double width;
  final double height;
}

final class MeasuredTextLayout {
  MeasuredTextLayout({
    required this.paintBoundsLocal,
    required this.hitBoundsLocal,
    required this.selectionBoundsLocal,
    required this.editBoundsLocal,
    required Iterable<MeasuredTextLineMetrics> lines,
  }) : lines = List.unmodifiable(lines);

  final Rect paintBoundsLocal;
  final Rect hitBoundsLocal;
  final Rect selectionBoundsLocal;
  final Rect editBoundsLocal;
  final List<MeasuredTextLineMetrics> lines;
}

sealed class MeasuredTextLayoutResult {
  const MeasuredTextLayoutResult();
}

final class MeasuredTextLayoutReady extends MeasuredTextLayoutResult {
  const MeasuredTextLayoutReady(this.layout);

  final MeasuredTextLayout layout;
}

final class MeasuredTextLayoutFailed extends MeasuredTextLayoutResult {
  const MeasuredTextLayoutFailed({required this.reason});

  final String reason;
}

abstract interface class MeasuredTextLayoutPort {
  MeasuredTextLayoutResult measureTextLayout(MeasuredTextLayoutInput input);
}
