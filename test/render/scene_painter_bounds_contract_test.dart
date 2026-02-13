import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _extractMethodBody({
  required String source,
  required String methodStart,
}) {
  final startIndex = source.indexOf(methodStart);
  if (startIndex < 0) {
    throw StateError('Method signature not found: $methodStart');
  }
  var bodyStart = -1;
  var parenDepth = 0;
  for (var i = startIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
    } else if (char == '{' && parenDepth == 0) {
      bodyStart = i;
      break;
    }
  }
  if (bodyStart < 0) {
    throw StateError('Method body start not found: $methodStart');
  }

  var depth = 1;
  for (var i = bodyStart + 1; i < source.length; i++) {
    final char = source[i];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(bodyStart + 1, i);
      }
    }
  }
  throw StateError('Method body end not found: $methodStart');
}

void main() {
  test(
    '_nodeBoundsWorld delegates world bounds to RenderGeometryCache only',
    () {
      final source = File(
        'lib/src/render/scene_painter.dart',
      ).readAsStringSync();
      final body = _extractMethodBody(
        source: source,
        methodStart: 'Rect _nodeBoundsWorld(',
      );

      expect(
        body,
        contains('final bounds = _geometryCache.get(node).worldBounds;'),
      );
      expect(body, isNot(contains('parseSvgPathData')));
      expect(body, isNot(contains('buildLocalPath')));
      expect(body, isNot(contains('_buildPathNode')));
      expect(body, isNot(contains('getBounds(')));
    },
  );

  test('_drawPathNode reads localPath from RenderGeometryCache only', () {
    final source = File('lib/src/render/scene_painter.dart').readAsStringSync();
    final body = _extractMethodBody(
      source: source,
      methodStart: 'void _drawPathNode(',
    );

    expect(
      body,
      contains('final localPath = _geometryCache.get(node).localPath;'),
    );
    expect(body, isNot(contains('parseSvgPathData')));
    expect(body, isNot(contains('buildLocalPath')));
    expect(body, isNot(contains('_buildPathNode')));
  });

  test(
    '_drawSelectionForNode uses worldBounds-based selection for box nodes',
    () {
      final source = File(
        'lib/src/render/scene_painter.dart',
      ).readAsStringSync();
      final body = _extractMethodBody(
        source: source,
        methodStart: 'void _drawSelectionForNode(',
      );

      expect(body, contains('case ImageNodeSnapshot image:'));
      expect(body, contains('case TextNodeSnapshot text:'));
      expect(body, contains('case RectNodeSnapshot rect:'));
      expect(body, contains('_drawWorldBoundsSelection('));
      expect(body, isNot(contains('_drawBoxSelection(')));
    },
  );
}
