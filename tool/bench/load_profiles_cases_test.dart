import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_snapshot_materializer.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/core/node_geometry.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart' show sceneSizeMax;
import 'package:iwb_canvas_engine/src/contract/scene_view_render_state.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_scene_view_runtime.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart'
    as interactive;
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';

import 'load_profile_policy.dart';

const _resultPrefix = 'IWB_BENCH_RESULT ';

void main() {
  final profile = _resolveProfile();
  final policy = loadProfilePolicyFor(profile);

  for (final nodeCase in policy.nodeCases) {
    test(
      'load profile nodes=${nodeCase.nodeCount} profile=$profile',
      () {
        final metrics = _runNodeScaleCase(
          nodeCount: nodeCase.nodeCount,
          iterations: policy.nodeIterations,
        );
        _emitResult(
          profile: profile,
          name: nodeCase.name,
          metrics: metrics,
          contract: policy.contractForCase(nodeCase.name),
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }

  for (final strokeCase in policy.strokeCases) {
    test(
      'load profile strokes=${strokeCase.strokeCount} points=${strokeCase.pointsPerStroke} profile=$profile',
      () {
        final metrics = _runStrokeScaleCase(
          strokeCount: strokeCase.strokeCount,
          pointsPerStroke: strokeCase.pointsPerStroke,
          iterations: policy.strokeIterations,
        );
        _emitResult(
          profile: profile,
          name: strokeCase.name,
          metrics: metrics,
          contract: policy.contractForCase(strokeCase.name),
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }

  test(
    'load profile selection-path-painter-only profile=$profile',
    () {
      final metrics = _runSelectionPathPainterOnlyCase(
        pathNodeCount: policy.selectionPathNodeCount,
        pathSegments: policy.selectionPathSegments,
        iterations: policy.selectionPathIterations,
      );
      _emitResult(
        profile: profile,
        name: selectionPathPainterOnlyCaseName,
        metrics: metrics,
        contract: policy.contractForCase(selectionPathPainterOnlyCaseName),
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'load profile selection-path-candidate-staging profile=$profile',
    () {
      final metrics = _runSelectionPathCandidateStagingCase(
        pathNodeCount: policy.selectionPathNodeCount,
        pathSegments: policy.selectionPathSegments,
        iterations: policy.selectionPathIterations,
      );
      _emitResult(
        profile: profile,
        name: selectionPathCandidateStagingCaseName,
        metrics: metrics,
        contract: policy.contractForCase(selectionPathCandidateStagingCaseName),
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'load profile selection-path-end-to-end-paint profile=$profile',
    () {
      final metrics = _runSelectionPathEndToEndPaintCase(
        pathNodeCount: policy.selectionPathNodeCount,
        pathSegments: policy.selectionPathSegments,
        iterations: policy.selectionPathIterations,
      );
      _emitResult(
        profile: profile,
        name: selectionPathEndToEndPaintCaseName,
        metrics: metrics,
        contract: policy.contractForCase(selectionPathEndToEndPaintCaseName),
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'load profile text-layout-cache profile=$profile',
    () {
      final metrics = _runTextLayoutCacheCase(
        iterations: policy.selectionPathIterations,
      );
      _emitResult(
        profile: profile,
        name: textLayoutCacheCaseName,
        metrics: metrics,
        contract: policy.contractForCase(textLayoutCacheCaseName),
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'load profile stroke-path-cache profile=$profile',
    () {
      final metrics = _runStrokePathCacheCase(
        iterations: policy.selectionPathIterations,
      );
      _emitResult(
        profile: profile,
        name: strokePathCacheCaseName,
        metrics: metrics,
        contract: policy.contractForCase(strokePathCacheCaseName),
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'load profile static-background-cache profile=$profile',
    () {
      final metrics = _runStaticBackgroundCacheCase(
        backgroundNodeCount: policy.nodeCases.last.nodeCount,
        iterations: policy.nodeIterations,
      );
      _emitResult(
        profile: profile,
        name: staticBackgroundCacheCaseName,
        metrics: metrics,
        contract: policy.contractForCase(staticBackgroundCacheCaseName),
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'load profile background-layer-paint profile=$profile',
    () {
      final metrics = _runBackgroundLayerPaintAdmissionCase(
        backgroundNodeCount: policy.nodeCases.last.nodeCount,
        iterations: policy.nodeIterations,
      );
      _emitResult(
        profile: profile,
        name: backgroundLayerPaintAdmissionCaseName,
        metrics: metrics,
        contract: policy.contractForCase(backgroundLayerPaintAdmissionCaseName),
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'load profile worst-case profile=$profile',
    () {
      final metrics = _runWorstCaseProfile(
        largeQueryNodeCount: policy.largeQueryNodeCount,
        longPathSegments: policy.longPathSegments,
        iterations: policy.worstCaseIterations,
      );
      _emitResult(
        profile: profile,
        name: worstCaseName,
        metrics: metrics,
        contract: policy.contractForCase(worstCaseName),
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

String _resolveProfile() {
  final raw = Platform.environment['IWB_BENCH_PROFILE']?.trim().toLowerCase();
  if (raw == null || raw.isEmpty) {
    return 'smoke';
  }
  return loadProfilePolicyFor(raw).profile;
}

Map<String, Object?> _runNodeScaleCase({
  required int nodeCount,
  required int iterations,
}) {
  final snapshot = SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-0',
        nodes: <NodeSnapshot>[
          for (var i = 0; i < nodeCount; i++)
            RectNodeSnapshot(
              id: 'n$i',
              size: const Size(12, 12),
              transform: Transform2D.translation(
                Offset((i % 400) * 20.0, (i ~/ 400) * 20.0),
              ),
            ),
        ],
      ),
    ],
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  final targetId = 'n${nodeCount ~/ 2}';

  try {
    controller.queryHitTestCandidates(const Rect.fromLTWH(0, 0, 1, 1));

    final patchMetric = _measureOperation(
      iterations: iterations,
      run: (i) {
        final width = i.isEven ? 2.0 : 1.0;
        controller.write<void>((writer) {
          writer.writeNodePatch(
            RectNodePatch(
              id: targetId,
              strokeWidth: PatchField<double>.value(width),
            ),
          );
        });
      },
    );

    final transformMetric = _measureOperation(
      iterations: iterations,
      run: (i) {
        controller.write<void>((writer) {
          writer.writeNodeTransformSet(
            targetId,
            Transform2D.translation(Offset((i + 1).toDouble(), 0)),
          );
        });
        controller.queryHitTestCandidates(
          Rect.fromLTWH((i + 1).toDouble(), 0, 1, 1),
        );
      },
    );

    final toggleMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.write<void>((writer) {
          writer.writeSelectionToggle(targetId);
        });
      },
    );

    final moveMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.write<void>((writer) {
          writer.writeSelectionReplace(<NodeId>{targetId});
          writer.writeSelectionTranslate(const Offset(1, 0));
        });
      },
    );

    return <String, Object?>{
      'nodeCount': nodeCount,
      'iterations': iterations,
      'metrics': <String, Object?>{
        'single_node_patch': patchMetric,
        'single_node_transform': transformMetric,
        'toggle_selection': toggleMetric,
        'move_selection': moveMetric,
      },
    };
  } finally {
    controller.dispose();
  }
}

Map<String, Object?> _runStrokeScaleCase({
  required int strokeCount,
  required int pointsPerStroke,
  required int iterations,
}) {
  final nodes = <NodeSnapshot>[
    for (var i = 0; i < strokeCount; i++)
      StrokeNodeSnapshot(
        id: 's$i',
        points: _linearPoints(
          count: pointsPerStroke,
          y: (i % 200).toDouble() * 2,
        ),
        thickness: 2,
        color: const Color(0xFF000000),
      ),
  ];
  final snapshot = SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(id: 'layer-auto-1', nodes: nodes),
    ],
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  final targetId = 's${strokeCount ~/ 2}';
  final pointsA = _linearPoints(count: pointsPerStroke, y: 0);
  final pointsB = _linearPoints(count: pointsPerStroke, y: 5);

  try {
    controller.queryHitTestCandidates(const Rect.fromLTWH(0, 0, 1, 1));

    final thicknessMetric = _measureOperation(
      iterations: iterations,
      run: (i) {
        controller.write<void>((writer) {
          writer.writeNodePatch(
            StrokeNodePatch(
              id: targetId,
              thickness: PatchField<double>.value(i.isEven ? 3 : 2),
            ),
          );
        });
      },
    );

    final pointsMetric = _measureOperation(
      iterations: iterations,
      run: (i) {
        controller.write<void>((writer) {
          writer.writeNodePatch(
            StrokeNodePatch(
              id: targetId,
              points: PatchField<List<Offset>>.value(
                i.isEven ? pointsA : pointsB,
              ),
            ),
          );
        });
      },
    );

    final toggleMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.write<void>((writer) {
          writer.writeSelectionToggle(targetId);
        });
      },
    );

    return <String, Object?>{
      'strokeCount': strokeCount,
      'pointsPerStroke': pointsPerStroke,
      'iterations': iterations,
      'metrics': <String, Object?>{
        'single_stroke_patch_thickness': thicknessMetric,
        'single_stroke_patch_points': pointsMetric,
        'toggle_selection': toggleMetric,
      },
    };
  } finally {
    controller.dispose();
  }
}

Map<String, Object?> _runWorstCaseProfile({
  required int largeQueryNodeCount,
  required int longPathSegments,
  required int iterations,
}) {
  final hugeBoundsMetric = _runHugeBoundsMetric(iterations: iterations);
  final hugeRectSelectMetric = _runHugeRectSelectMetric(
    nodeCount: largeQueryNodeCount,
    iterations: iterations,
  );
  final longPathMetric = _runVeryLongPathMetric(
    segments: longPathSegments,
    iterations: iterations,
  );
  return <String, Object?>{
    'largeQueryNodeCount': largeQueryNodeCount,
    'longPathSegments': longPathSegments,
    'iterations': iterations,
    'metrics': <String, Object?>{
      'huge_bounds': hugeBoundsMetric,
      'huge_rect_select': hugeRectSelectMetric,
      'very_long_path': longPathMetric,
    },
  };
}

Map<String, Object?> _runSelectionPathPainterOnlyCase({
  required int pathNodeCount,
  required int pathSegments,
  required int iterations,
}) {
  final snapshot = _selectionPathSnapshot(
    pathNodeCount: pathNodeCount,
    pathSegments: pathSegments,
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  final renderState = _BenchmarkControllerRenderState(controller);
  final pathCache = ScenePathMetricsCache(maxEntries: pathNodeCount * 2);
  final painter = ScenePainter(
    controller: renderState,
    imageResolver: (_) => null,
    pathMetricsCache: pathCache,
  );
  final selectedIds = <NodeId>{
    for (var i = 0; i < pathNodeCount; i++) 'spm-$i',
  };
  const canvasSize = Size(2200, 1400);

  try {
    final noSelectionMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.write<void>((writer) {
          writer.writeSelectionClear();
        });
        _paintScene(painter, canvasSize);
      },
    );

    pathCache.clear();
    final withSelectionMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.write<void>((writer) {
          writer.writeSelectionReplace(selectedIds);
        });
        _paintScene(painter, canvasSize);
      },
    );

    return <String, Object?>{
      'pathNodeCount': pathNodeCount,
      'pathSegments': pathSegments,
      'iterations': iterations,
      'metrics': <String, Object?>{
        'paint_no_selection': noSelectionMetric,
        'paint_with_selection': withSelectionMetric,
      },
    };
  } finally {
    renderState.dispose();
    controller.dispose();
  }
}

Map<String, Object?> _runSelectionPathCandidateStagingCase({
  required int pathNodeCount,
  required int pathSegments,
  required int iterations,
}) {
  final snapshot = _selectionPathSnapshot(
    pathNodeCount: pathNodeCount,
    pathSegments: pathSegments,
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  final interactionController = interactive.SceneController();
  final renderState = _createProductionBenchmarkRenderState(
    controller: controller,
    interactionController: interactionController,
  );
  final selectedIds = <NodeId>{
    for (var i = 0; i < pathNodeCount; i++) 'spm-$i',
  };
  const query = ScenePaintCandidateQuery(
    viewportRect: Rect.fromLTWH(0, 0, 2200, 1400),
    visibilityRect: Rect.fromLTWH(-1, -1, 2202, 1402),
  );

  try {
    final noSelectionMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.write<void>((writer) {
          writer.writeSelectionClear();
        });
        renderState.preparePaintPlan(renderState.captureFrameRead(), query);
      },
    );

    final withSelectionMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.write<void>((writer) {
          writer.writeSelectionReplace(selectedIds);
        });
        renderState.preparePaintPlan(renderState.captureFrameRead(), query);
      },
    );

    return <String, Object?>{
      'pathNodeCount': pathNodeCount,
      'pathSegments': pathSegments,
      'iterations': iterations,
      'metrics': <String, Object?>{
        'stage_no_selection': noSelectionMetric,
        'stage_with_selection': withSelectionMetric,
      },
    };
  } finally {
    renderState.dispose();
    interactionController.dispose();
    controller.dispose();
  }
}

Map<String, Object?> _runSelectionPathEndToEndPaintCase({
  required int pathNodeCount,
  required int pathSegments,
  required int iterations,
}) {
  final snapshot = _selectionPathSnapshot(
    pathNodeCount: pathNodeCount,
    pathSegments: pathSegments,
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  final interactionController = interactive.SceneController();
  final renderState = _createProductionBenchmarkRenderState(
    controller: controller,
    interactionController: interactionController,
  );
  final pathCache = ScenePathMetricsCache(maxEntries: pathNodeCount * 2);
  final painter = ScenePainter(
    controller: renderState,
    imageResolver: (_) => null,
    pathMetricsCache: pathCache,
  );
  final selectedIds = <NodeId>{
    for (var i = 0; i < pathNodeCount; i++) 'spm-$i',
  };
  const canvasSize = Size(2200, 1400);

  try {
    final noSelectionMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.write<void>((writer) {
          writer.writeSelectionClear();
        });
        _paintScene(painter, canvasSize);
      },
    );

    pathCache.clear();
    final withSelectionMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.write<void>((writer) {
          writer.writeSelectionReplace(selectedIds);
        });
        _paintScene(painter, canvasSize);
      },
    );

    return <String, Object?>{
      'pathNodeCount': pathNodeCount,
      'pathSegments': pathSegments,
      'iterations': iterations,
      'metrics': <String, Object?>{
        'paint_no_selection': noSelectionMetric,
        'paint_with_selection': withSelectionMetric,
      },
    };
  } finally {
    renderState.dispose();
    interactionController.dispose();
    controller.dispose();
  }
}

Map<String, Object?> _runTextLayoutCacheCase({required int iterations}) {
  final snapshot = SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-text-cache',
        nodes: <NodeSnapshot>[
          TextNodeSnapshot(
            id: 'text-cache',
            text: 'layout cache benchmark',
            fontSize: 14,
            color: const Color(0xFF000000),
            textDirection: TextDirection.ltr,
            transform: Transform2D.translation(const Offset(24, 24)),
          ),
        ],
      ),
    ],
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  final interactionController = interactive.SceneController();
  final renderState = _createProductionBenchmarkRenderState(
    controller: controller,
    interactionController: interactionController,
  );
  const canvasSize = Size(320, 160);

  try {
    final missMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        final textCache = SceneTextLayoutCache(maxEntries: 8);
        final painter = ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          textLayoutCache: textCache,
        );
        _paintScene(painter, canvasSize);
      },
    );

    final textCache = SceneTextLayoutCache(maxEntries: 8);
    final painter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      textLayoutCache: textCache,
    );
    final hitMetric = _measureOperation(
      iterations: iterations,
      warmUp: () {
        _paintScene(painter, canvasSize);
      },
      run: (_) {
        _paintScene(painter, canvasSize);
      },
    );

    return <String, Object?>{
      'iterations': iterations,
      'metrics': <String, Object?>{
        'paint_cache_miss': missMetric,
        'paint_cache_hit': hitMetric,
      },
    };
  } finally {
    renderState.dispose();
    interactionController.dispose();
    controller.dispose();
  }
}

