import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';

const _resultPrefix = 'IWB_BENCH_RESULT ';

void main() {
  final profile = _resolveProfile();
  final config = _configForProfile(profile);

  for (final nodeCount in config.nodeCounts) {
    test(
      'load profile nodes=$nodeCount profile=$profile',
      () {
        final metrics = _runNodeScaleCase(
          nodeCount: nodeCount,
          iterations: config.nodeIterations,
        );
        _emitResult(
          profile: profile,
          name: 'nodes_$nodeCount',
          metrics: metrics,
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }

  for (final strokeCase in config.strokeCases) {
    test(
      'load profile strokes=${strokeCase.strokeCount} points=${strokeCase.pointsPerStroke} profile=$profile',
      () {
        final metrics = _runStrokeScaleCase(
          strokeCount: strokeCase.strokeCount,
          pointsPerStroke: strokeCase.pointsPerStroke,
          iterations: config.strokeIterations,
        );
        _emitResult(
          profile: profile,
          name:
              'strokes_${strokeCase.strokeCount}_pts_${strokeCase.pointsPerStroke}',
          metrics: metrics,
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }

  test(
    'load profile worst-case profile=$profile',
    () {
      final metrics = _runWorstCaseProfile(
        largeQueryNodeCount: config.largeQueryNodeCount,
        longPathSegments: config.longPathSegments,
        iterations: config.worstCaseIterations,
      );
      _emitResult(profile: profile, name: 'worst_case', metrics: metrics);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

String _resolveProfile() {
  final raw = Platform.environment['IWB_BENCH_PROFILE']?.trim().toLowerCase();
  if (raw == null || raw.isEmpty) {
    return 'smoke';
  }
  if (raw == 'smoke' || raw == 'full') {
    return raw;
  }
  throw ArgumentError.value(raw, 'IWB_BENCH_PROFILE', 'Must be smoke or full.');
}

_BenchConfig _configForProfile(String profile) {
  switch (profile) {
    case 'smoke':
      return const _BenchConfig(
        nodeCounts: <int>[10000],
        nodeIterations: 3,
        strokeCases: <_StrokeCase>[
          _StrokeCase(strokeCount: 1000, pointsPerStroke: 256),
        ],
        strokeIterations: 2,
        largeQueryNodeCount: 10000,
        longPathSegments: 2000,
        worstCaseIterations: 2,
      );
    case 'full':
      return const _BenchConfig(
        nodeCounts: <int>[10000, 50000, 100000],
        nodeIterations: 4,
        strokeCases: <_StrokeCase>[
          _StrokeCase(strokeCount: 1000, pointsPerStroke: 1024),
          _StrokeCase(strokeCount: 5000, pointsPerStroke: 512),
        ],
        strokeIterations: 3,
        largeQueryNodeCount: 50000,
        longPathSegments: 12000,
        worstCaseIterations: 3,
      );
    default:
      throw StateError('Unsupported profile: $profile');
  }
}

Map<String, Object?> _runNodeScaleCase({
  required int nodeCount,
  required int iterations,
}) {
  final snapshot = SceneSnapshot(
    layers: <LayerSnapshot>[
      LayerSnapshot(
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
  final controller = SceneControllerV2(initialSnapshot: snapshot);
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
    layers: <LayerSnapshot>[LayerSnapshot(nodes: nodes)],
  );
  final controller = SceneControllerV2(initialSnapshot: snapshot);
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

Map<String, Object?> _runHugeBoundsMetric({required int iterations}) {
  final snapshot = SceneSnapshot(
    layers: <LayerSnapshot>[
      LayerSnapshot(
        nodes: const <NodeSnapshot>[
          RectNodeSnapshot(id: 'huge', size: Size(1e9, 1e9)),
        ],
      ),
    ],
  );
  final controller = SceneControllerV2(initialSnapshot: snapshot);
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
    layers: <LayerSnapshot>[
      LayerSnapshot(
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
  final controller = SceneControllerV2(initialSnapshot: snapshot);
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
    layers: <LayerSnapshot>[
      LayerSnapshot(
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
  final controller = SceneControllerV2(initialSnapshot: snapshot);
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
  final samples = <int>[];
  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    run(i);
    sw.stop();
    samples.add(sw.elapsedMicroseconds);
  }
  samples.sort();
  final total = samples.fold<int>(0, (sum, value) => sum + value);
  final p95Index =
      ((samples.length * 95) / 100).ceil().clamp(1, samples.length) - 1;
  return <String, Object?>{
    'avgUs': (total / samples.length).round(),
    'minUs': samples.first,
    'p95Us': samples[p95Index],
    'maxUs': samples.last,
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
  // ignore: avoid_print
  print(line);
}

class _BenchConfig {
  const _BenchConfig({
    required this.nodeCounts,
    required this.nodeIterations,
    required this.strokeCases,
    required this.strokeIterations,
    required this.largeQueryNodeCount,
    required this.longPathSegments,
    required this.worstCaseIterations,
  });

  final List<int> nodeCounts;
  final int nodeIterations;
  final List<_StrokeCase> strokeCases;
  final int strokeIterations;
  final int largeQueryNodeCount;
  final int longPathSegments;
  final int worstCaseIterations;
}

class _StrokeCase {
  const _StrokeCase({required this.strokeCount, required this.pointsPerStroke});

  final int strokeCount;
  final int pointsPerStroke;
}
