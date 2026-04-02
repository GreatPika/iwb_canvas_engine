import 'dart:ui';

import 'text_layout.dart';

/// Caches measured text bounds for a text node's layout inputs.
final class TextNodeLayoutState {
  TextNodeLayoutState({
    required String text,
    required double fontSize,
    required TextAlign align,
    required TextDirection textDirection,
    required bool isBold,
    required bool isItalic,
    required bool isUnderline,
    required String? fontFamily,
    required double? maxWidth,
    required double? lineHeight,
  }) : _text = text,
       _fontSize = fontSize,
       _align = align,
       _textDirection = textDirection,
       _isBold = isBold,
       _isItalic = isItalic,
       _isUnderline = isUnderline,
       _fontFamily = fontFamily,
       _maxWidth = maxWidth,
       _lineHeight = lineHeight;

  String _text;
  double _fontSize;
  TextAlign _align;
  TextDirection _textDirection;
  bool _isBold;
  bool _isItalic;
  bool _isUnderline;
  String? _fontFamily;
  double? _maxWidth;
  double? _lineHeight;
  Size? _derivedSizeCache;

  String get text => _text;
  set text(String value) => _setValue(
    currentValue: _text,
    nextValue: value,
    assign: (nextValue) => _text = nextValue,
  );

  double get fontSize => _fontSize;
  set fontSize(double value) => _setValue(
    currentValue: _fontSize,
    nextValue: value,
    assign: (nextValue) => _fontSize = nextValue,
  );

  TextAlign get align => _align;
  set align(TextAlign value) => _setValue(
    currentValue: _align,
    nextValue: value,
    assign: (nextValue) => _align = nextValue,
  );

  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) => _setValue(
    currentValue: _textDirection,
    nextValue: value,
    assign: (nextValue) => _textDirection = nextValue,
  );

  bool get isBold => _isBold;
  set isBold(bool value) => _setValue(
    currentValue: _isBold,
    nextValue: value,
    assign: (nextValue) => _isBold = nextValue,
  );

  bool get isItalic => _isItalic;
  set isItalic(bool value) => _setValue(
    currentValue: _isItalic,
    nextValue: value,
    assign: (nextValue) => _isItalic = nextValue,
  );

  bool get isUnderline => _isUnderline;
  set isUnderline(bool value) => _setValue(
    currentValue: _isUnderline,
    nextValue: value,
    assign: (nextValue) => _isUnderline = nextValue,
  );

  String? get fontFamily => _fontFamily;
  set fontFamily(String? value) => _setValue(
    currentValue: _fontFamily,
    nextValue: value,
    assign: (nextValue) => _fontFamily = nextValue,
  );

  double? get maxWidth => _maxWidth;
  set maxWidth(double? value) => _setValue(
    currentValue: _maxWidth,
    nextValue: value,
    assign: (nextValue) => _maxWidth = nextValue,
  );

  double? get lineHeight => _lineHeight;
  set lineHeight(double? value) => _setValue(
    currentValue: _lineHeight,
    nextValue: value,
    assign: (nextValue) => _lineHeight = nextValue,
  );

  Size derivedSize({required Color color}) {
    final cached = _derivedSizeCache;
    if (cached != null) {
      return cached;
    }
    final measured = TextLayoutRequest(
      text: text,
      color: color,
      fontSize: fontSize,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      textAlign: align,
      fontFamily: fontFamily,
      lineHeight: lineHeight,
      maxWidth: maxWidth,
      textDirection: textDirection,
    ).measure();
    _derivedSizeCache = measured;
    return measured;
  }

  void _setValue<T>({
    required T currentValue,
    required T nextValue,
    required void Function(T nextValue) assign,
  }) {
    if (currentValue == nextValue) {
      return;
    }
    assign(nextValue);
    _derivedSizeCache = null;
  }
}