Map<String, Object?> _runStrokePathCacheCase({required int iterations}) {
  final snapshot = SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-stroke-cache',
        nodes: <NodeSnapshot>[
          StrokeNodeSnapshot(
            id: 'stroke-cache',
            points: _linearPoints(count: 256, y: 40),
            thickness: 4,
            color: const Color(0xFF000000),
          ),
        ],
      ),
    ],
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  final interactionController = interactive.SceneController();
  final renderState = _createProductionBenchmarkRenderState(
    controller: controller,
    interactionController: interactionController,
  );
  const canvasSize = Size(320, 160);

  try {
    final missMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        final strokeCache = SceneStrokePathCache(maxEntries: 8);
        final painter = ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          strokePathCache: strokeCache,
        );
        _paintScene(painter, canvasSize);
      },
    );

    final strokeCache = SceneStrokePathCache(maxEntries: 8);
    final painter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      strokePathCache: strokeCache,
    );
    final hitMetric = _measureOperation(
      iterations: iterations,
      warmUp: () {
        _paintScene(painter, canvasSize);
      },
      run: (_) {
        _paintScene(painter, canvasSize);
      },
    );

    return <String, Object?>{
      'iterations': iterations,
      'metrics': <String, Object?>{
        'paint_cache_miss': missMetric,
        'paint_cache_hit': hitMetric,
      },
    };
  } finally {
    renderState.dispose();
    interactionController.dispose();
    controller.dispose();
  }
}

