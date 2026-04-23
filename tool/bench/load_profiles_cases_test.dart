import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_render_state.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart' show sceneSizeMax;
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_scene_view_runtime.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';
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
    'load profile stable-visible-working-set-paint profile=$profile',
    () {
      final metrics = _runStableVisibleWorkingSetPaintCase(
        iterations: policy.selectionPathIterations,
      );
      _emitResult(
        profile: profile,
        name: stableVisibleWorkingSetPaintCaseName,
        metrics: metrics,
        contract: policy.contractForCase(stableVisibleWorkingSetPaintCaseName),
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
        viewport: policy.backgroundViewport,
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

  if (policy.includesWorstCaseDiagnostics) {
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
}

typedef _BenchmarkPaintCaches = ({
  RenderGeometryCache geometryCache,
  SceneTextLayoutCache textLayoutCache,
  SceneStrokePathCache strokePathCache,
  ScenePathMetricsCache pathMetricsCache,
});

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
  final renderState = _createProductionBenchmarkRenderState(
    controller: controller,
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
    controller.write<void>((writer) {
      writer.writeSelectionClear();
    });
    final noSelectionPrepared = painter.prepareForPaint(canvasSize);
    final noSelectionMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        _paintPreparedScene(painter, noSelectionPrepared);
      },
    );

    pathCache.clear();
    controller.write<void>((writer) {
      writer.writeSelectionReplace(selectedIds);
    });
    final withSelectionPrepared = painter.prepareForPaint(canvasSize);
    final withSelectionMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        _paintPreparedScene(painter, withSelectionPrepared);
      },
    );

    controller.write<void>((writer) {
      writer.writeSelectionClear();
    });
    final noSelectionProbe = _captureSelectionSaveLayerProbe(
      painter: painter,
      preparedScene: painter.prepareForPaint(canvasSize),
    );

    controller.write<void>((writer) {
      writer.writeSelectionReplace(selectedIds);
    });
    final withSelectionProbe = _captureSelectionSaveLayerProbe(
      painter: painter,
      preparedScene: painter.prepareForPaint(canvasSize),
    );

    return <String, Object?>{
      'pathNodeCount': pathNodeCount,
      'pathSegments': pathSegments,
      'iterations': iterations,
      'probes': <String, Object?>{
        'paint_no_selection': noSelectionProbe,
        'paint_with_selection': withSelectionProbe,
      },
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
  final renderState = _createProductionBenchmarkRenderState(
    controller: controller,
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
  final renderState = _createProductionBenchmarkRenderState(
    controller: controller,
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

    controller.write<void>((writer) {
      writer.writeSelectionClear();
    });
    final noSelectionProbe = _captureSelectionSaveLayerProbe(
      painter: painter,
      preparedScene: painter.prepareForPaint(canvasSize),
    );

    controller.write<void>((writer) {
      writer.writeSelectionReplace(selectedIds);
    });
    final withSelectionProbe = _captureSelectionSaveLayerProbe(
      painter: painter,
      preparedScene: painter.prepareForPaint(canvasSize),
    );

    return <String, Object?>{
      'pathNodeCount': pathNodeCount,
      'pathSegments': pathSegments,
      'iterations': iterations,
      'probes': <String, Object?>{
        'paint_no_selection': noSelectionProbe,
        'paint_with_selection': withSelectionProbe,
      },
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

Map<String, Object?> _runStableVisibleWorkingSetPaintCase({
  required int iterations,
}) {
  final scenario = _stableVisibleWorkingSetScenario();
  final controller = SceneStoreController(initialSnapshot: scenario.snapshot);
  controller.write<void>((writer) {
    writer.writeSelectionReplace(scenario.selectedPathIds);
  });
  final renderState = _createProductionBenchmarkRenderState(
    controller: controller,
  );
  const canvasSize = Size(520, 320);

  try {
    final missMetric = _measureOperation(
      iterations: iterations,
      run: (_) {
        final caches = _createBenchmarkPaintCaches();
        final painter = ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          geometryCache: caches.geometryCache,
          textLayoutCache: caches.textLayoutCache,
          strokePathCache: caches.strokePathCache,
          pathMetricsCache: caches.pathMetricsCache,
        );
        _paintScene(painter, canvasSize);
      },
    );

    final hitCaches = _createBenchmarkPaintCaches();
    final hitPainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      geometryCache: hitCaches.geometryCache,
      textLayoutCache: hitCaches.textLayoutCache,
      strokePathCache: hitCaches.strokePathCache,
      pathMetricsCache: hitCaches.pathMetricsCache,
    );
    final hitMetric = _measureOperation(
      iterations: iterations,
      warmUp: () {
        _paintScene(hitPainter, canvasSize);
      },
      run: (_) {
        _paintScene(hitPainter, canvasSize);
      },
    );

    final missProbeCaches = _createBenchmarkPaintCaches();
    final missProbePainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      geometryCache: missProbeCaches.geometryCache,
      textLayoutCache: missProbeCaches.textLayoutCache,
      strokePathCache: missProbeCaches.strokePathCache,
      pathMetricsCache: missProbeCaches.pathMetricsCache,
    );
    final missProbe = _captureStableVisibleWorkingSetPaintProbe(
      run: () {
        _paintScene(missProbePainter, canvasSize);
      },
      caches: missProbeCaches,
    );

    final hitProbeCaches = _createBenchmarkPaintCaches();
    final hitProbePainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      geometryCache: hitProbeCaches.geometryCache,
      textLayoutCache: hitProbeCaches.textLayoutCache,
      strokePathCache: hitProbeCaches.strokePathCache,
      pathMetricsCache: hitProbeCaches.pathMetricsCache,
    );
    final hitProbe = _captureStableVisibleWorkingSetPaintProbe(
      warmUp: () {
        _paintScene(hitProbePainter, canvasSize);
      },
      run: () {
        _paintScene(hitProbePainter, canvasSize);
      },
      caches: hitProbeCaches,
    );

    return <String, Object?>{
      'iterations': iterations,
      'visibleNodeCount': scenario.visibleNodeCount,
      'selectedPathCount': scenario.selectedPathIds.length,
      'probes': <String, Object?>{
        'paint_cache_miss': missProbe,
        'paint_cache_hit': hitProbe,
      },
      'metrics': <String, Object?>{
        'paint_cache_miss': missMetric,
        'paint_cache_hit': hitMetric,
      },
    };
  } finally {
    renderState.dispose();
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
  final renderState = _createProductionBenchmarkRenderState(
    controller: controller,
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

    final missProbeCache = SceneTextLayoutCache(maxEntries: 8);
    final missProbePainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      textLayoutCache: missProbeCache,
    );
    final missProbe = _captureCacheChurnProbe(
      run: () {
        _paintScene(missProbePainter, canvasSize);
      },
      readBuildCount: () => missProbeCache.captureProbe().buildCount,
      readHitCount: () => missProbeCache.captureProbe().hitCount,
      readEvictCount: () => missProbeCache.captureProbe().evictCount,
    );

    final hitProbeCache = SceneTextLayoutCache(maxEntries: 8);
    final hitProbePainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      textLayoutCache: hitProbeCache,
    );
    final hitProbe = _captureCacheChurnProbe(
      warmUp: () {
        _paintScene(hitProbePainter, canvasSize);
      },
      run: () {
        _paintScene(hitProbePainter, canvasSize);
      },
      readBuildCount: () => hitProbeCache.captureProbe().buildCount,
      readHitCount: () => hitProbeCache.captureProbe().hitCount,
      readEvictCount: () => hitProbeCache.captureProbe().evictCount,
    );

    return <String, Object?>{
      'iterations': iterations,
      'probes': <String, Object?>{
        'paint_cache_miss': missProbe,
        'paint_cache_hit': hitProbe,
      },
      'metrics': <String, Object?>{
        'paint_cache_miss': missMetric,
        'paint_cache_hit': hitMetric,
      },
    };
  } finally {
    renderState.dispose();
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
  final renderState = _createProductionBenchmarkRenderState(
    controller: controller,
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

    final missProbeCache = SceneStrokePathCache(maxEntries: 8);
    final missProbePainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      strokePathCache: missProbeCache,
    );
    final missProbe = _captureCacheChurnProbe(
      run: () {
        _paintScene(missProbePainter, canvasSize);
      },
      readBuildCount: () => missProbeCache.captureProbe().buildCount,
      readHitCount: () => missProbeCache.captureProbe().hitCount,
      readEvictCount: () => missProbeCache.captureProbe().evictCount,
    );

    final hitProbeCache = SceneStrokePathCache(maxEntries: 8);
    final hitProbePainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      strokePathCache: hitProbeCache,
    );
    final hitProbe = _captureCacheChurnProbe(
      warmUp: () {
        _paintScene(hitProbePainter, canvasSize);
      },
      run: () {
        _paintScene(hitProbePainter, canvasSize);
      },
      readBuildCount: () => hitProbeCache.captureProbe().buildCount,
      readHitCount: () => hitProbeCache.captureProbe().hitCount,
      readEvictCount: () => hitProbeCache.captureProbe().evictCount,
    );

    return <String, Object?>{
      'iterations': iterations,
      'probes': <String, Object?>{
        'paint_cache_miss': missProbe,
        'paint_cache_hit': hitProbe,
      },
      'metrics': <String, Object?>{
        'paint_cache_miss': missMetric,
        'paint_cache_hit': hitMetric,
      },
    };
  } finally {
    renderState.dispose();
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
        cellSize: 1,
        color: const Color(0xFFDDDDDD),
      ),
    ),
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  SceneSnapshot readSnapshot() => controller.snapshot;
  final renderState = SceneControllerSceneViewMainSceneRenderRead(
    storeController: controller,
    readSnapshot: readSnapshot,
    readSelectedNodeIds: () => controller.selectedNodeIds,
    readControllerEpoch: () => controller.controllerEpoch,
    captureFramePreview: () => SceneViewFramePreview.captureSnapshot(
      snapshot: readSnapshot(),
      deltaForNode: _benchmarkZeroPreviewDelta,
    ),
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

    final missProbeCache = SceneStaticLayerCache();
    final missProbePainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      staticLayerCache: missProbeCache,
    );
    final missProbe = _captureStaticBackgroundProbe(
      run: () {
        _paintScene(missProbePainter, canvasSize);
      },
      captureProbe: () => missProbeCache.captureProbe(),
    );

    final hitProbeCache = SceneStaticLayerCache();
    final hitProbePainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      staticLayerCache: hitProbeCache,
    );
    final hitProbe = _captureStaticBackgroundProbe(
      warmUp: () {
        _paintScene(hitProbePainter, canvasSize);
      },
      run: () {
        _paintScene(hitProbePainter, canvasSize);
      },
      captureProbe: () => hitProbeCache.captureProbe(),
    );

    return <String, Object?>{
      'backgroundNodeCount': backgroundNodeCount,
      'iterations': iterations,
      'probes': <String, Object?>{
        'paint_cache_miss': missProbe,
        'paint_cache_hit': hitProbe,
      },
      'metrics': <String, Object?>{
        'paint_cache_miss': missMetric,
        'paint_cache_hit': hitMetric,
      },
    };
  } finally {
    renderState.dispose();
    controller.dispose();
  }
}

