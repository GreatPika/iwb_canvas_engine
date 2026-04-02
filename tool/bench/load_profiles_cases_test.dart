import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart' show sceneSizeMax;
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
        _emitResult(profile: profile, name: nodeCase.name, metrics: metrics);
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
        _emitResult(profile: profile, name: strokeCase.name, metrics: metrics);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }

  test(
    'load profile selection-path-metrics profile=$profile',
    () {
      final metrics = _runSelectionPathMetricsCase(
        pathNodeCount: policy.selectionPathNodeCount,
        pathSegments: policy.selectionPathSegments,
        iterations: policy.selectionPathIterations,
      );
      _emitResult(
        profile: profile,
        name: selectionPathCaseName,
        metrics: metrics,
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
      _emitResult(profile: profile, name: worstCaseName, metrics: metrics);
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
    controller.querySpatialCandidates(const Rect.fromLTWH(0, 0, 1, 1));

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
        controller.querySpatialCandidates(
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
    controller.querySpatialCandidates(const Rect.fromLTWH(0, 0, 1, 1));

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

Map<String, Object?> _runSelectionPathMetricsCase({
  required int pathNodeCount,
  required int pathSegments,
  required int iterations,
}) {
  final pathData = _horizontalPath(segments: pathSegments);
  final nodes = <NodeSnapshot>[
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
  ];
  final snapshot = SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(id: 'layer-auto-selection-path', nodes: nodes),
    ],
  );
  final controller = SceneStoreController(initialSnapshot: snapshot);
  final pathCache = ScenePathMetricsCache(maxEntries: pathNodeCount * 2);
  final painter = ScenePainter(
    controller: controller,
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
    controller.dispose();
  }
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
        controller.querySpatialCandidates(const Rect.fromLTWH(0, 0, 10, 10));
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
        controller.querySpatialCandidates(
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
        controller.querySpatialCandidates(
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
        controller.querySpatialCandidates(
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
  required void Function(int iteration) run,
}) {
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
  final p95Index =
      ((latencySamplesUs.length * 95) / 100).ceil().clamp(
        1,
        latencySamplesUs.length,
      ) -
      1;
  return <String, Object?>{
    'avgUs': (totalLatencyUs / latencySamplesUs.length).round(),
    'minUs': latencySamplesUs.first,
    'p95Us': latencySamplesUs[p95Index],
    'maxUs': latencySamplesUs.last,
    'avgRssDeltaBytes': (totalRssDeltaBytes / rssDeltaSamplesBytes.length)
        .round(),
    'minRssDeltaBytes': rssDeltaSamplesBytes.first,
    'p95RssDeltaBytes': rssDeltaSamplesBytes[p95Index],
    'maxRssDeltaBytes': rssDeltaSamplesBytes.last,
  };
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
}) {
  final record = <String, Object?>{
    'name': name,
    'profile': profile,
    'metrics': metrics,
  };
  final line = '$_resultPrefix${jsonEncode(record)}';
  // ignore: avoid_print, benchmark helper emits machine-readable JSON lines
  print(line);
}