Map<String, Object?> _runStaticBackgroundCacheCase({
  required int backgroundNodeCount,
  required int iterations,
}) {
  final snapshot = SceneSnapshot(
    backgroundLayer: BackgroundLayerSnapshot(
      nodes: <NodeSnapshot>[
        for (var i = 0; i < backgroundNodeCount; i++)
          RectNodeSnapshot(
            id: 'sbg$i',
            size: const Size(8, 8),
            transform: Transform2D.translation(
              Offset((i % 500) * 32.0, (i ~/ 500) * 32.0),
            ),
          ),
      ],
    ),
    background: BackgroundSnapshot(
      color: const Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 24,
        color: const Color(0xFFDDDDDD),
      ),
    ),
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  final interactionController = interactive.SceneController();
  SceneSnapshot readSnapshot() => controller.snapshot;
  final renderState = SceneControllerSceneViewRenderState(
    storeController: controller,
    readSnapshot: readSnapshot,
    readSelectedNodeIds: () => controller.selectedNodeIds,
    readControllerEpoch: () => controller.controllerEpoch,
    captureFramePreview: () => SceneViewFramePreview.captureSnapshot(
      snapshot: readSnapshot(),
      deltaForNode: _benchmarkZeroPreviewDelta,
    ),
    readInteraction: () => interactionController.interaction,
  );
  const canvasSize = Size(320, 180);

  try {
    final missMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        final staticCache = SceneStaticLayerCache();
        final painter = ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          staticLayerCache: staticCache,
        );
        _paintScene(painter, canvasSize);
      },
    );

    final staticCache = SceneStaticLayerCache();
    final painter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      staticLayerCache: staticCache,
    );
    final hitMetric = _measureOperation(
      iterations: iterations,
      warmUp: () {
        _paintScene(painter, canvasSize);
      },
      run: (_) {
        _paintScene(painter, canvasSize);
      },
    );

    return <String, Object?>{
      'backgroundNodeCount': backgroundNodeCount,
      'iterations': iterations,
      'metrics': <String, Object?>{
        'paint_cache_miss': missMetric,
        'paint_cache_hit': hitMetric,
      },
    };
  } finally {
    renderState.dispose();
    interactionController.dispose();
    controller.dispose();
  }
}

