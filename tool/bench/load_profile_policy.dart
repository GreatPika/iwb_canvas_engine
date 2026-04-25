const List<String> _loadProfileRequiredMetricKeys = <String>[
  'avgUs',
  'minUs',
  'maxUs',
  'avgRssDeltaBytes',
  'minRssDeltaBytes',
  'maxRssDeltaBytes',
];

const List<String> _nodeCaseRequiredOperations = <String>[
  'single_node_patch',
  'single_node_transform',
  'toggle_selection',
  'move_selection',
];

const List<String> _strokeCaseRequiredOperations = <String>[
  'single_stroke_patch_thickness',
  'single_stroke_patch_points',
  'toggle_selection',
];

const List<String> writeCommitAttributionProbeKeys = <String>[
  'stateCommitExecuted',
  'effectsOnlyCommitExecuted',
  'criticalValidationRan',
  'criticalValidationFullScene',
  'criticalValidationTrackedNodeCount',
  'debugFullStoreInvariantPassRan',
];

const Map<String, Object> fixedHarnessRuntimeMetadata = <String, Object>{
  'runtimeMode': 'debug',
  'assertionsEnabled': true,
  'debugInvariantMode': 'full_store',
};

const List<String> _selectionPathPaintRequiredOperations = <String>[
  'paint_no_selection',
  'paint_with_selection',
];

const List<String> _cacheBranchRequiredOperations = <String>[
  'paint_cache_miss',
  'paint_cache_hit',
];

const List<String> _cacheChurnProbeKeys = <String>[
  'buildDelta',
  'hitDelta',
  'evictDelta',
];

const List<String> _selectionCompositingProbeKeys = <String>[
  'saveLayerCount',
  'unboundedSaveLayerCount',
  'saveLayerBoundsArea',
];

const List<String> _stableVisibleWorkingSetPaintProbeKeys = <String>[
  'geometryBuildDelta',
  'geometryHitDelta',
  'geometryEvictDelta',
  'textBuildDelta',
  'textHitDelta',
  'textEvictDelta',
  'strokeBuildDelta',
  'strokeHitDelta',
  'strokeEvictDelta',
  'pathMetricsBuildDelta',
  'pathMetricsHitDelta',
  'pathMetricsEvictDelta',
];

const List<String> _staticBackgroundProbeKeys = <String>[
  'buildDelta',
  'disposeDelta',
  'gridLoopIterations',
  'gridDrawnLineCount',
];

const List<String> _selectionPathStagingRequiredOperations = <String>[
  'stage_no_selection',
  'stage_with_selection',
];

const List<String> _selectionPathStagingProbeKeys = <String>[
  'selectedCommittedBoundsReuseDelta',
];

const List<String> _backgroundLayerPaintAdmissionRequiredOperations = <String>[
  'enumerate_viewport',
  'paint_viewport',
];

const List<String> _backgroundLayerPaintAdmissionProbeKeys = <String>[
  'snapshotAdmissionBuildDelta',
  'snapshotAdmissionHitDelta',
  'snapshotAdmissionEvictDelta',
];

const List<String> eraserCommitProbeKeys = <String>[
  'spatialQueryCount',
  'preciseSegmentCheckCount',
  'projectedPointCount',
  'deletedCount',
];

const List<String> _worstCaseRequiredOperations = <String>[
  'huge_bounds.query',
  'huge_bounds.move_selection',
  'huge_rect_select',
  'very_long_path.patch_svg_path',
  'very_long_path.query_candidates',
];

