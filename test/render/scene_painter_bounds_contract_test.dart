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
  test('frame owner reads geometry from RenderGeometryCache once', () {
    final source = File(
      'lib/src/render/scene_painter_frame.part.dart',
    ).readAsStringSync();
    final body = _extractMethodBody(
      source: source,
      methodStart: '_ResolvedNodePaintData resolveNodePaintData(',
    );

    expect(body, contains('geometry: geometryCache.get(node),'));
    expect(body, isNot(contains('parseSvgPathData')));
    expect(body, isNot(contains('buildLocalPath')));
    expect(body, isNot(contains('_buildPathNode')));
  });

  test(
    'node renderer consumes frame-local localPath instead of querying cache',
    () {
      final source = File(
        'lib/src/render/scene_painter_node_renderer.part.dart',
      ).readAsStringSync();
      expect(source, contains('required Path? localPath'));
      final body = _extractMethodBody(
        source: source,
        methodStart: 'void _drawPathNode(',
      );

      expect(body, isNot(contains('_geometryCache.get(')));
    },
  );

  test('selection rendering uses resolved frame data for box selections', () {
    final source = File(
      'lib/src/render/scene_painter_selection.part.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('class _ScenePainterSelectionOwner')));
    final body = _extractMethodBody(
      source: source,
      methodStart: 'void _drawSelectionForNode(',
    );

    expect(body, contains('case ImageNodeSnapshot():'));
    expect(body, contains('case TextNodeSnapshot():'));
    expect(body, contains('case RectNodeSnapshot():'));
    expect(body, contains('_drawWorldBoundsSelection('));
    expect(body, isNot(contains('_drawBoxSelection(')));
    expect(body, isNot(contains('_nodePreviewOffset(')));
    expect(body, isNot(contains('geometryCache.get(')));
  });
}