Map<String, Object?> _runBackgroundLayerPaintAdmissionCase({
  required int backgroundNodeCount,
  required int iterations,
}) {
  final snapshot = SceneSnapshot(
    backgroundLayer: BackgroundLayerSnapshot(
      nodes: <NodeSnapshot>[
        for (var i = 0; i < backgroundNodeCount; i++)
          RectNodeSnapshot(
            id: 'bg$i',
            size: const Size(8, 8),
            transform: Transform2D.translation(
              Offset((i % 500) * 32.0, (i ~/ 500) * 32.0),
            ),
          ),
      ],
    ),
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  final interactionController = interactive.SceneController();
  SceneSnapshot readSnapshot() => controller.snapshot;
  final renderState = SceneControllerSceneViewRenderState(
    storeController: controller,
    readSnapshot: readSnapshot,
    readSelectedNodeIds: () => controller.selectedNodeIds,
    readControllerEpoch: () => controller.controllerEpoch,
    captureFramePreview: () => SceneViewFramePreview.captureSnapshot(
      snapshot: readSnapshot(),
      deltaForNode: _benchmarkZeroPreviewDelta,
    ),
    readInteraction: () => interactionController.interaction,
  );
  final painter = ScenePainter(
    controller: renderState,
    imageResolver: (_) => null,
  );
  const query = ScenePaintCandidateQuery(
    viewportRect: Rect.fromLTWH(0, 0, 240, 160),
    visibilityRect: Rect.fromLTWH(-1, -1, 242, 162),
  );
  const canvasSize = Size(240, 160);

  try {
    final enumerateMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        renderState
            .preparePaintPlan(renderState.captureFrameRead(), query)
            .candidateCount;
      },
    );

    final paintMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        _paintScene(painter, canvasSize);
      },
    );

    return <String, Object?>{
      'backgroundNodeCount': backgroundNodeCount,
      'iterations': iterations,
      'metrics': <String, Object?>{
        'enumerate_small_viewport': enumerateMetric,
        'paint_small_viewport': paintMetric,
      },
    };
  } finally {
    renderState.dispose();
    interactionController.dispose();
    controller.dispose();
  }
}

