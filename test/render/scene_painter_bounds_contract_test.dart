import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// INV:INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY

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
  test('scene painter modules no longer use part coupling', () {
    final painterModules = Directory('lib/src/render')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('scene_painter'))
        .where((file) => file.path.endsWith('.dart'));

    final partDirective = RegExp(
      "^part 'scene_painter_|^part of 'scene_painter",
      multiLine: true,
    );

    for (final module in painterModules) {
      final source = module.readAsStringSync();
      expect(partDirective.hasMatch(source), isFalse, reason: module.path);
    }
  });

  test('scene painter shell stays orchestration-only', () {
    final shellSource = File(
      'lib/src/render/scene_painter_shell.dart',
    ).readAsStringSync();
    final backgroundSource = File(
      'lib/src/render/scene_painter_background.dart',
    ).readAsStringSync();

    expect(shellSource, contains('class ScenePainterShell'));
    expect(shellSource, contains('backgroundOwner.paint('));
    expect(shellSource, isNot(contains('cache/scene_')));
    expect(shellSource, isNot(contains('render_geometry_cache.dart')));
    expect(shellSource, isNot(contains('scene_grid_renderer.dart')));
    expect(shellSource, isNot(contains('ScenePainterFrameOwner(')));
    expect(shellSource, isNot(contains('ScenePainterNodeRenderer(')));
    expect(shellSource, isNot(contains('ScenePainterSelectionRenderer(')));
    expect(backgroundSource, contains('class ScenePainterBackgroundOwner'));
  });

  test(
    'frame owner resolves ordered paint candidates and shared text layout before geometry lookup',
    () {
      final source = File(
        'lib/src/render/scene_painter_frame.dart',
      ).readAsStringSync();
      final createBody = _extractMethodBody(
        source: source,
        methodStart: 'ScenePainterPaintFrame create(Size size)',
      );
      final body = _extractMethodBody(
        source: source,
        methodStart: 'ScenePainterResolvedNodePaintData resolveNodePaintData(',
      );

      expect(
        createBody,
        contains('renderState.enumeratePaintCandidates(viewRect)'),
      );
      expect(
        createBody,
        contains('paintCandidates: List<NodeSnapshot>.unmodifiable('),
      );
      expect(body, contains('final textLayout = switch (node) {'));
      expect(
        body,
        contains('geometryCache.get(node, resolvedTextLayout: textLayout)'),
      );
      expect(body, contains('textLayout: textLayout,'));
      expect(body, isNot(contains('parseSvgPathData')));
      expect(body, isNot(contains('buildLocalPath')));
      expect(body, isNot(contains('_buildPathNode')));
    },
  );

  test(
    'node renderer consumes ordered frame paint candidates instead of snapshot scans',
    () {
      final source = File(
        'lib/src/render/scene_painter_node_renderer.dart',
      ).readAsStringSync();
      expect(source, contains('class ScenePainterNodeRenderer'));
      expect(source, contains('nodes: frame.paintCandidates,'));
      expect(source, isNot(contains('snapshot.backgroundLayer.nodes')));
      expect(source, isNot(contains('for (final layer in snapshot.layers)')));
      expect(source, contains('Path? localPath'));
      expect(source, isNot(contains('SceneTextLayoutCache')));
      expect(source, isNot(contains('buildSceneTextPainter(')));
      final body = _extractMethodBody(
        source: source,
        methodStart: 'void _drawPathNode(',
      );

      expect(body, isNot(contains('_geometryCache.get(')));
    },
  );

  test('selection rendering uses resolved frame data for box selections', () {
    final source = File(
      'lib/src/render/scene_painter_selection.dart',
    ).readAsStringSync();
    expect(source, contains('class ScenePainterSelectionRenderer'));
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
