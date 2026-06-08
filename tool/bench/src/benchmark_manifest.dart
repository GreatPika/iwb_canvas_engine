import 'dart:io';

import 'package:yaml/yaml.dart';

const benchmarkManifestPath = 'docs/_registry/benchmarks.yaml';
const benchmarkManifestVersion = 'benchmark_measurement_boundary_v3';
const benchmarkToolSchemaVersion = 4;

final class BenchmarkManifest {
  const BenchmarkManifest({
    required this.manifestVersion,
    required this.toolSchemaVersion,
    required this.releaseContour,
    required this.profiles,
    required this.budgetClasses,
    required this.memoryScopes,
    required this.cases,
    required this.postBaselineRegressionCaps,
    required this.firstBaselineReferenceLimits,
  });

  final String manifestVersion;
  final int toolSchemaVersion;
  final BenchmarkReleaseContour releaseContour;
  final List<BenchmarkProfile> profiles;
  final List<BenchmarkBudgetClass> budgetClasses;
  final List<BenchmarkMemoryScope> memoryScopes;
  final List<BenchmarkCase> cases;
  final Map<String, num> postBaselineRegressionCaps;
  final Map<String, num> firstBaselineReferenceLimits;

  Map<String, BenchmarkProfile> get profilesById => {
    for (final profile in profiles) profile.id: profile,
  };

  Map<String, BenchmarkCase> get casesById => {
    for (final benchmarkCase in cases) benchmarkCase.id: benchmarkCase,
  };

  static BenchmarkManifest load({String path = benchmarkManifestPath}) {
    return parse(File(path).readAsStringSync(), source: path);
  }

  static BenchmarkManifest parse(
    String yamlText, {
    String source = 'manifest',
  }) {
    final raw = loadYaml(yamlText);
    if (raw is! YamlMap) {
      throw const FormatException('benchmark manifest must be a YAML map');
    }
    return _BenchmarkManifestParser(raw, source).parse();
  }
}

final class BenchmarkReleaseContour {
  const BenchmarkReleaseContour({
    required this.runnerLabel,
    required this.osName,
    required this.osVersion,
    required this.flutterChannel,
    required this.flutterVersion,
  });

  final String runnerLabel;
  final String osName;
  final String osVersion;
  final String flutterChannel;
  final String flutterVersion;
}

final class BenchmarkProfile {
  const BenchmarkProfile({
    required this.id,
    required this.warmups,
    required this.repetitions,
    required this.iterations,
    required this.minimumMeasuredMs,
    required this.minimumSamples,
    required this.timingClaims,
    required this.scaleSelection,
  });

  final String id;
  final int warmups;
  final int repetitions;
  final int? iterations;
  final int minimumMeasuredMs;
  final int minimumSamples;
  final bool timingClaims;
  final String scaleSelection;
}

final class BenchmarkBudgetClass {
  const BenchmarkBudgetClass({required this.id, required this.absoluteCaps});

  final String id;
  final Map<String, Object?> absoluteCaps;
}

final class BenchmarkMemoryScope {
  const BenchmarkMemoryScope({required this.id, required this.caps});

  final String id;
  final Map<String, Object?> caps;
}

final class BenchmarkCase {
  const BenchmarkCase({
    required this.id,
    required this.baselinePolicy,
    required this.budgetClasses,
    required this.memoryScope,
    required this.measurementBoundary,
    required this.fixtureShape,
    required this.docsMetricsLabel,
    required this.requiredMetrics,
    required this.exactInvariants,
    required this.scales,
  });

  final String id;
  final String baselinePolicy;
  final List<String> budgetClasses;
  final String memoryScope;
  final BenchmarkMeasurementBoundary measurementBoundary;
  final String fixtureShape;
  final String docsMetricsLabel;
  final List<String> requiredMetrics;
  final List<BenchmarkExactInvariant> exactInvariants;
  final List<BenchmarkScale> scales;