SceneSnapshot _selectionPathSnapshot({
  required int pathNodeCount,
  required int pathSegments,
}) {
  final pathData = _horizontalPath(segments: pathSegments);
  return SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-selection-path',
        nodes: <NodeSnapshot>[
          for (var i = 0; i < pathNodeCount; i++)
            PathNodeSnapshot(
              id: 'spm-$i',
              svgPathData: pathData,
              strokeColor: const Color(0xFF000000),
              strokeWidth: 2,
              transform: Transform2D.translation(
                Offset((i % 50) * 40.0 + 20.0, (i ~/ 50) * 30.0 + 20.0),
              ),
            ),
        ],
      ),
    ],
  );
}

SceneControllerSceneViewRenderState _createProductionBenchmarkRenderState({
  required SceneStoreController controller,
  required interactive.SceneController interactionController,
}) {
  SceneSnapshot readSnapshot() => controller.snapshot;
  return SceneControllerSceneViewRenderState(
    storeController: controller,
    readSnapshot: readSnapshot,
    readSelectedNodeIds: () => controller.selectedNodeIds,
    readControllerEpoch: () => controller.controllerEpoch,
    captureFramePreview: () => SceneViewFramePreview.captureSnapshot(
      snapshot: readSnapshot(),
      deltaForNode: _benchmarkZeroPreviewDelta,
    ),
    readInteraction: () => interactionController.interaction,
  );
}

