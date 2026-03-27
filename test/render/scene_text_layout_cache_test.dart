import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render text cache consumes shared core text layout owner', () {
    final source = File(
      'lib/src/render/cache/scene_text_layout_cache.dart',
    ).readAsStringSync();

    expect(source, contains("import '../../core/text_layout.dart';"));
    expect(source, contains('TextLayoutRequest _createTextLayoutRequest('));
    expect(source, contains('final request = _createTextLayoutRequest('));
    expect(source, contains('request.buildTextStyle()'));
    expect(source, isNot(contains('recomputeDerivedTextSize(')));
    expect(source, isNot(contains('freezePayloadMap(')));
    expect(source, isNot(contains('_GeneratedIdAllocator')));
  });

  test('SceneTextLayoutCache rejects non-positive maxEntries', () {
    expect(() => SceneTextLayoutCache(maxEntries: 0), throwsArgumentError);
    expect(() => SceneTextLayoutCache(maxEntries: -1), throwsArgumentError);
  });

  test('SceneTextLayoutCache caches render-ready TextPainters', () {
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final node = _textNode(
      id: 't-1',
      maxWidth: 100,
      opacity: 0.5,
      isBold: true,
    );

    final first = cache.getOrBuild(node: node);
    final second = cache.getOrBuild(node: node);

    expect(identical(first, second), isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
    expect(cache.debugSize, 1);

    final span = first.text;
    expect(span, isA<TextSpan>());
    final style = (span as TextSpan).style;
    expect(style, isNotNull);
    expect(style?.color, _effectiveTextColor(node.color, node.opacity));
    expect(style?.fontWeight, FontWeight.bold);
  });

  test('SceneTextLayoutCache rebuilds on maxWidth change', () {
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final first = cache.getOrBuild(
      node: _textNode(id: 't-width', maxWidth: 80),
    );
    final second = cache.getOrBuild(
      node: _textNode(id: 't-width', maxWidth: 120),
    );

    expect(identical(first, second), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test('SceneTextLayoutCache key includes textDirection', () {
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final node = _textNode(id: 't-dir', maxWidth: 100);

    final ltr = cache.getOrBuild(node: node, textDirection: TextDirection.ltr);
    final rtl = cache.getOrBuild(node: node, textDirection: TextDirection.rtl);

    expect(identical(ltr, rtl), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test('SceneTextLayoutCache key excludes node identity and box height', () {
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final first = cache.getOrBuild(
      node: _textNode(
        id: 'node-a',
        size: const ui.Size(100, 20),
        maxWidth: 100,
      ),
    );
    final second = cache.getOrBuild(
      node: _textNode(
        id: 'node-b',
        size: const ui.Size(100, 200),
        maxWidth: 100,
      ),
    );

    expect(identical(first, second), isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
  });

  test(
    'SceneTextLayoutCache key includes paint-affecting color and opacity',
    () {
      final cache = SceneTextLayoutCache(maxEntries: 8);
      final opaqueBlack = cache.getOrBuild(
        node: _textNode(
          id: 'node-color',
          color: const ui.Color(0xFF000000),
          opacity: 1,
          maxWidth: 100,
        ),
      );
      final translucentBlack = cache.getOrBuild(
        node: _textNode(
          id: 'node-color',
          color: const ui.Color(0xFF000000),
          opacity: 0.5,
          maxWidth: 100,
        ),
      );
      final opaqueRed = cache.getOrBuild(
        node: _textNode(
          id: 'node-color',
          color: const ui.Color(0xFFFF0000),
          opacity: 1,
          maxWidth: 100,
        ),
      );

      expect(identical(opaqueBlack, translucentBlack), isFalse);
      expect(identical(opaqueBlack, opaqueRed), isFalse);
      expect(cache.debugBuildCount, 3);
      expect(cache.debugHitCount, 0);
    },
  );

  test('SceneTextLayoutCache key includes positive lineHeight', () {
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final first = cache.getOrBuild(
      node: _textNode(id: 'node-line-height', lineHeight: 18, maxWidth: 100),
    );
    final second = cache.getOrBuild(
      node: _textNode(id: 'node-line-height', lineHeight: 24, maxWidth: 100),
    );

    expect(identical(first, second), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test(
    'SceneTextLayoutCache normalizes invalid fontSize, lineHeight, and maxWidth',
    () {
      final cache = SceneTextLayoutCache(maxEntries: 8);
      final first = cache.getOrBuild(
        node: textNodeSnapshotFromValidated(
          id: 'node-invalid',
          text: 'Shared',
          size: const ui.Size(100, 20),
          fontSize: -5,
          lineHeight: -1,
          maxWidth: double.nan,
          color: const ui.Color(0xFF000000),
        ),
      );
      final second = cache.getOrBuild(
        node: textNodeSnapshotFromValidated(
          id: 'node-invalid',
          text: 'Shared',
          size: const ui.Size(100, 20),
          fontSize: double.nan,
          lineHeight: 0,
          maxWidth: -100,
          color: const ui.Color(0xFF000000),
        ),
      );

      expect(identical(first, second), isTrue);
      expect(cache.debugBuildCount, 1);
      expect(cache.debugHitCount, 1);
    },
  );

  test('SceneTextLayoutCache evicts least-recent entries (LRU)', () {
    final cache = SceneTextLayoutCache(maxEntries: 2);
    final a = _textNode(id: 'a', text: 'A', maxWidth: 20);
    final b = _textNode(id: 'b', text: 'B', maxWidth: 20);
    final c = _textNode(id: 'c', text: 'C', maxWidth: 20);

    cache.getOrBuild(node: a);
    cache.getOrBuild(node: b);
    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 0);

    cache.getOrBuild(node: a);
    expect(cache.debugHitCount, 1);

    cache.getOrBuild(node: c);
    expect(cache.debugEvictCount, 1);
    expect(cache.debugSize, 2);

    cache.getOrBuild(node: b);
    expect(cache.debugBuildCount, 4);
  });

  test('SceneTextLayoutCache clear drops entries', () {
    final cache = SceneTextLayoutCache(maxEntries: 8);
    cache.getOrBuild(node: _textNode(id: 't-clear', maxWidth: 100));

    expect(cache.debugSize, 1);
    cache.clear();
    expect(cache.debugSize, 0);
  });
}

TextNodeSnapshot _textNode({
  required String id,
  String text = 'Hello',
  ui.Size size = const ui.Size(100, 20),
  double fontSize = 14,
  ui.Color color = const ui.Color(0xFF000000),
  TextAlign align = TextAlign.left,
  bool isBold = false,
  bool isItalic = false,
  bool isUnderline = false,
  String? fontFamily,
  double? maxWidth,
  double? lineHeight,
  double opacity = 1,
}) {
  return TextNodeSnapshot(
    id: id,
    text: text,
    size: size,
    fontSize: fontSize,
    color: color,
    align: align,
    isBold: isBold,
    isItalic: isItalic,
    isUnderline: isUnderline,
    fontFamily: fontFamily,
    maxWidth: maxWidth,
    lineHeight: lineHeight,
    opacity: opacity,
  );
}

ui.Color _effectiveTextColor(ui.Color color, double opacity) {
  final alpha = (opacity.clamp(0.0, 1.0) * 255.0).round().clamp(0, 255);
  return color.withAlpha(alpha);
}