  String get docsScaleLabel {
    final labels = scales.map((scale) => scale.label).toList();
    if (labels.length == 1) {
      return labels.single;
    }
    final tokens = [for (final label in labels) label.split(' ')];
    if (tokens.every((parts) => parts.length >= 3) &&
        tokens.map((parts) => parts.first).toSet().length == 1 &&
        tokens.map((parts) => parts.last).toSet().length == 1) {
      final first = tokens.first.first;
      final last = tokens.first.last;
      final middles = [
        for (final parts in tokens)
          parts.skip(1).take(parts.length - 2).join(' '),
      ];
      if (middles.every((middle) => middle.isNotEmpty)) {
        return '$first ${middles.join('/')} $last';
      }
    }
    return labels.join('/');
  }
}

final class BenchmarkMeasurementBoundary {
  const BenchmarkMeasurementBoundary({
    required this.timedScope,
    required this.setupScope,
    required this.teardownScope,
    required this.primaryTiming,
    required this.primaryMemory,
    required this.setupMetrics,
    required this.setupMemoryMetrics,
  });

  final String timedScope;
  final String setupScope;
  final String teardownScope;
  final String primaryTiming;
  final String primaryMemory;
  final List<String> setupMetrics;
  final List<String> setupMemoryMetrics;
}

final class BenchmarkScale {
  const BenchmarkScale({
    required this.id,
    required this.label,
    required this.profiles,
  });

  final String id;
  final String label;
  final List<String> profiles;
}

final class BenchmarkExactInvariant {
  const BenchmarkExactInvariant({
    required this.name,
    required this.metric,
    required this.expected,
    required this.max,
  });

  final String name;
  final String metric;
  final Object? expected;
  final num? max;
}

final class _ExpectedBenchmarkBoundary {
  const _ExpectedBenchmarkBoundary({
    required this.timedScope,
    required this.setupScope,
    required this.teardownScope,
    required this.primaryTiming,
    required this.primaryMemory,
    required this.fixtureShape,
  });

  final String timedScope;
  final String setupScope;
  final String teardownScope;
  final String primaryTiming;
  final String primaryMemory;
  final String fixtureShape;
}

// The parser keeps the benchmark manifest schema in one owner so validation
// errors are reported against a single source-of-truth reader.
// ignore: number-of-methods, response-for-class, weighted-methods-per-class
final class _BenchmarkManifestParser {
  _BenchmarkManifestParser(this.root, this.source);