class _BenchmarkControllerRenderState extends ChangeNotifier
    implements SceneViewRenderState {
  _BenchmarkControllerRenderState(this._controller) {
    _controller.addListener(notifyListeners);
  }

  final SceneStoreController _controller;

  @override
  SceneSnapshot get snapshot => _controller.snapshot;

  @override
  Set<NodeId> get selectedNodeIds => _controller.selectedNodeIds;

  @override
  int get controllerEpoch => _controller.controllerEpoch;

  @override
  Listenable get overlayRepaintListenable => this;

  @override
  Rect? get selectionRect => null;

  @override
  Offset get cameraOffset => snapshot.camera.offset;

  @override
  SceneViewFrameRead captureFrameRead() {
    return SceneViewFrameRead(
      snapshot: snapshot,
      selectedNodeIds: selectedNodeIds,
      selectionRevision: 0,
      preview: SceneViewFramePreview.captureSnapshot(
        snapshot: snapshot,
        deltaForNode: _benchmarkZeroPreviewDelta,
      ),
    );
  }

  @override
  ScenePreparedPaintPlan preparePaintPlan(
    SceneViewFrameRead frameRead,
    ScenePaintCandidateQuery query,
  ) {
    return ScenePreparedPaintCandidateList(
      _benchmarkPaintCandidates(frameRead, query),
    );
  }

  @override
  bool get hasActiveStrokePreview => false;

  @override
  List<Offset> get activeStrokePreviewPoints => const <Offset>[];

  @override
  double get activeStrokePreviewThickness => 0;

  @override
  Color get activeStrokePreviewColor => const Color(0x00000000);

  @override
  double get activeStrokePreviewOpacity => 0;

  @override
  bool get hasActiveLinePreview => false;

  @override
  Offset? get activeLinePreviewStart => null;

  @override
  Offset? get activeLinePreviewEnd => null;

  @override
  double get activeLinePreviewThickness => 0;

  @override
  Color get activeLinePreviewColor => const Color(0x00000000);

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    super.dispose();
  }
}

