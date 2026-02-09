import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/v2/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/v2/render/scene_painter_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SceneTextLayoutCacheV2 caches TextPainter layouts', () {
    final cache = SceneTextLayoutCacheV2(maxEntries: 8);
    final node = TextNodeSnapshot(
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

  test('SceneTextLayoutCacheV2 rebuilds on maxWidth change', () {
    final cache = SceneTextLayoutCacheV2(maxEntries: 8);
    final node = TextNodeSnapshot(
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

  test('SceneTextLayoutCacheV2 key includes textDirection', () {
    final cache = SceneTextLayoutCacheV2(maxEntries: 8);
    final node = TextNodeSnapshot(
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

  test('SceneTextLayoutCacheV2 key excludes node identity and box height', () {
    final cache = SceneTextLayoutCacheV2(maxEntries: 8);
    final nodeA = TextNodeSnapshot(
      id: 'node-a',
      text: 'Shared',
      size: const ui.Size(100, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    final nodeB = TextNodeSnapshot(
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

  test('SceneTextLayoutCacheV2 key includes paint color', () {
    final cache = SceneTextLayoutCacheV2(maxEntries: 8);
    final node = TextNodeSnapshot(
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

  test('SceneTextLayoutCacheV2 key includes positive lineHeight', () {
    final cache = SceneTextLayoutCacheV2(maxEntries: 8);
    final node = TextNodeSnapshot(
      id: 'node-line-height',
      text: 'Shared',
      size: const ui.Size(100, 20),
      fontSize: 14,
      lineHeight: 1.5,
      color: const ui.Color(0xFF000000),
    );
    const style = TextStyle(fontSize: 14, color: ui.Color(0xFF000000));

    final first = cache.getOrBuild(node: node, textStyle: style, maxWidth: 100);
    final second = cache.getOrBuild(
      node: node,
      textStyle: style,
      maxWidth: 100,
    );
    expect(identical(first, second), isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
  });

  test('SceneTextLayoutCacheV2 normalizes invalid lineHeight and maxWidth', () {
    final cache = SceneTextLayoutCacheV2(maxEntries: 8);
    final node = TextNodeSnapshot(
      id: 'node-invalid',
      text: 'Shared',
      size: const ui.Size(100, 20),
      fontSize: 14,
      lineHeight: -5,
      color: const ui.Color(0xFF000000),
    );
    const style = TextStyle(fontSize: 14, color: ui.Color(0xFF000000));

    final first = cache.getOrBuild(
      node: node,
      textStyle: style,
      maxWidth: double.nan,
    );
    final second = cache.getOrBuild(
      node: node,
      textStyle: style,
      maxWidth: -100,
    );

    expect(identical(first, second), isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
  });

  test('SceneTextLayoutCacheV2 evicts least-recent entries (LRU)', () {
    final cache = SceneTextLayoutCacheV2(maxEntries: 2);
    final style = const TextStyle(fontSize: 14, color: ui.Color(0xFF000000));
    final a = TextNodeSnapshot(
      id: 'a',
      text: 'A',
      size: const ui.Size(20, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    final b = TextNodeSnapshot(
      id: 'b',
      text: 'B',
      size: const ui.Size(20, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    final c = TextNodeSnapshot(
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

    cache.getOrBuild(node: a, textStyle: style, maxWidth: 20);
    expect(cache.debugHitCount, 1);

    cache.getOrBuild(node: c, textStyle: style, maxWidth: 20);
    expect(cache.debugEvictCount, 1);
    expect(cache.debugSize, 2);

    cache.getOrBuild(node: b, textStyle: style, maxWidth: 20);
    expect(cache.debugBuildCount, 4);
  });

  test('SceneTextLayoutCacheV2 clear drops entries', () {
    final cache = SceneTextLayoutCacheV2(maxEntries: 8);
    final node = TextNodeSnapshot(
      id: 't-clear',
      text: 'Hello',
      size: const ui.Size(100, 20),
      fontSize: 14,
      color: const ui.Color(0xFF000000),
    );
    final style = const TextStyle(fontSize: 14, color: ui.Color(0xFF000000));

    cache.getOrBuild(node: node, textStyle: style, maxWidth: 100);
    expect(cache.debugSize, 1);
    cache.clear();
    expect(cache.debugSize, 0);
  });
}