  static const _baselinePolicies = {'reference_comparison', 'absolute_budget'};
  static const _timedScopes = {'action_only', 'lifecycle', 'projection_split'};
  static const _setupScopes = {
    'none',
    'per_run_prepared_fixture',
    'per_sample_prepared_fixture',
  };
  static const _teardownScopes = {'excluded', 'measured_lifecycle'};
  static const _primaryTimings = {
    'action',
    'lifecycle',
    'projection_action_total',
  };
  static const _primaryMemories = {'action', 'lifecycle', 'none'};
  static const _fixtureShapes = {
    'normal_spread',
    'dense_stress',
    'resource_set',
    'active_preview',
    'invalid_document',
    'codec_fixture',
    'hot_pointer',
  };
  static const _selectedBoundaryTable = {
    'edit.add_element': _normalActionPerSample,
    'edit.update_visual': _normalActionPerSample,
    'edit.update_transform': _normalActionPerSample,
    'edit.move_selection': _normalActionPerSample,
    'edit.set_camera_offset': _normalActionPerSample,
    'edit.add_line': _normalActionPerSample,
    'input.selected_move_preview': _normalActionPerSample,
    'input.marquee_preview': _normalActionPerSample,
    'input.draw_preview': _normalActionPerSample,
    'input.line_preview': _normalActionPerSample,
    'input.eraser_preview': _normalActionPerSample,
    'input.eraser_budget_exceeded': _ExpectedBenchmarkBoundary(
      timedScope: 'action_only',
      setupScope: 'per_sample_prepared_fixture',
      teardownScope: 'excluded',
      primaryTiming: 'action',
      primaryMemory: 'action',
      fixtureShape: 'dense_stress',
    ),
    'frame.selected_move_preview_cached_ordinary_plan': _normalActionPerRun,
    'frame.main_capture': _normalActionPerRun,
    'frame.overlay_capture': _ExpectedBenchmarkBoundary(
      timedScope: 'action_only',
      setupScope: 'per_run_prepared_fixture',
      teardownScope: 'excluded',
      primaryTiming: 'action',
      primaryMemory: 'action',
      fixtureShape: 'active_preview',
    ),
    'frame.paint_candidates': _normalActionPerRun,
    'resources.resolve_sync': _resourceAction,
    'resources.resolve_sync_cold_budget': _resourceAction,
    'resources.mark_dirty': _resourceAction,
    'resources.mark_all_dirty': _resourceAction,
    'projection.read_document': _ExpectedBenchmarkBoundary(
      timedScope: 'projection_split',
      setupScope: 'per_sample_prepared_fixture',
      teardownScope: 'excluded',
      primaryTiming: 'projection_action_total',
      primaryMemory: 'action',
      fixtureShape: 'normal_spread',
    ),
    'codec.decode_v1': _ExpectedBenchmarkBoundary(
      timedScope: 'lifecycle',
      setupScope: 'per_run_prepared_fixture',
      teardownScope: 'measured_lifecycle',
      primaryTiming: 'lifecycle',
      primaryMemory: 'lifecycle',
      fixtureShape: 'codec_fixture',
    ),
    'load_document.success': _ExpectedBenchmarkBoundary(
      timedScope: 'action_only',
      setupScope: 'per_sample_prepared_fixture',
      teardownScope: 'excluded',
      primaryTiming: 'action',
      primaryMemory: 'action',
      fixtureShape: 'normal_spread',
    ),
    'load_document.breakdown': _ExpectedBenchmarkBoundary(
      timedScope: 'lifecycle',
      setupScope: 'per_run_prepared_fixture',
      teardownScope: 'measured_lifecycle',
      primaryTiming: 'lifecycle',
      primaryMemory: 'lifecycle',
      fixtureShape: 'codec_fixture',
    ),
    'load_document.failure': _ExpectedBenchmarkBoundary(
      timedScope: 'lifecycle',
      setupScope: 'per_sample_prepared_fixture',
      teardownScope: 'measured_lifecycle',
      primaryTiming: 'lifecycle',
      primaryMemory: 'lifecycle',
      fixtureShape: 'invalid_document',
    ),
    'spatial.query_point': _normalActionPerRun,
    'spatial.query_point_dense_stress': _ExpectedBenchmarkBoundary(
      timedScope: 'action_only',
      setupScope: 'per_run_prepared_fixture',
      teardownScope: 'excluded',
      primaryTiming: 'action',
      primaryMemory: 'action',
      fixtureShape: 'dense_stress',
    ),
    'spatial.touched_update': _normalActionPerSample,
    'runtime.dispose_during_gesture': _ExpectedBenchmarkBoundary(
      timedScope: 'action_only',
      setupScope: 'per_sample_prepared_fixture',
      teardownScope: 'excluded',
      primaryTiming: 'action',
      primaryMemory: 'action',
      fixtureShape: 'active_preview',
    ),
    'diagnostics.disabled_pointer': _ExpectedBenchmarkBoundary(
      timedScope: 'action_only',
      setupScope: 'per_sample_prepared_fixture',
      teardownScope: 'excluded',
      primaryTiming: 'action',
      primaryMemory: 'action',
      fixtureShape: 'hot_pointer',
    ),
  };
  static const _normalActionPerSample = _ExpectedBenchmarkBoundary(
    timedScope: 'action_only',
    setupScope: 'per_sample_prepared_fixture',
    teardownScope: 'excluded',
    primaryTiming: 'action',
    primaryMemory: 'action',
    fixtureShape: 'normal_spread',
  );
  static const _normalActionPerRun = _ExpectedBenchmarkBoundary(
    timedScope: 'action_only',
    setupScope: 'per_run_prepared_fixture',
    teardownScope: 'excluded',
    primaryTiming: 'action',
    primaryMemory: 'action',
    fixtureShape: 'normal_spread',
  );
  static const _resourceAction = _ExpectedBenchmarkBoundary(
    timedScope: 'action_only',
    setupScope: 'per_sample_prepared_fixture',
    teardownScope: 'excluded',
    primaryTiming: 'action',
    primaryMemory: 'action',
    fixtureShape: 'resource_set',
  );