const Map<String, LoadProfilePolicy> _loadProfilePolicies =
    <String, LoadProfilePolicy>{
      'smoke': LoadProfilePolicy(
        profile: 'smoke',
        profileSemantics: 'product_realistic',
        nodeCases: <LoadProfileNodeCase>[LoadProfileNodeCase(nodeCount: 1000)],
        nodeIterations: 3,
        strokeCases: <LoadProfileStrokeCase>[
          LoadProfileStrokeCase(strokeCount: 1000, pointsPerStroke: 256),
        ],
        strokeIterations: 2,
        selectionPathNodeCount: 400,
        selectionPathSegments: 128,
        selectionPathIterations: 3,
        largeQueryNodeCount: 1000,
        longPathSegments: 2000,
        worstCaseIterations: 2,
        includesWorstCaseDiagnostics: false,
        backgroundViewport: LoadProfileViewport(width: 3840, height: 2160),
        maxRegressionPctByMetric: <String, double>{'avgUs': 35},
        maxAbsoluteValueByMetric: <String, double>{},
      ),
      'full': LoadProfilePolicy(
        profile: 'full',
        profileSemantics: 'stress_nightly',
        nodeCases: <LoadProfileNodeCase>[
          LoadProfileNodeCase(nodeCount: 10000),
          LoadProfileNodeCase(nodeCount: 50000),
          LoadProfileNodeCase(nodeCount: 100000),
        ],
        nodeIterations: 4,
        strokeCases: <LoadProfileStrokeCase>[
          LoadProfileStrokeCase(strokeCount: 1000, pointsPerStroke: 1024),
          LoadProfileStrokeCase(strokeCount: 5000, pointsPerStroke: 512),
        ],
        strokeIterations: 3,
        selectionPathNodeCount: 2000,
        selectionPathSegments: 256,
        selectionPathIterations: 4,
        largeQueryNodeCount: 50000,
        longPathSegments: 12000,
        worstCaseIterations: 3,
        includesWorstCaseDiagnostics: true,
        backgroundViewport: LoadProfileViewport(width: 240, height: 160),
        maxRegressionPctByMetric: <String, double>{'avgUs': 35},
        maxAbsoluteValueByMetric: <String, double>{},
      ),
    };

LoadProfilePolicy loadProfilePolicyFor(String rawProfile) {
  final normalized = rawProfile.trim().toLowerCase();
  final policy = _loadProfilePolicies[normalized];
  if (policy == null) {
    throw ArgumentError.value(
      rawProfile,
      'profile',
      'Must be one of: ${_loadProfilePolicies.keys.join(', ')}.',
    );
  }
  return policy;
}

List<String> validateProducedLoadProfileCaseNames({
  required LoadProfilePolicy policy,
  required Iterable<String> caseNames,
}) {
  final seen = <String>{};
  final duplicates = <String>[];

  for (final caseName in caseNames) {
    if (!seen.add(caseName)) {
      duplicates.add(caseName);
    }
  }

  final expected = policy.requiredCaseNames.toSet();
  final actual = seen;
  final missing = expected.difference(actual).toList()..sort();
  final unexpected = actual.difference(expected).toList()..sort();

  final issues = <String>[];
  if (duplicates.isNotEmpty) {
    duplicates.sort();
    issues.add('duplicate benchmark cases: ${duplicates.join(', ')}');
  }
  if (missing.isNotEmpty) {
    issues.add('missing required benchmark cases: ${missing.join(', ')}');
  }
  if (unexpected.isNotEmpty) {
    issues.add('unexpected benchmark cases: ${unexpected.join(', ')}');
  }
  return issues;
}

class LoadProfilePolicy {
  const LoadProfilePolicy({
    required this.profile,
    required this.profileSemantics,
    required this.nodeCases,
    required this.nodeIterations,
    required this.strokeCases,
    required this.strokeIterations,
    required this.selectionPathNodeCount,
    required this.selectionPathSegments,
    required this.selectionPathIterations,
    required this.largeQueryNodeCount,
    required this.longPathSegments,
    required this.worstCaseIterations,
    required this.includesWorstCaseDiagnostics,
    required this.backgroundViewport,
    required this.maxRegressionPctByMetric,
    required this.maxAbsoluteValueByMetric,
  });

  final String profile;
  final String profileSemantics;
  final List<LoadProfileNodeCase> nodeCases;
  final int nodeIterations;
  final List<LoadProfileStrokeCase> strokeCases;
  final int strokeIterations;
  final int selectionPathNodeCount;
  final int selectionPathSegments;
  final int selectionPathIterations;
  final int largeQueryNodeCount;
  final int longPathSegments;
  final int worstCaseIterations;
  final bool includesWorstCaseDiagnostics;
  final LoadProfileViewport backgroundViewport;
  final Map<String, double> maxRegressionPctByMetric;
  final Map<String, double> maxAbsoluteValueByMetric;
  List<String> get requiredMetricKeys => _loadProfileRequiredMetricKeys;

  List<String> get requiredCaseNames => <String>[
    ...nodeCases.map((c) => c.name),
    ...strokeCases.map((c) => c.name),
    selectionPathPainterOnlyCaseName,
    selectionPathCandidateStagingCaseName,
    selectionPathEndToEndPaintCaseName,
    stableVisibleWorkingSetPaintCaseName,
    textLayoutCacheCaseName,
    strokePathCacheCaseName,
    staticBackgroundCacheCaseName,
    backgroundLayerPaintAdmissionCaseName,
    if (profile == 'full') eraserLongPathMixedSceneCaseName,
    if (includesWorstCaseDiagnostics) worstCaseName,
  ];