Map<String, Object?> _runBackgroundLayerPaintAdmissionCase({
  required int backgroundNodeCount,
  required int iterations,
  required LoadProfileViewport viewport,
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
  SceneSnapshot readSnapshot() => controller.snapshot;
  final renderState = SceneControllerSceneViewMainSceneRenderRead(
    storeController: controller,
    readSnapshot: readSnapshot,
    readSelectedNodeIds: () => controller.selectedNodeIds,
    readControllerEpoch: () => controller.controllerEpoch,
    captureFramePreview: () => SceneViewFramePreview.captureSnapshot(
      snapshot: readSnapshot(),
      deltaForNode: _benchmarkZeroPreviewDelta,
    ),
  );
  final painter = ScenePainter(
    controller: renderState,
    imageResolver: (_) => null,
  );
  final query = ScenePaintCandidateQuery(
    viewportRect: Rect.fromLTWH(
      0,
      0,
      viewport.width.toDouble(),
      viewport.height.toDouble(),
    ),
    visibilityRect: Rect.fromLTWH(
      -1,
      -1,
      viewport.width.toDouble() + 2,
      viewport.height.toDouble() + 2,
    ),
  );
  final canvasSize = Size(
    viewport.width.toDouble(),
    viewport.height.toDouble(),
  );

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
      'viewport': viewport.toJson(),
      'metrics': <String, Object?>{
        'enumerate_viewport': enumerateMetric,
        'paint_viewport': paintMetric,
      },
    };
  } finally {
    renderState.dispose();
    controller.dispose();
  }
}