Offset _benchmarkZeroPreviewDelta(NodeId _) => Offset.zero;

Iterable<ScenePaintCandidate> _benchmarkPaintCandidates(
  SceneViewFrameRead frameRead,
  ScenePaintCandidateQuery query,
) sync* {
  for (final node in frameRead.snapshot.backgroundLayer.nodes) {
    final candidateRect = frameRead.selectedNodeIds.contains(node.id)
        ? query.visibilityRect
        : query.viewportRect;
    if (_benchmarkCandidateOverlaps(node, candidateRect)) {
      yield ScenePaintCandidate(
        node: node,
        paintBoundsWorld: nodeSnapshotBoundsWorld(node),
      );
    }
  }
  for (final layer in frameRead.snapshot.layers) {
    for (final node in layer.nodes) {
      final candidateRect = frameRead.selectedNodeIds.contains(node.id)
          ? query.visibilityRect
          : query.viewportRect;
      if (_benchmarkCandidateOverlaps(node, candidateRect)) {
        yield ScenePaintCandidate(
          node: node,
          paintBoundsWorld: nodeSnapshotBoundsWorld(node),
        );
      }
    }
  }
}

bool _benchmarkCandidateOverlaps(NodeSnapshot node, Rect worldRect) {
  return worldRect.overlaps(boundsWorldForNodeSnapshot(node));
}

Map<String, Object?> _runHugeBoundsMetric({required int iterations}) {
  final snapshot = SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-2',
        nodes: <NodeSnapshot>[
          RectNodeSnapshot(id: 'huge', size: Size(sceneSizeMax, sceneSizeMax)),
        ],
      ),
    ],
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  try {
    final queryMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.queryHitTestCandidates(const Rect.fromLTWH(0, 0, 10, 10));
      },
    );

    final moveMetric = _measureOperation(
      iterations: iterations,
      run: (i) {
        controller.write<void>((writer) {
          writer.writeSelectionReplace(const <NodeId>{'huge'});
          writer.writeSelectionTranslate(
            Offset(1000000 * (i + 1).toDouble(), 0),
          );
        });
        controller.queryHitTestCandidates(
          Rect.fromLTWH(1000000 * (i + 1).toDouble(), 0, 10, 10),
        );
      },
    );

    return <String, Object?>{
      'query': queryMetric,
      'move_selection': moveMetric,
    };
  } finally {
    controller.dispose();
  }
}