  final YamlMap root;
  final String source;

  BenchmarkManifest parse() {
    _rejectRetiredRootFields();
    final manifestVersion = _manifestVersion();
    final toolSchemaVersion = _toolSchemaVersion();
    final profiles = _profiles();
    final profileIds = profiles.map((profile) => profile.id).toSet();
    final budgetClasses = _budgetClasses();
    final budgetClassIds = budgetClasses.map((budget) => budget.id).toSet();
    final memoryScopes = _memoryScopes();
    final memoryScopeIds = memoryScopes.map((scope) => scope.id).toSet();
    final cases = _cases(
      profileIds: profileIds,
      budgetClassIds: budgetClassIds,
      memoryScopeIds: memoryScopeIds,
    );

    return BenchmarkManifest(
      manifestVersion: manifestVersion,
      toolSchemaVersion: toolSchemaVersion,
      releaseContour: _releaseContour(),
      profiles: profiles,
      budgetClasses: budgetClasses,
      memoryScopes: memoryScopes,
      cases: cases,
      postBaselineRegressionCaps: _numberMap(
        root,
        'post_baseline_regression_caps',
        source,
      ),
      firstBaselineReferenceLimits: _numberMap(
        root,
        'first_baseline_reference_limits',
        source,
      ),
    );
  }

  void _rejectRetiredRootFields() {
    for (final field in const ['bootstrap_legacy_equivalence']) {
      if (root.containsKey(field)) {
        _fail('benchmark manifest uses retired field $field');
      }
    }
  }

  String _manifestVersion() {
    final manifestVersion = _string(root, 'manifest_version', source);
    if (manifestVersion != benchmarkManifestVersion) {
      _fail(
        'manifest_version must be $benchmarkManifestVersion, '
        'found $manifestVersion',
      );
    }
    return manifestVersion;
  }

  int _toolSchemaVersion() {
    final toolSchemaVersion = _int(root, 'tool_schema_version', source);
    if (toolSchemaVersion != benchmarkToolSchemaVersion) {
      _fail(
        'tool_schema_version must be $benchmarkToolSchemaVersion, '
        'found $toolSchemaVersion',
      );
    }
    return toolSchemaVersion;
  }

  BenchmarkReleaseContour _releaseContour() {
    final contour = _map(root, 'release_contour', source);
    final releaseContour = BenchmarkReleaseContour(
      runnerLabel: _string(contour, 'runner_label', 'release_contour'),
      osName: _string(contour, 'os_name', 'release_contour'),
      osVersion: _string(contour, 'os_version', 'release_contour'),
      flutterChannel: _string(contour, 'flutter_channel', 'release_contour'),
      flutterVersion: _string(contour, 'flutter_version', 'release_contour'),
    );
    return releaseContour;
  }

