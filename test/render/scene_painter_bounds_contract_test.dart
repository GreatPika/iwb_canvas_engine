import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// INV:INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY
// INV:INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION
// INV:INV-ENG-SELECTION-BOUNDED-COMPOSITING
// INV:INV-ENG-PERFORMANCE-PROOF-CONTOUR
// INV:INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE

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
    'frame owner resolves viewport-first paint candidates, per-node visibility rects, and shared text layout before geometry lookup',
    () {
      final source = File(
        'lib/src/render/scene_painter_frame.dart',
      ).readAsStringSync();
      final createBody = _extractMethodBody(
        source: source,
        methodStart:
            'ScenePainterPaintFrame create(Size size, SceneViewFrameRead frameRead)',
      );
      final createPreparedBody = _extractMethodBody(
        source: source,
        methodStart: 'ScenePainterPreparedFrame createPrepared(',
      );
      final body = _extractMethodBody(
        source: source,
        methodStart: 'ScenePainterResolvedNodePaintData resolveNodePaintData(',
      );

      expect(source, contains('class ScenePainterVisibilityBudget'));
      expect(
        createBody,
        contains('return ScenePainterPaintFrame.fromPrepared('),
      );
      expect(createBody, contains('createPrepared(size, frameRead));'));
      expect(
        createPreparedBody,
        contains('final visibilityBudget = ScenePainterVisibilityBudget('),
      );
      expect(
        createPreparedBody,
        contains('hasSelectedNodes: frameRead.selectedNodeIds.isNotEmpty,'),
      );
      expect(
        createPreparedBody,
        contains('final rawViewRect = Rect.fromLTWH('),
      );
      expect(
        createPreparedBody,
        contains('final viewRect = visibilityBudget.applyTo(rawViewRect);'),
      );
      expect(
        createPreparedBody,
        contains('paintPlan: renderState.preparePaintPlan('),
      );
      expect(createPreparedBody, contains('frameRead,'));
      expect(
        createPreparedBody,
        contains('paintPlan: renderState.preparePaintPlan('),
      );
      expect(createPreparedBody, contains('viewportRect: rawViewRect,'));
      expect(createPreparedBody, contains('visibilityRect: viewRect,'));
      expect(
        createPreparedBody,
        contains('selectedIds: frameRead.selectedNodeIds,'),
      );
      expect(
        createPreparedBody,
        isNot(contains('List<ScenePaintCandidate>.unmodifiable(')),
      );
      expect(
        createPreparedBody,
        contains('paintPlan: renderState.preparePaintPlan('),
      );
      expect(source, isNot(contains('scenePainterCullPadding')));
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

  test('scene painter captures one atomic frame read before shell paint', () {
    final source = File('lib/src/render/scene_painter.dart').readAsStringSync();

    expect(
      source,
      contains('_shell.paint(canvas, size, controller.captureFrameRead());'),
    );
    expect(source, contains('ScenePainterPreparedScene prepareForPaint('));
    expect(source, contains('frame: _shell.prepareFrame(size, frameRead),'));
    expect(source, contains('_shell.paintPrepared('));
  });

  test(
    'node renderer consumes ordered frame paint candidates instead of snapshot scans',
    () {
      final source = File(
        'lib/src/render/scene_painter_node_renderer.dart',
      ).readAsStringSync();
      final body = _extractMethodBody(
        source: source,
        methodStart: 'void _drawVisibleNodes(',
      );

      expect(source, contains('class ScenePainterNodeRenderer'));
      expect(source, contains('frame.paintPlan.candidateCount'));
      expect(source, contains('frame.paintPlan.candidateAt(index)'));
      expect(
        body,
        contains('final nodeViewRect = frame.visibilityRectForNode('),
      );
      expect(
        body,
        contains('candidate.paintBoundsWorld.overlaps(nodeViewRect)'),
      );
      expect(
        body,
        contains('final resolvedNode = resolveNodePaintData(node);'),
      );
      expect(
        body,
        contains('_canPaintNodeInFrame(resolvedNode, nodeViewRect)'),
      );
      expect(
        source,
        isNot(contains('_canPaintNodeInFrame(resolvedNode, frame.viewRect)')),
      );
      expect(source, isNot(contains('snapshot.backgroundLayer.nodes')));
      expect(source, isNot(contains('for (final layer in snapshot.layers)')));
      expect(source, contains('Path? localPath'));
      expect(source, isNot(contains('SceneTextLayoutCache')));
      expect(source, isNot(contains('buildSceneTextPainter(')));
      final pathBody = _extractMethodBody(
        source: source,
        methodStart: 'void _drawPathNode(',
      );

      expect(pathBody, isNot(contains('_geometryCache.get(')));
    },
  );

  test('committed paint enumeration uses scoped shared spatial query', () {
    final runtimeSource = File(
      'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
    ).readAsStringSync();
    final stageSource = File(
      'lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart',
    ).readAsStringSync();
    final runtimeBody = _extractMethodBody(
      source: runtimeSource,
      methodStart: 'ScenePreparedPaintPlan preparePaintPlan(',
    );
    expect(
      runtimeBody,
      contains('return _paintCandidateStage.prepareCommittedPaintPlan('),
    );
    expect(runtimeBody, isNot(contains('queryPaintCandidates(')));

    final stageBody = _extractMethodBody(
      source: stageSource,
      methodStart: 'ScenePreparedPaintPlan prepareCommittedPaintPlan({',
    );
    final ordinaryBody = _extractMethodBody(
      source: stageSource,
      methodStart: 'void _stageOrdinaryCandidates({',
    );
    final supplementBody = _extractMethodBody(
      source: stageSource,
      methodStart: 'void _stageSelectedSupplements({',
    );

    expect(stageBody, contains('_stageOrdinaryCandidates('));
    expect(stageBody, contains('_stageSelectedSupplements('));
    expect(
      supplementBody,
      contains('_selectedOrderCache.orderedSelectedTokens('),
    );
    expect(supplementBody, contains('selectionRevision: selectionRevision,'));
    expect(supplementBody, contains('structuralRevision: structuralRevision,'));
    expect(supplementBody, contains('for (final token in selectedTokens)'));
    expect(
      supplementBody,
      isNot(contains('for (final nodeId in selectedNodeIds)')),
    );
    expect(supplementBody, isNot(contains('.sort(')));
    expect(
      ordinaryBody,
      contains(
        'scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,',
      ),
    );
    expect(ordinaryBody, contains('_store.resolveSpatialCandidateSnapshot(('));
    expect(
      ordinaryBody,
      contains('paintBoundsWorld: candidate.paintBoundsWorld,'),
    );
    expect(stageSource, isNot(contains('snapshot.backgroundLayer.nodes')));
    expect(
      stageSource,
      isNot(contains('resolveSnapshotNodeById(candidate.nodeId)')),
    );
    expect(ordinaryBody, isNot(contains('_snapshotPaintBoundsWorld(')));
    expect(ordinaryBody, isNot(contains('nodeSnapshotPaintBoundsWorld(')));
    expect(ordinaryBody, isNot(contains('nodePaintBoundsWorld(')));
    expect(stageBody, isNot(contains('.sort(')));
  });

  test(
    'paint admission modules use explicit bounds sources instead of heavy snapshot geometry',
    () {
      final stageSource = File(
        'lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart',
      ).readAsStringSync();
      final snapshotEnumeratorSource = File(
        'lib/src/core/scene_snapshot_paint_candidates.dart',
      ).readAsStringSync();
      final supplementBody = _extractMethodBody(
        source: stageSource,
        methodStart: 'void _stageSelectedSupplements({',
      );

      expect(stageSource, contains('queryPaintCandidates('));
      expect(supplementBody, contains('queryPaintCandidates('));
      expect(supplementBody, contains('spatialCandidate.paintBoundsWorld'));

      expect(
        snapshotEnumeratorSource,
        contains('SnapshotPaintAdmissionBoundsSource'),
      );
      expect(snapshotEnumeratorSource, contains('.resolveBasePaintBounds('));

      for (final MapEntry(:key, :value) in <String, String>{
        'selected supplement stage': stageSource,
        'snapshot candidate enumerator': snapshotEnumeratorSource,
      }.entries) {
        expect(value, isNot(contains('nodeSnapshotPaintBoundsWorld(')));
        expect(value, isNot(contains('TextLayoutRequest')));
        expect(value, isNot(contains('.measure()')));
        expect(value, isNot(contains('buildCenteredSvgPathGeometry(')));
        expect(
          value,
          isNot(contains('_snapshotPaintBoundsWorld(')),
          reason: key,
        );
      }
    },
  );

  test(
    'frame preview contract stays frozen across capture, admission, and late node resolution',
    () {
      final contractSource = File(
        'lib/src/contract/scene_view_render_state.dart',
      ).readAsStringSync();
      final runtimeSource = File(
        'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
      ).readAsStringSync();
      final frameSource = File(
        'lib/src/render/scene_painter_frame.dart',
      ).readAsStringSync();

      expect(contractSource, contains('final class SceneViewFramePreview'));
      expect(contractSource, contains('required this.preview,'));
      expect(
        contractSource,
        isNot(
          contains(
            'final Offset Function(NodeId nodeId) previewDeltaResolver;',
          ),
        ),
      );
      expect(
        contractSource,
        isNot(
          contains('Offset Function(NodeId nodeId) get previewDeltaResolver;'),
        ),
      );

      expect(
        runtimeSource,
        contains(
          'required InteractiveMovePreviewRead Function() readMovePreview,',
        ),
      );
      expect(
        runtimeSource,
        contains('preview: _readMovePreview().captureFramePreview(),'),
      );
      expect(runtimeSource, contains('preview: frameRead.preview,'));
      expect(runtimeSource, isNot(contains('readPreviewDeltaResolver')));

      expect(frameSource, contains('frameRead.preview.deltaForNode(nodeId)'));
      expect(frameSource, isNot(contains('frameRead.previewDeltaResolver(')));
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

  test(
    'selection rendering keeps bounded compositing on selection owner seam',
    () {
      final source = File(
        'lib/src/render/scene_painter_selection.dart',
      ).readAsStringSync();

      expect(source, contains("import 'selection_halo_compositing.dart';"));
      expect(source, contains('drawBoundedRectHalo('));
      expect(source, contains('drawBoundedPathHalo('));
      expect(source, isNot(contains('canvas.saveLayer(null, Paint());')));
      expect(source, isNot(contains('benchmark-only')));
    },
  );
}