Map<String, Object?> _runHugeRectSelectMetric({
  required int nodeCount,
  required int iterations,
}) {
  final snapshot = SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-3',
        nodes: <NodeSnapshot>[
          for (var i = 0; i < nodeCount; i++)
            RectNodeSnapshot(
              id: 'q$i',
              size: const Size(8, 8),
              transform: Transform2D.translation(
                Offset((i % 500) * 16.0, (i ~/ 500) * 16.0),
              ),
            ),
        ],
      ),
    ],
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  try {
    return _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.queryHitTestCandidates(
          const Rect.fromLTWH(-128000, -12800, 256000, 25600),
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

Map<String, Object?> _runVeryLongPathMetric({
  required int segments,
  required int iterations,
}) {
  final pathA = _horizontalPath(segments: segments);
  final pathB = _horizontalPath(segments: segments + 100);
  final snapshot = SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-4',
        nodes: <NodeSnapshot>[
          PathNodeSnapshot(
            id: 'path',
            svgPathData: pathA,
            strokeColor: const Color(0xFF000000),
            strokeWidth: 1,
          ),
        ],
      ),
    ],
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  try {
    final patchMetric = _measureOperation(
      iterations: iterations,
      run: (i) {
        controller.write<void>((writer) {
          writer.writeNodePatch(
            PathNodePatch(
              id: 'path',
              svgPathData: PatchField<String>.value(i.isEven ? pathA : pathB),
            ),
          );
        });
      },
    );

    final queryMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        controller.queryHitTestCandidates(
          const Rect.fromLTWH(0, 0, 100000, 100),
        );
      },
    );

    return <String, Object?>{
      'patch_svg_path': patchMetric,
      'query_candidates': queryMetric,
    };
  } finally {
    controller.dispose();
  }
}

Map<String, Object?> _measureOperation({
  required int iterations,
  void Function()? warmUp,
  required void Function(int iteration) run,
}) {
  warmUp?.call();
  final latencySamplesUs = <int>[];
  final rssDeltaSamplesBytes = <int>[];
  for (var i = 0; i < iterations; i++) {
    final baselineRssBytes = ProcessInfo.currentRss;
    final sw = Stopwatch()..start();
    run(i);
    sw.stop();
    final currentRssBytes = ProcessInfo.currentRss;
    latencySamplesUs.add(sw.elapsedMicroseconds);
    rssDeltaSamplesBytes.add(
      currentRssBytes > baselineRssBytes
          ? currentRssBytes - baselineRssBytes
          : 0,
    );
  }
  latencySamplesUs.sort();
  rssDeltaSamplesBytes.sort();
  final totalLatencyUs = latencySamplesUs.fold<int>(
    0,
    (sum, value) => sum + value,
  );
  final totalRssDeltaBytes = rssDeltaSamplesBytes.fold<int>(
    0,
    (sum, value) => sum + value,
  );
  final metrics = <String, Object?>{
    'avgUs': (totalLatencyUs / latencySamplesUs.length).round(),
    'minUs': latencySamplesUs.first,
    'maxUs': latencySamplesUs.last,
    'avgRssDeltaBytes': (totalRssDeltaBytes / rssDeltaSamplesBytes.length)
        .round(),
    'minRssDeltaBytes': rssDeltaSamplesBytes.first,
    'maxRssDeltaBytes': rssDeltaSamplesBytes.last,
  };
  return metrics;
}

List<Offset> _linearPoints({required int count, required double y}) {
  return <Offset>[for (var i = 0; i < count; i++) Offset(i.toDouble(), y)];
}

String _horizontalPath({required int segments}) {
  final buf = StringBuffer('M0 0');
  for (var i = 1; i <= segments; i++) {
    buf.write(' L${i.toDouble()} 0');
  }
  return buf.toString();
}

void _paintScene(ScenePainter painter, Size size) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  picture.dispose();
}

void _emitResult({
  required String profile,
  required String name,
  required Map<String, Object?> metrics,
  required Map<String, Object?> contract,
}) {
  final record = <String, Object?>{
    'name': name,
    'profile': profile,
    'contract': contract,
    'metrics': metrics,
  };
  final line = '$_resultPrefix${jsonEncode(record)}';
  // ignore: avoid_print, benchmark helper emits machine-readable JSON lines
  print(line);
}