  List<BenchmarkProfile> _profiles() {
    final profiles = <BenchmarkProfile>[];
    final seen = <String>{};

    for (final entry in _mapList(root, 'profiles', source)) {
      final id = _string(entry, 'id', 'profile');
      if (!seen.add(id)) {
        _fail('duplicate profile id $id');
      }
      profiles.add(
        BenchmarkProfile(
          id: id,
          warmups: _int(entry, 'warmups', 'profile $id'),
          repetitions: _int(entry, 'repetitions', 'profile $id'),
          iterations: _optionalInt(entry, 'iterations', 'profile $id'),
          minimumMeasuredMs:
              _optionalInt(entry, 'minimum_measured_ms', 'profile $id') ?? 0,
          minimumSamples:
              _optionalInt(entry, 'minimum_samples', 'profile $id') ?? 0,
          timingClaims: _bool(entry, 'timing_claims', 'profile $id'),
          scaleSelection: _string(entry, 'scale_selection', 'profile $id'),
        ),
      );
    }

    return profiles;
  }

  List<BenchmarkBudgetClass> _budgetClasses() {
    final classes = <BenchmarkBudgetClass>[];
    final seen = <String>{};
    for (final entry in _mapList(root, 'budget_classes', source)) {
      final id = _string(entry, 'id', 'budget class');
      if (!seen.add(id)) {
        _fail('duplicate budget class id $id');
      }
      classes.add(
        BenchmarkBudgetClass(
          id: id,
          absoluteCaps: _objectMap(entry, 'absolute_caps', 'budget class $id'),
        ),
      );
    }
    return classes;
  }

  List<BenchmarkMemoryScope> _memoryScopes() {
    final scopes = <BenchmarkMemoryScope>[];
    final seen = <String>{};
    for (final entry in _mapList(root, 'memory_scopes', source)) {
      final id = _string(entry, 'id', 'memory scope');
      if (!seen.add(id)) {
        _fail('duplicate memory scope id $id');
      }
      final caps = {
        for (final mapEntry in entry.entries)
          if (mapEntry.key != 'id')
            mapEntry.key.toString(): _plainYamlValue(mapEntry.value),
      };
      if (caps.isEmpty) {
        _fail('memory scope $id must declare caps');
      }
      scopes.add(BenchmarkMemoryScope(id: id, caps: caps));
    }
    return scopes;
  }

  // Case parsing validates identity, baselinePolicy, budgets, metrics,
  // invariants, and scales together because they form one manifest row schema.
  // Keeping this row admission together prevents partial manifest acceptance
  // where boundary policy is parsed separately from the case it governs.
  // ignore: cyclomatic-complexity, halstead-volume, maintainability-index, source-lines-of-code
  List<BenchmarkCase> _cases({
    required Set<String> profileIds,
    required Set<String> budgetClassIds,
    required Set<String> memoryScopeIds,
  }) {
    final cases = <BenchmarkCase>[];
    final seen = <String>{};

    for (final entry in _mapList(root, 'cases', source)) {
      final id = _string(entry, 'id', 'benchmark case');
      _rejectRetiredCaseFields(entry, id);
      if (!seen.add(id)) {
        _fail('duplicate benchmark case id $id');
      }
      final baselinePolicy = _string(entry, 'baseline_policy', id);
      if (!_baselinePolicies.contains(baselinePolicy)) {
        _fail('$id has unsupported baselinePolicy $baselinePolicy');
      }
      final budgetClasses = _stringList(entry, 'budget_classes', id);
      if (budgetClasses.isEmpty) {
        _fail('$id must declare budget classes');
      }
      _requireKnownValues(budgetClasses, budgetClassIds, '$id budget_classes');
      final memoryScope = _string(entry, 'memory_scope', id);
      if (!memoryScopeIds.contains(memoryScope)) {
        _fail('$id references unknown memory scope $memoryScope');
      }
      final requiredMetrics = _stringList(entry, 'required_metrics', id);
      if (requiredMetrics.isEmpty) {
        _fail('$id must declare required metrics');
      }
      final exactInvariants = _exactInvariants(entry, id);
      if (exactInvariants.isNotEmpty &&
          !budgetClasses.contains('exact_invariant')) {
        _fail(
          '$id must use exact_invariant when exact invariants are declared',
        );
      }
      for (final invariant in exactInvariants) {
        if (!requiredMetrics.contains(invariant.metric)) {
          _fail('$id exact invariant ${invariant.name} uses unknown metric');
        }
      }
      final measurementBoundary = _measurementBoundary(entry, id);
      final fixtureShape = _fixtureShape(entry, id);
      _validateCaseBoundary(
        id: id,
        boundary: measurementBoundary,
        fixtureShape: fixtureShape,
      );
      final scales = _scales(entry, id, profileIds);
      cases.add(
        BenchmarkCase(
          id: id,
          baselinePolicy: baselinePolicy,
          budgetClasses: budgetClasses,
          memoryScope: memoryScope,
          measurementBoundary: measurementBoundary,
          fixtureShape: fixtureShape,
          docsMetricsLabel: _string(entry, 'docs_metrics_label', id),
          requiredMetrics: requiredMetrics,
          exactInvariants: exactInvariants,
          scales: scales,
        ),
      );
    }
    if (!cases.any(
      (benchmarkCase) =>
          benchmarkCase.id == 'spatial.query_point_dense_stress' &&
          benchmarkCase.fixtureShape == 'dense_stress',
    )) {
      _fail(
        'spatial dense fallback must declare spatial.query_point_dense_stress '
        'with fixture_shape dense_stress',
      );
    }

    return cases;
  }