  Map<String, Object?> get reportMetadata => <String, Object?>{
    'profileSemantics': profileSemantics,
    'maxNodeCount': nodeCases.last.nodeCount,
    'includesWorstCaseDiagnostics': includesWorstCaseDiagnostics,
    'backgroundViewport': backgroundViewport.toJson(),
  };

  Map<String, List<String>> requiredProbeKeysForCase(String caseName) {
    if (nodeCases.any((c) => c.name == caseName)) {
      return <String, List<String>>{
        for (final operation in _nodeCaseRequiredOperations)
          operation: writeCommitAttributionProbeKeys,
      };
    }
    if (strokeCases.any((c) => c.name == caseName)) {
      return <String, List<String>>{
        for (final operation in _strokeCaseRequiredOperations)
          operation: writeCommitAttributionProbeKeys,
      };
    }
    if (caseName == textLayoutCacheCaseName ||
        caseName == strokePathCacheCaseName) {
      return <String, List<String>>{
        'paint_cache_miss': _cacheChurnProbeKeys,
        'paint_cache_hit': _cacheChurnProbeKeys,
      };
    }
    if (caseName == stableVisibleWorkingSetPaintCaseName) {
      return <String, List<String>>{
        'paint_cache_miss': _stableVisibleWorkingSetPaintProbeKeys,
        'paint_cache_hit': _stableVisibleWorkingSetPaintProbeKeys,
      };
    }
    if (caseName == staticBackgroundCacheCaseName) {
      return <String, List<String>>{
        'paint_cache_miss': _staticBackgroundProbeKeys,
        'paint_cache_hit': _staticBackgroundProbeKeys,
      };
    }
    if (caseName == selectionPathPainterOnlyCaseName ||
        caseName == selectionPathEndToEndPaintCaseName) {
      return <String, List<String>>{
        'paint_no_selection': _selectionCompositingProbeKeys,
        'paint_with_selection': _selectionCompositingProbeKeys,
      };
    }
    if (caseName == selectionPathCandidateStagingCaseName) {
      return <String, List<String>>{
        'stage_with_selection': _selectionPathStagingProbeKeys,
      };
    }
    if (caseName == backgroundLayerPaintAdmissionCaseName) {
      return <String, List<String>>{
        'enumerate_viewport': _backgroundLayerPaintAdmissionProbeKeys,
      };
    }
    if (caseName == eraserLongPathMixedSceneCaseName) {
      return <String, List<String>>{
        eraserLongPathCommitOperationName: eraserCommitProbeKeys,
      };
    }
    return const <String, List<String>>{};
  }

  List<String> requiredProbeKeysForOperation({
    required String caseName,
    required String operationName,
  }) {
    return requiredProbeKeysForCase(caseName)[operationName] ??
        const <String>[];
  }

  List<String> requiredOperationsForCase(String caseName) {
    if (nodeCases.any((c) => c.name == caseName)) {
      return _nodeCaseRequiredOperations;
    }
    if (strokeCases.any((c) => c.name == caseName)) {
      return _strokeCaseRequiredOperations;
    }
    if (caseName == selectionPathPainterOnlyCaseName ||
        caseName == selectionPathEndToEndPaintCaseName) {
      return _selectionPathPaintRequiredOperations;
    }
    if (caseName == selectionPathCandidateStagingCaseName) {
      return _selectionPathStagingRequiredOperations;
    }
    if (caseName == stableVisibleWorkingSetPaintCaseName ||
        caseName == textLayoutCacheCaseName ||
        caseName == strokePathCacheCaseName ||
        caseName == staticBackgroundCacheCaseName) {
      return _cacheBranchRequiredOperations;
    }
    if (caseName == backgroundLayerPaintAdmissionCaseName) {
      return _backgroundLayerPaintAdmissionRequiredOperations;
    }
    if (caseName == eraserLongPathMixedSceneCaseName) {
      return const <String>[eraserLongPathCommitOperationName];
    }
    if (caseName == worstCaseName) {
      return _worstCaseRequiredOperations;
    }
    return const <String>[];
  }

