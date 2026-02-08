import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('P1-4: SceneTextLayoutCache caches TextPainter layouts', () {
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final node = TextNode(
      id: 't-1',
      text: 'Hello',
      size: const ui.Size(100, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    final style = const TextStyle(fontSize: 14, color: ui.Color(0xFF000000));

    final tp1 = cache.getOrBuild(node: node, textStyle: style, maxWidth: 100);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 0);
    expect(cache.debugSize, 1);

    final tp2 = cache.getOrBuild(node: node, textStyle: style, maxWidth: 100);
    expect(identical(tp1, tp2), isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
    expect(cache.debugSize, 1);
  });

  test('P1-5: SceneTextLayoutCache rebuilds on maxWidth change', () {
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final node = TextNode(
      id: 't-1',
      text: 'Hello',
      size: const ui.Size(100, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    final style = const TextStyle(fontSize: 14, color: ui.Color(0xFF000000));

    final tp1 = cache.getOrBuild(node: node, textStyle: style, maxWidth: 80);
    final tp2 = cache.getOrBuild(node: node, textStyle: style, maxWidth: 120);
    expect(identical(tp1, tp2), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test('SceneTextLayoutCache key includes textDirection', () {
    // INV:INV-RENDER-TEXT-DIRECTION-ALIGNMENT
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final node = TextNode(
      id: 't-dir',
      text: 'Hello',
      size: const ui.Size(100, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    final style = const TextStyle(fontSize: 14, color: ui.Color(0xFF000000));

    final ltr = cache.getOrBuild(
      node: node,
      textStyle: style,
      maxWidth: 100,
      textDirection: TextDirection.ltr,
    );
    final rtl = cache.getOrBuild(
      node: node,
      textStyle: style,
      maxWidth: 100,
      textDirection: TextDirection.rtl,
    );

    expect(identical(ltr, rtl), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test('SceneTextLayoutCache key includes valid lineHeight', () {
    // INV:INV-CORE-RUNTIME-NUMERIC-SANITIZATION
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final node = TextNode(
      id: 't-lineHeight',
      text: 'Hello',
      size: const ui.Size(100, 20),
      fontSize: 14,
      lineHeight: 28,
      color: const ui.Color(0xFF000000),
    );
    final style = const TextStyle(fontSize: 14, color: ui.Color(0xFF000000));

    cache.getOrBuild(node: node, textStyle: style, maxWidth: 100);
    expect(cache.debugBuildCount, 1);
  });

  test('SceneTextLayoutCache key excludes node identity and box height', () {
    // INV:INV-RENDER-TEXT-LAYOUT-CACHE-KEY
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final nodeA = TextNode(
      id: 'node-a',
      text: 'Shared',
      size: const ui.Size(100, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    final nodeB = TextNode(
      id: 'node-b',
      text: 'Shared',
      size: const ui.Size(100, 200),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    const style = TextStyle(fontSize: 14, color: ui.Color(0xFF000000));

    final tp1 = cache.getOrBuild(node: nodeA, textStyle: style, maxWidth: 100);
    final tp2 = cache.getOrBuild(node: nodeB, textStyle: style, maxWidth: 100);

    expect(identical(tp1, tp2), isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
  });

  test('SceneTextLayoutCache key includes paint color', () {
    final cache = SceneTextLayoutCache(maxEntries: 8);
    final node = TextNode(
      id: 'node-color',
      text: 'Shared',
      size: const ui.Size(100, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    const styleBlack = TextStyle(fontSize: 14, color: ui.Color(0xFF000000));
    const styleRed = TextStyle(fontSize: 14, color: ui.Color(0xFFFF0000));

    final tp1 = cache.getOrBuild(
      node: node,
      textStyle: styleBlack,
      maxWidth: 100,
    );
    final tp2 = cache.getOrBuild(
      node: node,
      textStyle: styleRed,
      maxWidth: 100,
    );

    expect(identical(tp1, tp2), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test('P1-6: SceneTextLayoutCache evicts oldest entries (LRU)', () {
    final cache = SceneTextLayoutCache(maxEntries: 2);
    final style = const TextStyle(fontSize: 14, color: ui.Color(0xFF000000));
    final a = TextNode(
      id: 'a',
      text: 'A',
      size: const ui.Size(20, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    final b = TextNode(
      id: 'b',
      text: 'B',
      size: const ui.Size(20, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    final c = TextNode(
      id: 'c',
      text: 'C',
      size: const ui.Size(20, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );

    cache.getOrBuild(node: a, textStyle: style, maxWidth: 20);
    cache.getOrBuild(node: b, textStyle: style, maxWidth: 20);
    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 0);

    cache.getOrBuild(node: a, textStyle: style, maxWidth: 20); // hit
    expect(cache.debugHitCount, 1);

    cache.getOrBuild(node: c, textStyle: style, maxWidth: 20); // evict B
    expect(cache.debugEvictCount, 1);
    expect(cache.debugSize, 2);

    cache.getOrBuild(node: b, textStyle: style, maxWidth: 20); // rebuild
    expect(cache.debugBuildCount, 4);
  });
}