  void _rejectRetiredCaseFields(YamlMap entry, String id) {
    for (final field in const ['classification']) {
      if (entry.containsKey(field)) {
        _fail('$id uses retired field $field');
      }
    }
  }

  // Measurement boundary parsing keeps every required boundary field in one
  // admission point so missing-field errors cannot drift across helper owners.
  // ignore: source-lines-of-code
  BenchmarkMeasurementBoundary _measurementBoundary(
    YamlMap entry,
    String owner,
  ) {
    final boundary = _map(entry, 'measurement_boundary', owner);
    final setupMetrics = _setupMetrics(boundary, owner);
    final setupMemoryMetrics = _setupMemoryMetrics(boundary, owner);
    final setupScope = _enumString(
      boundary,
      'setup_scope',
      '$owner measurement_boundary',
      _setupScopes,
    );
    _validateSetupDiagnostics(
      owner: owner,
      setupScope: setupScope,
      setupMetrics: setupMetrics,
      setupMemoryMetrics: setupMemoryMetrics,
    );
    return BenchmarkMeasurementBoundary(
      timedScope: _enumString(
        boundary,
        'timed_scope',
        '$owner measurement_boundary',
        _timedScopes,
      ),
      setupScope: setupScope,
      teardownScope: _enumString(
        boundary,
        'teardown_scope',
        '$owner measurement_boundary',
        _teardownScopes,
      ),
      primaryTiming: _enumString(
        boundary,
        'primary_timing',
        '$owner measurement_boundary',
        _primaryTimings,
      ),
      primaryMemory: _enumString(
        boundary,
        'primary_memory',
        '$owner measurement_boundary',
        _primaryMemories,
      ),
      setupMetrics: setupMetrics,
      setupMemoryMetrics: setupMemoryMetrics,
    );
  }

  void _validateSetupDiagnostics({
    required String owner,
    required String setupScope,
    required List<String> setupMetrics,
    required List<String> setupMemoryMetrics,
  }) {
    if (setupScope == 'none') {
      if (setupMetrics.isNotEmpty || setupMemoryMetrics.isNotEmpty) {
        _fail('$owner setup metrics require a prepared fixture setup scope');
      }
    } else if (setupMetrics.isEmpty || setupMemoryMetrics.isEmpty) {
      _fail('$owner prepared fixture setup must declare setup diagnostics');
    }
    if (setupScope != 'none' &&
        (!_hasPrefix(setupMemoryMetrics, 'setup_allocation_bytes') ||
            !_hasPrefix(setupMemoryMetrics, 'setup_rss_delta_bytes'))) {
      _fail(
        '$owner prepared fixture setup must declare setup allocation and '
        'setup RSS diagnostics',
      );
    }
  }