SceneSnapshot _selectionPathSnapshot({
  required int pathNodeCount,
  required int pathSegments,
}) {
  final pathData = _closedRibbonPath(segments: pathSegments);
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

SceneControllerSceneViewMainSceneRenderRead
_createProductionBenchmarkRenderState({
  required SceneStoreController controller,
}) {
  SceneSnapshot readSnapshot() => controller.snapshot;
  return SceneControllerSceneViewMainSceneRenderRead(
    storeController: controller,
    readSnapshot: readSnapshot,
    readSelectedNodeIds: () => controller.selectedNodeIds,
    readControllerEpoch: () => controller.controllerEpoch,
    captureFramePreview: () => SceneViewFramePreview.captureSnapshot(
      snapshot: readSnapshot(),
      deltaForNode: _benchmarkZeroPreviewDelta,
    ),
  );
}

Offset _benchmarkZeroPreviewDelta(NodeId _) => Offset.zero;

_BenchmarkPaintCaches _createBenchmarkPaintCaches() {
  return (
    geometryCache: RenderGeometryCache(maxEntries: 8),
    textLayoutCache: SceneTextLayoutCache(maxEntries: 2),
    strokePathCache: SceneStrokePathCache(maxEntries: 2),
    pathMetricsCache: ScenePathMetricsCache(maxEntries: 2),
  );
}

({SceneSnapshot snapshot, Set<NodeId> selectedPathIds, int visibleNodeCount})
_stableVisibleWorkingSetScenario() {
  final selectedPathIds = <NodeId>{};
  final nodes = <NodeSnapshot>[];
  for (var i = 0; i < 3; i++) {
    nodes.add(
      TextNodeSnapshot(
        id: 'stable-text-$i',
        text: 'stable text $i',
        fontSize: 14,
        color: const Color(0xFF000000),
        textDirection: TextDirection.ltr,
        transform: Transform2D.translation(
          Offset(24 + (i * 160).toDouble(), 24),
        ),
      ),
    );
    nodes.add(
      StrokeNodeSnapshot(
        id: 'stable-stroke-$i',
        points: _linearPoints(count: 96, y: 0),
        thickness: 3,
        color: const Color(0xFF0055AA),
        transform: Transform2D.translation(
          Offset(24 + (i * 160).toDouble(), 96),
        ),
      ),
    );
    final pathId = 'stable-path-$i';
    selectedPathIds.add(pathId);
    nodes.add(
      PathNodeSnapshot(
        id: pathId,
        svgPathData: _closedRibbonPath(segments: 48),
        strokeColor: const Color(0xFF663300),
        strokeWidth: 2,
        transform: Transform2D.translation(
          Offset(24 + (i * 160).toDouble(), 156),
        ),
      ),
    );
    nodes.add(
      RectNodeSnapshot(
        id: 'stable-rect-$i',
        size: const Size(72, 28),
        fillColor: const Color(0xFF88CCEE),
        transform: Transform2D.translation(
          Offset(24 + (i * 160).toDouble(), 252),
        ),
      ),
    );
  }
  return (
    snapshot: SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-stable-visible-paint',
          nodes: nodes,
        ),
      ],
    ),
    selectedPathIds: selectedPathIds,
    visibleNodeCount: nodes.length,
  );
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

