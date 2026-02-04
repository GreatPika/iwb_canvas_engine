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