  List<String> _setupMetrics(YamlMap boundary, String owner) {
    final setupMetrics = _stringList(
      boundary,
      'setup_metrics',
      '$owner measurement_boundary',
    );
    _validateMetricPrefixes(
      values: setupMetrics,
      prefixes: const ['setup_us'],
      owner: '$owner measurement_boundary.setup_metrics',
    );
    return setupMetrics;
  }

  List<String> _setupMemoryMetrics(YamlMap boundary, String owner) {
    final setupMemoryMetrics = _stringList(
      boundary,
      'setup_memory_metrics',
      '$owner measurement_boundary',
    );
    _validateMetricPrefixes(
      values: setupMemoryMetrics,
      prefixes: const ['setup_allocation_bytes', 'setup_rss_delta_bytes'],
      owner: '$owner measurement_boundary.setup_memory_metrics',
    );
    return setupMemoryMetrics;
  }

  String _fixtureShape(YamlMap entry, String owner) {
    return _enumString(entry, 'fixture_shape', owner, _fixtureShapes);
  }

  void _validateCaseBoundary({
    required String id,
    required BenchmarkMeasurementBoundary boundary,
    required String fixtureShape,
  }) {
    final expected = _selectedBoundaryTable[id];
    if (expected == null) {
      _fail('$id has no selected measurement boundary policy');
    }
    if (boundary.timedScope != expected.timedScope ||
        boundary.setupScope != expected.setupScope ||
        boundary.teardownScope != expected.teardownScope ||
        boundary.primaryTiming != expected.primaryTiming ||
        boundary.primaryMemory != expected.primaryMemory ||
        fixtureShape != expected.fixtureShape) {
      _fail('$id measurement boundary must match the selected boundary table');
    }
  }

  String _enumString(
    YamlMap map,
    String field,
    String owner,
    Set<String> allowed,
  ) {
    final value = _string(map, field, owner);
    if (!allowed.contains(value)) {
      _fail('$owner field $field has unsupported value $value');
    }
    return value;
  }

  void _validateMetricPrefixes({
    required List<String> values,
    required List<String> prefixes,
    required String owner,
  }) {
    for (final value in values) {
      if (!prefixes.any((prefix) => value.startsWith(prefix))) {
        _fail('$owner contains unsupported metric $value');
      }
    }
  }

  bool _hasPrefix(List<String> values, String prefix) {
    return values.any((value) => value.startsWith(prefix));
  }

  List<BenchmarkExactInvariant> _exactInvariants(YamlMap entry, String owner) {
    final invariants = <BenchmarkExactInvariant>[];
    final seen = <String>{};
    for (final invariant in _mapList(entry, 'exact_invariants', owner)) {
      final name = _string(invariant, 'name', '$owner exact invariant');
      final metric = _string(
        invariant,
        'metric',
        '$owner exact invariant $name',
      );
      if (!seen.add(name)) {
        _fail('$owner has duplicate exact invariant $name');
      }
      invariants.add(
        BenchmarkExactInvariant(
          name: name,
          metric: metric,
          expected: invariant['expected'],
          max: _optionalNumber(
            invariant,
            'max',
            '$owner exact invariant $name',
          ),
        ),
      );
    }
    return invariants;
  }

