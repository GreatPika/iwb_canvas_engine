const List<String> loadProfileRequiredMetricKeys = <String>[
  'avgUs',
  'minUs',
  'p95Us',
  'maxUs',
  'avgRssDeltaBytes',
  'minRssDeltaBytes',
  'p95RssDeltaBytes',
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

const List<String> _selectionPathRequiredOperations = <String>[
  'paint_no_selection',
  'paint_with_selection',
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
        nodeCases: <LoadProfileNodeCase>[LoadProfileNodeCase(nodeCount: 10000)],
        nodeIterations: 3,
        strokeCases: <LoadProfileStrokeCase>[
          LoadProfileStrokeCase(strokeCount: 1000, pointsPerStroke: 256),
        ],
        strokeIterations: 2,
        selectionPathNodeCount: 400,
        selectionPathSegments: 128,
        selectionPathIterations: 3,
        largeQueryNodeCount: 10000,
        longPathSegments: 2000,
        worstCaseIterations: 2,
        maxRegressionPctByMetric: <String, double>{
          'avgUs': 35,
          'p95Us': 45,
          'avgRssDeltaBytes': 150,
          'p95RssDeltaBytes': 200,
        },
        maxAbsoluteValueByMetric: <String, double>{
          'avgRssDeltaBytes': 1048576,
          'p95RssDeltaBytes': 2097152,
        },
      ),
      'full': LoadProfilePolicy(
        profile: 'full',
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
        maxRegressionPctByMetric: <String, double>{
          'avgUs': 35,
          'p95Us': 45,
          'avgRssDeltaBytes': 150,
          'p95RssDeltaBytes': 200,
        },
        maxAbsoluteValueByMetric: <String, double>{
          'avgRssDeltaBytes': 1048576,
          'p95RssDeltaBytes': 2097152,
        },
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
    required this.maxRegressionPctByMetric,
    required this.maxAbsoluteValueByMetric,
  });

  final String profile;
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
  final Map<String, double> maxRegressionPctByMetric;
  final Map<String, double> maxAbsoluteValueByMetric;

  List<String> get requiredCaseNames => <String>[
    ...nodeCases.map((c) => c.name),
    ...strokeCases.map((c) => c.name),
    selectionPathCaseName,
    worstCaseName,
  ];

  List<String> requiredOperationsForCase(String caseName) {
    if (nodeCases.any((c) => c.name == caseName)) {
      return _nodeCaseRequiredOperations;
    }
    if (strokeCases.any((c) => c.name == caseName)) {
      return _strokeCaseRequiredOperations;
    }
    if (caseName == selectionPathCaseName) {
      return _selectionPathRequiredOperations;
    }
    if (caseName == worstCaseName) {
      return _worstCaseRequiredOperations;
    }
    return const <String>[];
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

const String selectionPathCaseName = 'selection_path_metrics';
const String worstCaseName = 'worst_case';