  Map<String, Object?> contractForCase(String caseName) {
    final requiredOperations = requiredOperationsForCase(caseName);
    final gatedMetrics = <String>{
      ...maxRegressionPctByMetric.keys,
      ...maxAbsoluteValueByMetric.keys,
    }.toList()..sort();
    final diagnosticMetrics = requiredMetricKeys
        .where((metric) => !gatedMetrics.contains(metric))
        .toList(growable: false);

    return <String, Object?>{
      'profileSemantics': profileSemantics,
      'scenario': _scenarioForCase(caseName),
      'operations': <String, Object?>{
        for (final operation in requiredOperations)
          operation: <String, Object?>{
            'executionMode': executionModeForOperation(
              caseName: caseName,
              operationName: operation,
            ),
            'warmupIterations': warmupIterationsForOperation(
              caseName: caseName,
              operationName: operation,
            ),
            'measuredIterations': measuredIterationsForCase(caseName),
            'probeKeys': requiredProbeKeysForOperation(
              caseName: caseName,
              operationName: operation,
            ),
            'gatedMetrics': gatedMetrics,
            'diagnosticMetrics': diagnosticMetrics,
          },
      },
    };
  }

  Map<String, Object?> _scenarioForCase(String caseName) {
    for (final nodeCase in nodeCases) {
      if (nodeCase.name == caseName) {
        return <String, Object?>{
          'kind': 'node_scale',
          'nodeCount': nodeCase.nodeCount,
        };
      }
    }
    for (final strokeCase in strokeCases) {
      if (strokeCase.name == caseName) {
        return <String, Object?>{
          'kind': 'stroke_scale',
          'strokeCount': strokeCase.strokeCount,
          'pointsPerStroke': strokeCase.pointsPerStroke,
        };
      }
    }
    if (caseName == backgroundLayerPaintAdmissionCaseName) {
      return <String, Object?>{
        'kind': 'background_viewport',
        'nodeCount': nodeCases.last.nodeCount,
        'viewport': backgroundViewport.toJson(),
      };
    }
    if (caseName == stableVisibleWorkingSetPaintCaseName) {
      return <String, Object?>{'kind': 'stable_visible_working_set_paint'};
    }
    if (caseName == eraserLongPathMixedSceneCaseName) {
      return <String, Object?>{'kind': 'eraser_long_path_mixed_scene'};
    }
    if (caseName == worstCaseName) {
      return <String, Object?>{'kind': 'stress_worst_case'};
    }
    return <String, Object?>{'kind': caseName};
  }

  int measuredIterationsForCase(String caseName) {
    if (nodeCases.any((c) => c.name == caseName)) {
      return nodeIterations;
    }
    if (strokeCases.any((c) => c.name == caseName)) {
      return strokeIterations;
    }
    if (caseName == backgroundLayerPaintAdmissionCaseName) {
      return nodeIterations;
    }
    if (caseName == worstCaseName) {
      return worstCaseIterations;
    }
    return selectionPathIterations;
  }

  String executionModeForOperation({
    required String caseName,
    required String operationName,
  }) {
    if ((caseName == stableVisibleWorkingSetPaintCaseName ||
            caseName == textLayoutCacheCaseName ||
            caseName == strokePathCacheCaseName ||
            caseName == staticBackgroundCacheCaseName) &&
        operationName == 'paint_cache_hit') {
      return 'steady_state';
    }
    return 'cold_start';
  }

  int warmupIterationsForOperation({
    required String caseName,
    required String operationName,
  }) {
    return executionModeForOperation(
              caseName: caseName,
              operationName: operationName,
            ) ==
            'steady_state'
        ? 1
        : 0;
  }
}

class LoadProfileNodeCase {
  const LoadProfileNodeCase({required this.nodeCount});

  final int nodeCount;

  String get name => 'nodes_$nodeCount';
}

class LoadProfileStrokeCase {
  const LoadProfileStrokeCase({
    required this.strokeCount,
    required this.pointsPerStroke,
  });

  final int strokeCount;
  final int pointsPerStroke;

  String get name => 'strokes_${strokeCount}_pts_$pointsPerStroke';
}

class LoadProfileViewport {
  const LoadProfileViewport({required this.width, required this.height});

  final int width;
  final int height;

  Map<String, int> toJson() => <String, int>{'width': width, 'height': height};
}

const String selectionPathPainterOnlyCaseName = 'selection_path_painter_only';
const String selectionPathCandidateStagingCaseName =
    'selection_path_candidate_staging';
const String selectionPathEndToEndPaintCaseName =
    'selection_path_end_to_end_paint';
const String stableVisibleWorkingSetPaintCaseName =
    'stable_visible_working_set_paint';
const String textLayoutCacheCaseName = 'text_layout_cache';
const String strokePathCacheCaseName = 'stroke_path_cache';
const String staticBackgroundCacheCaseName = 'static_background_cache';
const String backgroundLayerPaintAdmissionCaseName =
    'background_layer_paint_admission';
const String eraserLongPathMixedSceneCaseName = 'eraser_long_path_mixed_scene';
const String eraserLongPathCommitOperationName = 'erase_path_commit';
const String worstCaseName = 'worst_case';