  // Scale parsing owns profile membership and smoke coverage as one row-level
  // gate so malformed benchmark scales fail before runner selection.
  // ignore: halstead-volume
  List<BenchmarkScale> _scales(
    YamlMap entry,
    String owner,
    Set<String> profileIds,
  ) {
    final scales = <BenchmarkScale>[];
    final seen = <String>{};
    var smokeScaleCount = 0;
    for (final scale in _mapList(entry, 'scales', owner)) {
      final id = _string(scale, 'id', '$owner scale');
      if (!seen.add(id)) {
        _fail('$owner has duplicate scale $id');
      }
      final profiles = _stringList(scale, 'profiles', '$owner scale $id');
      _requireKnownValues(profiles, profileIds, '$owner scale $id profiles');
      if (!profiles.contains('dry_run')) {
        _fail('$owner scale $id must belong to dry_run');
      }
      if (!profiles.contains('release')) {
        _fail('$owner scale $id must belong to release');
      }
      if (profiles.contains('smoke')) {
        smokeScaleCount++;
      }
      scales.add(
        BenchmarkScale(
          id: id,
          label: _string(scale, 'label', '$owner scale $id'),
          profiles: profiles,
        ),
      );
    }
    if (scales.isEmpty) {
      _fail('$owner must declare scales');
    }
    if (smokeScaleCount == 0) {
      _fail('$owner must have at least one smoke scale');
    }
    return scales;
  }

  Never _fail(String message) {
    throw FormatException('$source: $message');
  }

  void _requireKnownValues(
    List<String> actual,
    Set<String> expected,
    String owner,
  ) {
    for (final value in actual) {
      if (!expected.contains(value)) {
        _fail('$owner references unknown value $value');
      }
    }
  }
}

String _string(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$owner must have non-empty string field $field');
}

int _int(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is int) {
    return value;
  }
  throw FormatException('$owner must have integer field $field');
}

int? _optionalInt(YamlMap map, String field, String owner) {
  if (!map.containsKey(field)) {
    return null;
  }
  return _int(map, field, owner);
}

num? _optionalNumber(YamlMap map, String field, String owner) {
  if (!map.containsKey(field)) {
    return null;
  }
  final value = map[field];
  if (value is num) {
    return value;
  }
  throw FormatException('$owner must have number field $field');
}

bool _bool(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is bool) {
    return value;
  }
  throw FormatException('$owner must have boolean field $field');
}

List<String> _stringList(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is! YamlList) {
    throw FormatException('$owner must have list field $field');
  }
  final items = <String>[];
  final seen = <String>{};
  for (final item in value) {
    if (item is! String || item.isEmpty) {
      throw FormatException('$owner field $field must contain strings');
    }
    if (!seen.add(item)) {
      throw FormatException('$owner field $field contains duplicate $item');
    }
    items.add(item);
  }
  return items;
}

List<YamlMap> _mapList(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is! YamlList) {
    throw FormatException('$owner must have list field $field');
  }
  final items = <YamlMap>[];
  for (final item in value) {
    if (item is! YamlMap) {
      throw FormatException('$owner field $field must contain maps');
    }
    items.add(item);
  }
  return items;
}

YamlMap _map(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is YamlMap) {
    return value;
  }
  throw FormatException('$owner must have map field $field');
}

Map<String, Object?> _objectMap(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is! YamlMap) {
    throw FormatException('$owner must have map field $field');
  }
  return {
    for (final entry in value.entries)
      entry.key.toString(): _plainYamlValue(entry.value),
  };
}

Map<String, num> _numberMap(YamlMap map, String field, String owner) {
  final raw = _objectMap(map, field, owner);
  final values = <String, num>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! num) {
      throw FormatException(
        '$owner field $field.${entry.key} must be a number',
      );
    }
    values[entry.key] = value;
  }
  return values;
}

Object? _plainYamlValue(Object? value) {
  return switch (value) {
    YamlMap() => {
      for (final entry in value.entries)
        entry.key.toString(): _plainYamlValue(entry.value),
    },
    YamlList() => [for (final item in value) _plainYamlValue(item)],
    _ => value,
  };
}