String _closedRibbonPath({required int segments}) {
  final buf = StringBuffer('M0 0');
  for (var i = 1; i <= segments; i++) {
    buf.write(' L${i.toDouble()} 0');
  }
  buf.write(' L${segments.toDouble()} 20');
  buf.write(' L0 20 Z');
  return buf.toString();
}

void _paintScene(ScenePainter painter, Size size) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  picture.dispose();
}

void _paintPreparedScene(
  ScenePainter painter,
  ScenePainterPreparedScene preparedScene,
) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paintPrepared(canvas, preparedScene);
  final picture = recorder.endRecording();
  picture.dispose();
}

Map<String, num> _captureSelectionSaveLayerProbe({
  required ScenePainter painter,
  required ScenePainterPreparedScene preparedScene,
}) {
  final canvas = TestRecordingCanvas();
  painter.paintPrepared(canvas, preparedScene);
  final saveLayerBounds = canvas.invocations
      .where((invocation) => invocation.invocation.memberName == #saveLayer)
      .map((invocation) => invocation.invocation.positionalArguments.first)
      .toList(growable: false);
  var unboundedSaveLayerCount = 0;
  var saveLayerBoundsArea = 0.0;
  for (final bounds in saveLayerBounds) {
    if (bounds == null) {
      unboundedSaveLayerCount += 1;
      continue;
    }
    if (bounds is Rect) {
      saveLayerBoundsArea += bounds.width * bounds.height;
    }
  }
  return <String, num>{
    'saveLayerCount': saveLayerBounds.length,
    'unboundedSaveLayerCount': unboundedSaveLayerCount,
    'saveLayerBoundsArea': saveLayerBoundsArea,
  };
}

Map<String, num> _captureCacheChurnProbe({
  void Function()? warmUp,
  required void Function() run,
  required int Function() readBuildCount,
  required int Function() readHitCount,
  required int Function() readEvictCount,
}) {
  warmUp?.call();
  final buildBefore = readBuildCount();
  final hitBefore = readHitCount();
  final evictBefore = readEvictCount();
  run();
  return <String, num>{
    'buildDelta': readBuildCount() - buildBefore,
    'hitDelta': readHitCount() - hitBefore,
    'evictDelta': readEvictCount() - evictBefore,
  };
}

Map<String, num> _captureStableVisibleWorkingSetPaintProbe({
  void Function()? warmUp,
  required void Function() run,
  required _BenchmarkPaintCaches caches,
}) {
  warmUp?.call();
  final geometryBefore = caches.geometryCache.captureProbe();
  final textBefore = caches.textLayoutCache.captureProbe();
  final strokeBefore = caches.strokePathCache.captureProbe();
  final pathMetricsBefore = caches.pathMetricsCache.captureProbe();
  run();
  final geometryAfter = caches.geometryCache.captureProbe();
  final textAfter = caches.textLayoutCache.captureProbe();
  final strokeAfter = caches.strokePathCache.captureProbe();
  final pathMetricsAfter = caches.pathMetricsCache.captureProbe();
  return <String, num>{
    'geometryBuildDelta': geometryAfter.buildCount - geometryBefore.buildCount,
    'geometryHitDelta': geometryAfter.hitCount - geometryBefore.hitCount,
    'geometryEvictDelta': geometryAfter.evictCount - geometryBefore.evictCount,
    'textBuildDelta': textAfter.buildCount - textBefore.buildCount,
    'textHitDelta': textAfter.hitCount - textBefore.hitCount,
    'textEvictDelta': textAfter.evictCount - textBefore.evictCount,
    'strokeBuildDelta': strokeAfter.buildCount - strokeBefore.buildCount,
    'strokeHitDelta': strokeAfter.hitCount - strokeBefore.hitCount,
    'strokeEvictDelta': strokeAfter.evictCount - strokeBefore.evictCount,
    'pathMetricsBuildDelta':
        pathMetricsAfter.buildCount - pathMetricsBefore.buildCount,
    'pathMetricsHitDelta':
        pathMetricsAfter.hitCount - pathMetricsBefore.hitCount,
    'pathMetricsEvictDelta':
        pathMetricsAfter.evictCount - pathMetricsBefore.evictCount,
  };
}

Map<String, num> _captureStaticBackgroundProbe({
  void Function()? warmUp,
  required void Function() run,
  required ({
    int buildCount,
    int disposeCount,
    int gridLoopIterations,
    int gridDrawnLineCount,
  })
  Function()
  captureProbe,
}) {
  warmUp?.call();
  final before = captureProbe();
  run();
  final after = captureProbe();
  return <String, num>{
    'buildDelta': after.buildCount - before.buildCount,
    'disposeDelta': after.disposeCount - before.disposeCount,
    'gridLoopIterations': after.gridLoopIterations - before.gridLoopIterations,
    'gridDrawnLineCount': after.gridDrawnLineCount - before.gridDrawnLineCount,
  };
}

void _emitResult({
  required String profile,
  required String name,
  required Map<String, Object?> metrics,
  required Map<String, Object?> contract,
}) {
  final rawMetrics = metrics['metrics'];
  final rawProbes = metrics['probes'];
  final record = <String, Object?>{
    'name': name,
    'profile': profile,
    'contract': contract,
    for (final entry in metrics.entries)
      if (entry.key != 'metrics' && entry.key != 'probes')
        entry.key: entry.value,
    'metrics': rawMetrics is Map<String, Object?> ? rawMetrics : metrics,
    if (rawProbes is Map<String, Object?>) 'probes': rawProbes,
  };
  final line = '$_resultPrefix${jsonEncode(record)}';
  // ignore: avoid_print, benchmark helper emits machine-readable JSON lines
  print(line);
}
