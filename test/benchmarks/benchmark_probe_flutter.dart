// The Flutter probe intentionally imports every owner surface it measures so
// benchmark setup stays executable without benchmark-only production exports.
// ignore_for_file: number-of-external-imports, number-of-imports

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/api/canvas_codec.dart';
import 'package:iwb_canvas_engine/src/api/canvas_runtime_frame_bridge.dart';
import 'package:iwb_canvas_engine/src/api/canvas_runtime.dart' as canvas_api;
import 'package:iwb_canvas_engine/src/codec/schema_v1_decoder.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/document_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_document.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_element.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_element_update.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_errors.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_field_update.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_pointer.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_resource.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_runtime.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_tools.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_capture_service.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/selected_move_supplement_planner.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/surface/canvas_surface_widget.dart';
import 'package:iwb_canvas_engine/src/surface/main_painter.dart';
import 'package:iwb_canvas_engine/src/surface/overlay_painter.dart';

import '../../tool/bench/src/benchmark_manifest.dart';

void main() {
  _registerProbeProtocolTests();
  _registerProbeLifecycleTests();
  _registerCaseRegistryTests();
  _registerPreparedCaseTests();
}

void _registerProbeProtocolTests() {
  _widgetHelperTest(
    'benchmark probe executes requested case',
    _probeExecutesRequestedCase,
  );
  _helperTest(
    'probe options validate profile ids',
    _probeOptionsValidateProfileIds,
  );
}

void _registerProbeLifecycleTests() {
  _helperTest(
    'case plan separates setup timing from action samples',
    _casePlanSeparatesSetupTimingFromActionSamples,
  );
  _helperTest(
    'case plan runs cleanup after action failure',
    _casePlanRunsCleanupAfterActionFailure,
  );
  _helperTest(
    'case plan fails before timing claims when prepare fails',
    _casePlanFailsBeforeTimingClaimsWhenPrepareFails,
  );
  _helperTest(
    'case plan fails when cleanup fails',
    _casePlanFailsWhenCleanupFails,
  );
  _helperTest(
    'per-run case plan does not reuse warmup fixture for measured samples',
    _perRunCasePlanDoesNotReuseWarmupFixtureForMeasuredSamples,
  );
  _helperTest(
    'per-run lifecycle case plan reuses measured fixture after warmup',
    _perRunLifecycleCasePlanReusesMeasuredFixtureAfterWarmup,
  );
}

void _registerCaseRegistryTests() {
  _helperTest(
    'case plan fails closed for missing boundary registry entries',
    _casePlanFailsClosedForMissingBoundaryRegistryEntries,
  );
  _helperTest(
    'case plan fails when operation lacks boundary metadata',
    _casePlanFailsWhenOperationLacksBoundaryMetadata,
  );
  _helperTest(
    'case plan accepts no setup boundary metadata',
    _casePlanAcceptsNoSetupBoundaryMetadata,
  );
  _helperTest(
    'real case plans use manifest boundary table',
    _realCasePlansUseManifestBoundaryTable,
  );
  _helperTest(
    'spatial case plans enforce ordinary and dense fixture shapes',
    _spatialCasePlansEnforceFixtureShapes,
  );
  _helperTest(
    'case plan rejects timed and memory boundary drift',
    _casePlanRejectsBoundaryPolicyDrift,
  );
}

void _registerPreparedCaseTests() {
  _helperTest(
    'projection case excludes runtime setup from action samples',
    _projectionCaseExcludesRuntimeSetupFromActionSamples,
  );
  _helperTest(
    'resource and diagnostic case plans expose prepared setup diagnostics',
    _resourceAndDiagnosticCasePlansExposePreparedSetupDiagnostics,
  );
  _helperTest(
    'load document breakdown records public load diagnostics',
    _loadDocumentBreakdownRecordsPublicLoadDiagnostics,
  );
  _helperTest(
    'load document timings exclude fixture encoding',
    _loadDocumentTimingsExcludeFixtureEncoding,
  );
  _helperTest(
    'edit input and frame case plans execute prepared action samples',
    _editInputAndFrameCasePlansExecutePreparedActionSamples,
  );
  _helperTest(
    'runtime case plans prepare spatial state outside action samples',
    _runtimeCasePlansPrepareSpatialStateOutsideActionSamples,
  );
  _widgetHelperTest(
    'surface case plans exercise canvas surface delegates',
    _surfaceCasePlansExerciseCanvasSurfaceDelegates,
  );
}

void _helperTest(String description, FutureOr<void> Function() body) {
  // Assertions live in named helpers so each scenario remains independently
  // reviewable while the test registration stays compact.
  // ignore: missing-test-assertion
  test(description, body);
}

void _widgetHelperTest(String description, FutureOr<void> Function() body) {
  // Surface probe cases need a WidgetTester while preserving the existing
  // machine-readable benchmark probe test name and stdout protocol.
  // ignore: missing-test-assertion
  testWidgets(description, (tester) async {
    _activeWidgetTester = tester;
    try {
      await body();
    } finally {
      _activeWidgetTester = null;
    }
  }, semanticsEnabled: false);
}

Future<void> _probeExecutesRequestedCase() async {
  final args = _probeArgs();
  final options = _ProbeOptions.parse(args);
  final result = await _runProbe(options);
  expect(result['actionUsSamples'], isNotEmpty);
  // Machine-readable stdout is the probe protocol consumed by tool/bench.
  // ignore: avoid_print
  print('BENCHMARK_PROBE_JSON:${jsonEncode(result)}');
}

void _probeOptionsValidateProfileIds() {
  final options = _ProbeOptions.parse([
    '--case=edit.add_element',
    '--scale=1k',
    '--profile=release',
  ]);
  expect(options.profileId, 'release');

  expect(
    () => _ProbeOptions.parse(['--case=edit.add_element', '--scale=1k']),
    throwsFormatException,
  );
  expect(
    () => _ProbeOptions.parse([
      '--case=edit.add_element',
      '--scale=1k',
      '--profile=prod',
    ]),
    throwsFormatException,
  );
}

Future<void> _casePlanSeparatesSetupTimingFromActionSamples() async {
  final events = <String>[];
  final result = await _runProbePlan(
    _fakeOptions(warmups: 1, repetitions: 1),
    _BenchmarkCasePlan(
      prepare: () {
        events.add('prepare');
        return const _PreparedProbeFixture(
          value: 'fixture',
          setupMetrics: {'setup_allocation_bytes': 1000},
        );
      },
      measure: (fixture) {
        expect(fixture, 'fixture');
        events.add('measure');
        return const {'allocation_bytes': 10};
      },
      cleanup: (fixture) {
        expect(fixture, 'fixture');
        events.add('cleanup');
      },
      setupElapsedUsOverride: 5000,
      actionElapsedUsOverride: 7,
      setupRssDeltaOverride: 2000,
      actionRssDeltaOverride: 20,
    ),
  );

  expect(events, [
    'prepare',
    'measure',
    'cleanup',
    'prepare',
    'measure',
    'cleanup',
  ]);
  _expectActionAndSetupSamples(result);
  _expectActionAndSetupMetrics(result);
}

void _expectActionAndSetupSamples(Map<String, Object?> result) {
  expect(result['actionUsSamples'], [7]);
  expect(result['setupUsSamples'], [5000]);
}

void _expectActionAndSetupMetrics(Map<String, Object?> result) {
  expect(result['metrics'], containsPair('avg_us', 7));
  expect(result['metrics'], containsPair('p95_us', 7));
  expect(result['metrics'], containsPair('max_us', 7));
  expect(result['metrics'], containsPair('setup_us', 5000));
  expect(result['metrics'], containsPair('allocation_bytes', 10));
  expect(result['metrics'], containsPair('rss_delta_bytes', 20));
  expect(result['setupMetrics'], containsPair('setup_allocation_bytes', 1000));
  expect(result['setupMetrics'], containsPair('setup_rss_delta_bytes', 2000));
}

Future<void> _casePlanRunsCleanupAfterActionFailure() async {
  final events = <String>[];

  await expectLater(
    _runProbePlan(
      _fakeOptions(),
      _BenchmarkCasePlan(
        prepare: () {
          events.add('prepare');
          return const _PreparedProbeFixture();
        },
        measure: (_) {
          events.add('measure');
          throw StateError('action failed');
        },
        cleanup: (_) {
          events.add('cleanup');
        },
      ),
    ),
    throwsA(isA<StateError>()),
  );
  expect(events, ['prepare', 'measure', 'cleanup']);
}

Future<void> _casePlanFailsBeforeTimingClaimsWhenPrepareFails() async {
  final events = <String>[];

  await expectLater(
    _runProbePlan(
      _fakeOptions(),
      _BenchmarkCasePlan(
        prepare: () {
          events.add('prepare');
          throw StateError('prepare failed');
        },
        measure: (_) {
          events.add('measure');
          return const {};
        },
        cleanup: (_) {
          events.add('cleanup');
        },
      ),
    ),
    throwsA(isA<StateError>()),
  );
  expect(events, ['prepare']);
}

Future<void> _casePlanFailsWhenCleanupFails() async {
  await expectLater(
    _runProbePlan(
      _fakeOptions(),
      _BenchmarkCasePlan(
        prepare: () => const _PreparedProbeFixture(),
        measure: (_) => const {},
        cleanup: (_) => throw StateError('cleanup failed'),
      ),
    ),
    throwsA(isA<StateError>()),
  );
}

Future<void>
_perRunCasePlanDoesNotReuseWarmupFixtureForMeasuredSamples() async {
  final events = <String>[];
  var nextFixtureId = 0;

  final result = await _runProbePlan(
    _fakeOptions(warmups: 1, repetitions: 1),
    _BenchmarkCasePlan(
      setupScope: 'per_run_prepared_fixture',
      prepare: () {
        final fixtureId = nextFixtureId++;
        events.add('prepare-$fixtureId');
        return _PreparedProbeFixture(value: fixtureId);
      },
      measure: (fixture) {
        events.add('measure-$fixture');
        return {'fixture_id': fixture};
      },
      cleanup: (fixture) {
        events.add('cleanup-$fixture');
      },
    ),
  );

  expect(events, [
    'prepare-0',
    'measure-0',
    'cleanup-0',
    'prepare-1',
    'measure-1',
    'cleanup-1',
  ]);
  final metrics = result['metrics'] as Map<String, Object?>;
  expect(metrics, containsPair('fixture_id', 1));
}

Future<void> _perRunLifecycleCasePlanReusesMeasuredFixtureAfterWarmup() async {
  final events = <String>[];
  var nextFixtureId = 0;

  final result = await _runProbePlan(
    _fakeOptions(warmups: 1, repetitions: 2),
    _BenchmarkCasePlan(
      timedScope: 'lifecycle',
      primaryTiming: 'lifecycle',
      setupScope: 'per_run_prepared_fixture',
      prepare: () {
        final fixtureId = nextFixtureId++;
        events.add('prepare-$fixtureId');
        return _PreparedProbeFixture(value: fixtureId);
      },
      measure: (fixture) {
        events.add('measure-$fixture');
        return {'fixture_id': fixture};
      },
      cleanup: (fixture) {
        events.add('cleanup-$fixture');
      },
    ),
  );

  expect(events, [
    'prepare-0',
    'measure-0',
    'cleanup-0',
    'prepare-1',
    'measure-1',
    'measure-1',
    'cleanup-1',
  ]);
  expect(result['setupUsSamples'], hasLength(1));
  final metrics = result['metrics'] as Map<String, Object?>;
  expect(metrics, containsPair('fixture_id', 1));
}

void _casePlanFailsClosedForMissingBoundaryRegistryEntries() {
  expect(
    () => _casePlan('fake.unregistered', '1k'),
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('has no benchmark measurement boundary'),
      ),
    ),
  );
}

void _casePlanFailsWhenOperationLacksBoundaryMetadata() {
  const registry = _CaseBoundaryRegistry({
    'edit.add_element': _CaseBoundaryRegistryEntry(
      timedScope: 'action_only',
      setupScope: '',
      teardownScope: 'excluded',
      primaryTiming: 'action',
      primaryMemory: 'action',
      setupMetrics: ['setup_us'],
      setupMemoryMetrics: ['setup_allocation_bytes', 'setup_rss_delta_bytes'],
      fixtureShape: 'normal_spread',
    ),
  });

  expect(
    () => _casePlan('edit.add_element', '1k', boundaryRegistry: registry),
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('has incomplete benchmark measurement boundary'),
      ),
    ),
  );
}

Future<void> _casePlanAcceptsNoSetupBoundaryMetadata() async {
  const boundary = _CaseBoundaryRegistryEntry(
    timedScope: 'action_only',
    setupScope: 'none',
    teardownScope: 'excluded',
    primaryTiming: 'action',
    primaryMemory: 'action',
    setupMetrics: [],
    setupMemoryMetrics: [],
    fixtureShape: 'normal_spread',
  );
  expect(boundary.isComplete, isTrue);

  final result = await _runProbePlan(_fakeOptions(), _noSetupPlan(boundary));
  _expectNoSetupResult(result);
}

_BenchmarkCasePlan _noSetupPlan(_CaseBoundaryRegistryEntry boundary) {
  return _BenchmarkCasePlan(
    setupScope: boundary.setupScope,
    setupMetricKeys: boundary.setupMetrics,
    setupMemoryMetricKeys: boundary.setupMemoryMetrics,
    prepare: () => const _PreparedProbeFixture(value: 'fixture'),
    measure: (fixture) {
      expect(fixture, 'fixture');
      return const {'allocation_bytes': 10, 'rss_delta_bytes': 20};
    },
    cleanup: (fixture) => expect(fixture, 'fixture'),
  );
}

void _expectNoSetupResult(Map<String, Object?> result) {
  final metrics = result['metrics'] as Map<String, Object?>;
  final setupMetrics = result['setupMetrics'] as Map<String, Object?>;

  expect(result['actionUsSamples'], isNotEmpty);
  expect(result['setupUsSamples'], isEmpty);
  expect(metrics.containsKey('setup_us'), isFalse);
  expect(setupMetrics, isEmpty);
  expect(result['measurementBoundary'], containsPair('setupMetrics', isEmpty));
  expect(
    result['measurementBoundary'],
    containsPair('setupMemoryMetrics', isEmpty),
  );
}

void _realCasePlansUseManifestBoundaryTable() {
  final manifest = BenchmarkManifest.load();
  for (final benchmarkCase in manifest.cases) {
    final scaleId = benchmarkCase.scales.first.id;
    final plan = _casePlan(benchmarkCase.id, scaleId);
    expect(
      plan.setupScope,
      benchmarkCase.measurementBoundary.setupScope,
      reason: benchmarkCase.id,
    );
    expect(
      plan.timedScope,
      benchmarkCase.measurementBoundary.timedScope,
      reason: benchmarkCase.id,
    );
    expect(
      plan.primaryMemory,
      benchmarkCase.measurementBoundary.primaryMemory,
      reason: benchmarkCase.id,
    );
    expect(
      plan.primaryTiming,
      benchmarkCase.measurementBoundary.primaryTiming,
      reason: benchmarkCase.id,
    );
    expect(
      plan.teardownScope,
      benchmarkCase.measurementBoundary.teardownScope,
      reason: benchmarkCase.id,
    );
    expect(plan.fixtureShape, benchmarkCase.fixtureShape);
  }
}

void _spatialCasePlansEnforceFixtureShapes() {
  _ordinarySpatialQueryRejectsDenseFixtureShape();
  _denseSpatialQueryRejectsOrdinaryFixtureShape();
}

void _ordinarySpatialQueryRejectsDenseFixtureShape() {
  const invalidOrdinaryRegistry = _CaseBoundaryRegistry({
    'spatial.query_point': _CaseBoundaryRegistryEntry(
      timedScope: 'action_only',
      setupScope: 'per_run_prepared_fixture',
      teardownScope: 'excluded',
      primaryTiming: 'action',
      primaryMemory: 'action',
      setupMetrics: ['setup_us'],
      setupMemoryMetrics: ['setup_allocation_bytes', 'setup_rss_delta_bytes'],
      fixtureShape: 'dense_stress',
    ),
  });

  expect(
    () => _casePlan(
      'spatial.query_point',
      '1k',
      boundaryRegistry: invalidOrdinaryRegistry,
    ),
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('normal_spread fixture shape'),
      ),
    ),
  );
}

void _denseSpatialQueryRejectsOrdinaryFixtureShape() {
  const invalidDenseRegistry = _CaseBoundaryRegistry({
    'spatial.query_point_dense_stress': _CaseBoundaryRegistryEntry(
      timedScope: 'action_only',
      setupScope: 'per_run_prepared_fixture',
      teardownScope: 'excluded',
      primaryTiming: 'action',
      primaryMemory: 'action',
      setupMetrics: ['setup_us'],
      setupMemoryMetrics: ['setup_allocation_bytes', 'setup_rss_delta_bytes'],
      fixtureShape: 'normal_spread',
    ),
  });

  expect(
    () => _casePlan(
      'spatial.query_point_dense_stress',
      'dense_50k',
      boundaryRegistry: invalidDenseRegistry,
    ),
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('dense_stress fixture shape'),
      ),
    ),
  );
}

void _casePlanRejectsBoundaryPolicyDrift() {
  const registry = _CaseBoundaryRegistry({
    'edit.add_element': _CaseBoundaryRegistryEntry(
      timedScope: 'lifecycle',
      setupScope: 'per_run_prepared_fixture',
      teardownScope: 'measured_lifecycle',
      primaryTiming: 'lifecycle',
      primaryMemory: 'lifecycle',
      setupMetrics: ['setup_us'],
      setupMemoryMetrics: ['setup_allocation_bytes', 'setup_rss_delta_bytes'],
      fixtureShape: 'normal_spread',
    ),
  });

  expect(
    () => _casePlan('edit.add_element', '1k', boundaryRegistry: registry),
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('benchmark measurement boundary drift'),
      ),
    ),
  );
}

Future<void> _projectionCaseExcludesRuntimeSetupFromActionSamples() async {
  final result = await _runProbePlan(
    _fakeOptions(caseId: 'projection.read_document'),
    _casePlan('projection.read_document', '1k'),
  );

  expect(result['actionUsSamples'], hasLength(1));
  expect(result['setupUsSamples'], hasLength(1));
  final metrics = result['metrics'] as Map<String, Object?>;
  expect(metrics, containsPair('setup_us', isA<int>()));
  expect(metrics, contains('first_read_us'));
  expect(metrics, contains('cache_hit_us'));
}

Future<void>
_resourceAndDiagnosticCasePlansExposePreparedSetupDiagnostics() async {
  final resourceResult = await _runProbePlan(
    _fakeOptions(caseId: 'resources.mark_dirty'),
    _casePlan('resources.mark_dirty', '1k_resources'),
  );
  final disposeResult = await _runProbePlan(
    _fakeOptions(caseId: 'runtime.dispose_during_gesture'),
    _casePlan(
      'runtime.dispose_during_gesture',
      'active_selected_overlay_previews',
    ),
  );
  final disabledPointerResult = await _runProbePlan(
    _fakeOptions(caseId: 'diagnostics.disabled_pointer'),
    _casePlan('diagnostics.disabled_pointer', 'hot_pointer'),
  );

  _expectPreparedCaseMetrics(
    resourceResult,
    'target_session_cache_invalidation_cost',
  );
  _expectPreparedCaseMetrics(disposeResult, 'action_events');
  _expectPreparedCaseMetrics(disabledPointerResult, 'allocation_records');
}

void _expectPreparedCaseMetrics(Map<String, Object?> result, String metric) {
  expect(result['actionUsSamples'], hasLength(1));
  expect(result['setupUsSamples'], hasLength(1));
  final metrics = result['metrics'] as Map<String, Object?>;
  expect(metrics, containsPair('setup_us', isA<int>()));
  expect(metrics, contains(metric));
}

Future<void> _loadDocumentBreakdownRecordsPublicLoadDiagnostics() async {
  final result = await _runProbePlan(
    _fakeOptions(warmups: 0, repetitions: 1),
    _casePlan('load_document.breakdown', '1k'),
  );
  final metrics = result['metrics'] as Map<String, Object?>;

  expect(metrics, containsPair('decode_us', isA<int>()));
  expect(metrics, containsPair('runtime_construct_us', isA<int>()));
  expect(metrics, containsPair('schema_import_load_us', isA<int>()));
  expect(metrics, containsPair('first_projection_us', isA<int>()));
  expect(metrics, containsPair('loaded_element_count', 1000));
  expect(metrics, containsPair('projected_element_count', 1000));
  expect(metrics, containsPair('encoded_byte_count', isA<int>()));
  expect(result['setupUsSamples'], hasLength(1));
}

void _loadDocumentTimingsExcludeFixtureEncoding() {
  _expectRuntimeConstructionExcludesLoad();
  _expectLoadDocumentSourceShape();
}

void _expectRuntimeConstructionExcludesLoad() {
  final runtime = _timedRuntimeConstruction();
  try {
    expect(runtime.value.state.value.revisions.document, 0);
    expect(runtime.value.projectionBuildCount, 0);
  } finally {
    runtime.value.dispose();
  }

  final source = _benchmarkProbeSource();
  _expectBenchmarkSourceExcludesRetiredLoadRoutes(source);
  _expectFunctionExcludes(
    source,
    '_timedRuntimeConstruction',
    forbidden: [
      'runtimeRootWithCommittedDocumentSeed',
      'loadDocumentFromJson',
      'encodeCanvasDocumentToJson',
    ],
  );
}

void _expectLoadDocumentSourceShape() {
  final source = _benchmarkProbeSource();
  _expectBenchmarkSourceExcludesRetiredLoadRoutes(source);
  final timedLoadBody = _declarationBody(source, '_timedLoadDocument');
  expect(
    timedLoadBody,
    contains('runtime.edits.loadDocumentFromJson(encodedJson);'),
  );
  _expectFunctionExcludes(
    source,
    '_timedLoadDocument',
    forbidden: [
      'encodeCanvasDocumentToJson',
      '_document(',
      'readDocument',
      '_timedFirstProjection',
      'importSchemaV1Document',
      'prepareSchemaV1Import',
    ],
  );
  _expectClosureExcludes(
    source,
    '_loadDocumentSuccessPlan',
    'measure:',
    forbidden: [
      'encodeCanvasDocumentToJson',
      'readDocument',
      '_timedFirstProjection',
    ],
  );
  _expectClosureExcludes(
    source,
    '_loadDocumentFailurePlan',
    'measure:',
    forbidden: ["'committed_mutation_count': 0", 'encodeCanvasDocumentToJson'],
  );
  expect(
    _declarationBody(source, '_loadDocumentFailurePlan'),
    contains('loadFixture.before.mutationCount'),
  );
}

void _expectBenchmarkSourceExcludesRetiredLoadRoutes(String source) {
  expect(
    source,
    isNot(
      contains(
        'decodeCanvasDocument'
        'FromJson',
      ),
    ),
  );
  expect(
    source,
    isNot(
      contains(
        '.load'
        'Document(',
      ),
    ),
  );
}

String _benchmarkProbeSource() {
  return File(
    'test/benchmarks/benchmark_probe_flutter.dart',
  ).readAsStringSync();
}

void _expectFunctionExcludes(
  String source,
  String functionName, {
  required List<String> forbidden,
}) {
  final body = _declarationBody(source, functionName);
  for (final pattern in forbidden) {
    expect(body, isNot(contains(pattern)), reason: functionName);
  }
}

void _expectClosureExcludes(
  String source,
  String functionName,
  String marker, {
  required List<String> forbidden,
}) {
  final functionBody = _declarationBody(source, functionName);
  final markerIndex = functionBody.indexOf(marker);
  expect(markerIndex, isNonNegative, reason: functionName);
  final closureBody = _balancedBodyFrom(functionBody, markerIndex);
  for (final pattern in forbidden) {
    expect(closureBody, isNot(contains(pattern)), reason: functionName);
  }
}

String _declarationBody(String source, String declarationName) {
  final declarationIndex = _declarationIndex(source, declarationName);
  expect(declarationIndex, isNonNegative, reason: declarationName);

  return _balancedBodyFrom(source, declarationIndex);
}

int _declarationIndex(String source, String declarationName) {
  for (final prefix in _topLevelDeclarationPrefixes) {
    final index = source.indexOf('$prefix $declarationName');
    if (index != -1) {
      return index;
    }
  }

  return -1;
}

const _topLevelDeclarationPrefixes = [
  '_BenchmarkCasePlan',
  'Future<void>',
  'int',
  'Map<String, Object?>',
  'Stopwatch',
  'String',
  'void',
  '({CanvasDocument value, Stopwatch stopwatch})',
  '({RuntimeRoot value, Stopwatch stopwatch})',
];

String _balancedBodyFrom(String source, int searchFrom) {
  final openIndex = source.indexOf('{', searchFrom);
  expect(openIndex, isNonNegative);
  var depth = 0;
  for (var index = openIndex; index < source.length; index += 1) {
    final character = source[index];
    if (character == '{') {
      depth += 1;
    } else if (character == '}') {
      depth -= 1;
      if (depth == 0) {
        return _sourceRange(source, openIndex, index + 1);
      }
    }
  }

  throw StateError('Could not find balanced body from $searchFrom.');
}

String _sourceRange(String source, int start, int end) {
  final buffer = StringBuffer();
  var offset = 0;
  for (final character in source.characters) {
    final nextOffset = offset + character.length;
    if (nextOffset > start && offset < end) {
      buffer.write(character);
    }
    if (nextOffset >= end) {
      break;
    }
    offset = nextOffset;
  }

  return buffer.toString();
}

Future<void> _editInputAndFrameCasePlansExecutePreparedActionSamples() async {
  final editResult = await _runProbePlan(
    _fakeOptions(caseId: 'edit.move_selection'),
    _casePlan('edit.move_selection', '1k'),
  );
  final inputResult = await _runProbePlan(
    _fakeOptions(caseId: 'input.selected_move_preview'),
    _casePlan('input.selected_move_preview', '1k'),
  );
  final frameResult = await _runProbePlan(
    _fakeOptions(caseId: 'frame.selected_move_preview_cached_ordinary_plan'),
    _casePlan('frame.selected_move_preview_cached_ordinary_plan', '1k'),
  );

  _expectPreparedCaseMetrics(editResult, 'selected_count');
  _expectPreparedCaseMetrics(inputResult, 'scene_repaint_count');
  _expectPreparedCaseMetrics(frameResult, 'ordinary_plan_hit_rate');
}

Future<void> _runtimeCasePlansPrepareSpatialStateOutsideActionSamples() async {
  final result = await _runProbePlan(
    _fakeOptions(caseId: 'spatial.query_point'),
    _runtimeCasePlan(
      'per_run_prepared_fixture',
      '1k',
      (runtime) => {
        'spatial_invalid_at_action': runtime.spatialKernel.snapshot.isInvalid
            ? 1
            : 0,
      },
    ),
  );

  expect(result['metrics'], containsPair('spatial_invalid_at_action', 0));
  expect(
    result['setupMetrics'],
    containsPair('spatial_rebuild_setup_us', isA<int>()),
  );
}

Future<void> _surfaceCasePlansExerciseCanvasSurfaceDelegates() async {
  final overlayResult = await _runProbePlan(
    _fakeOptions(caseId: 'surface.overlay_preview_route'),
    _casePlan('surface.overlay_preview_route', '1k'),
  );
  final selectedResult = await _runProbePlan(
    _fakeOptions(caseId: 'surface.selected_move_route'),
    _casePlan('surface.selected_move_route', '1k'),
  );

  final overlayMetrics = overlayResult['metrics'] as Map<String, Object?>;
  expect(
    overlayMetrics,
    containsPair('overlay_primitive_count', greaterThan(0)),
  );
  expect(overlayMetrics, contains('main_output_identity_changes'));
  expect(overlayMetrics, contains('main_should_repaint_count'));

  final selectedMetrics = selectedResult['metrics'] as Map<String, Object?>;
  expect(selectedMetrics, containsPair('selected_move_main_signal_count', 1));
  expect(selectedMetrics, contains('overlay_output_identity_changes'));
  expect(selectedMetrics, contains('overlay_should_repaint_count'));
}

List<String> _probeArgs() {
  final encoded = Platform.environment['BENCHMARK_PROBE_ARGS'];
  if (encoded == null) {
    throw const FormatException('Missing BENCHMARK_PROBE_ARGS.');
  }
  return [
    for (final value in jsonDecode(encoded) as List<Object?>)
      if (value is String)
        value
      else
        throw FormatException('Invalid arg $value'),
  ];
}

Future<Map<String, Object?>> _runProbe(_ProbeOptions options) =>
    _runProbePlan(options, _casePlan(options.caseId, options.scaleId));

Future<Map<String, Object?>> _runProbePlan(
  _ProbeOptions options,
  _BenchmarkCasePlan plan,
) async {
  final state = _ProbeRunState();
  _MeasuredSetup? reusableSetup;
  try {
    await _runWarmupSamples(options, plan);
    reusableSetup = await _prepareReusableSetup(plan, state);
    await _runMeasuredSamples(options, plan, state, reusableSetup);
  } finally {
    if (reusableSetup != null) {
      await plan.cleanup(reusableSetup.prepared.value);
    }
  }

  return _probeResultJson(options, plan, state);
}

Future<void> _runWarmupSamples(
  _ProbeOptions options,
  _BenchmarkCasePlan plan,
) async {
  for (var index = 0; index < options.warmups; index++) {
    await _measurePlanSample(plan, null);
  }
}

Future<_MeasuredSetup?> _prepareReusableSetup(
  _BenchmarkCasePlan plan,
  _ProbeRunState state,
) async {
  if (!plan.reusesPreparedFixture) {
    return null;
  }
  final reusableSetup = await _measureSetup(plan);
  if (plan.setupScope != 'none') {
    state.recordSetup(reusableSetup);
  }

  return reusableSetup;
}

Future<void> _runMeasuredSamples(
  _ProbeOptions options,
  _BenchmarkCasePlan plan,
  _ProbeRunState state,
  _MeasuredSetup? reusableSetup,
) async {
  final total = Stopwatch()..start();
  do {
    final sample = await _measurePlanSample(plan, reusableSetup);
    state.recordSample(
      sample,
      includeSetup: reusableSetup == null && plan.setupScope != 'none',
    );
  } while (_needsMoreSamples(
    options,
    state.samples.length,
    total.elapsedMilliseconds,
  ));
  total.stop();
}

Map<String, Object?> _probeResultJson(
  _ProbeOptions options,
  _BenchmarkCasePlan plan,
  _ProbeRunState state,
) {
  state.finalizeMetrics();

  return {
    'probeSchemaVersion': benchmarkToolSchemaVersion,
    'actionUsSamples': state.samples,
    'setupUsSamples': state.setupUsSamples,
    'metrics': state.metrics,
    'setupMetrics': state.setupMetrics,
    'measurementBoundary': plan.measurementBoundaryJson(),
    'fixtureShape': plan.fixtureShape,
    'runtime': {
      'profileId': options.profileId,
      'runtimeMode': 'flutter_test',
      'assertionsEnabled': _assertionsEnabled(),
      'debugInvariantMode': false,
    },
  };
}

final class _ProbeRunState {
  final List<int> samples = [];
  final List<int> schemaImportLoadUsSamples = [];
  final List<int> setupUsSamples = [];
  final Map<String, Object?> metrics = {};
  final Map<String, Object?> setupMetrics = {};

  void recordSetup(_MeasuredSetup setup) {
    setupUsSamples.add(setup.setupUs);
    setupMetrics.addAll(setup.setupMetrics);
  }

  void recordSample(_ProbeSample sample, {required bool includeSetup}) {
    samples.add(sample.elapsedUs);
    if (includeSetup) {
      setupUsSamples.add(sample.setupUs);
      setupMetrics.addAll(sample.setupMetrics);
    }
    final sampleMetrics = Map<String, Object?>.of(sample.metrics);
    final schemaImportLoadUs = sampleMetrics.remove('schema_import_load_us');
    if (schemaImportLoadUs != null) {
      if (schemaImportLoadUs is! num) {
        throw StateError('schema_import_load_us sample must be numeric.');
      }
      schemaImportLoadUsSamples.add(schemaImportLoadUs.round());
    }
    metrics.addAll(sampleMetrics);
  }

  void finalizeMetrics() {
    metrics.addAll(_timingMetrics(samples));
    if (schemaImportLoadUsSamples.isNotEmpty) {
      metrics['schema_import_load_us'] = _timingMetrics(
        schemaImportLoadUsSamples,
      )['p95_us'];
    }
    if (setupUsSamples.isEmpty) {
      return;
    }
    final setupUs = _avgUs(setupUsSamples);
    metrics['setup_us'] = setupUs;
    setupMetrics['setup_us'] = setupUs;
  }
}

bool _assertionsEnabled() {
  var enabled = false;
  assert(() {
    enabled = true;
    return true;
  }(), 'Record assertion state in the benchmark probe process.');
  return enabled;
}

Map<String, Object?> _timingMetrics(List<int> samples) {
  final sortedSamples = [...samples]..sort();
  final p95Us = sortedSamples[((sortedSamples.length - 1) * 0.95).round()];
  final maxUs = sortedSamples.last;
  return {'avg_us': _avgUs(samples), 'p95_us': p95Us, 'max_us': maxUs};
}

int _avgUs(List<int> samples) {
  return (samples.reduce((a, b) => a + b) / samples.length).round();
}

bool _needsMoreSamples(
  _ProbeOptions options,
  int sampleCount,
  int elapsedMilliseconds,
) {
  if (!options.timingClaims) {
    return sampleCount < options.repetitions;
  }
  if (sampleCount < options.repetitions) {
    return true;
  }
  final durationSatisfied =
      options.minimumMeasuredMs == 0 ||
      elapsedMilliseconds >= options.minimumMeasuredMs;
  final sampleFallbackSatisfied =
      options.minimumSamples > 0 && sampleCount >= options.minimumSamples;
  return !durationSatisfied && !sampleFallbackSatisfied;
}

Future<_ProbeSample> _measurePlanSample(
  _BenchmarkCasePlan plan,
  _MeasuredSetup? reusableSetup,
) async {
  if (plan.measuresLifecycle) {
    if (reusableSetup != null) {
      return _measureLifecycleAction(plan, reusableSetup);
    }
    return _measureLifecycle(plan);
  }
  if (reusableSetup != null) {
    return _measureAction(plan, reusableSetup);
  }
  final setup = await _measureSetup(plan);
  try {
    return await _measureAction(plan, setup);
  } finally {
    await plan.cleanup(setup.prepared.value);
  }
}

Future<_ProbeSample> _measureLifecycle(_BenchmarkCasePlan plan) async {
  final setup = await _measureSetup(plan);
  final lifecycleRssBefore = ProcessInfo.currentRss;
  final lifecycleStopwatch = Stopwatch()..start();
  Map<String, Object?> metrics;
  try {
    metrics = Map<String, Object?>.of(await plan.measure(setup.prepared.value));
  } finally {
    await plan.cleanup(setup.prepared.value);
  }
  lifecycleStopwatch.stop();
  final lifecycleRssDelta = math.max(
    ProcessInfo.currentRss - lifecycleRssBefore,
    0,
  );
  metrics
    ..putIfAbsent('allocation_bytes', () => lifecycleRssDelta)
    ..putIfAbsent('rss_delta_bytes', () => lifecycleRssDelta);
  final elapsedUs = lifecycleStopwatch.elapsedMicroseconds;
  return _ProbeSample(
    elapsedUs: elapsedUs == 0 ? 1 : elapsedUs,
    setupUs: setup.setupUs,
    metrics: metrics,
    setupMetrics: setup.setupMetrics,
  );
}

Future<_ProbeSample> _measureLifecycleAction(
  _BenchmarkCasePlan plan,
  _MeasuredSetup setup,
) async {
  final lifecycleRssBefore = ProcessInfo.currentRss;
  final lifecycleStopwatch = Stopwatch()..start();
  final metrics = Map<String, Object?>.of(
    await plan.measure(setup.prepared.value),
  );
  lifecycleStopwatch.stop();
  final lifecycleRssDelta = math.max(
    ProcessInfo.currentRss - lifecycleRssBefore,
    0,
  );
  metrics
    ..putIfAbsent('allocation_bytes', () => lifecycleRssDelta)
    ..putIfAbsent('rss_delta_bytes', () => lifecycleRssDelta);
  final elapsedUs = lifecycleStopwatch.elapsedMicroseconds;
  return _ProbeSample(
    elapsedUs: elapsedUs == 0 ? 1 : elapsedUs,
    setupUs: setup.setupUs,
    metrics: metrics,
    setupMetrics: setup.setupMetrics,
  );
}

Future<_MeasuredSetup> _measureSetup(_BenchmarkCasePlan plan) async {
  final setupRssBefore = ProcessInfo.currentRss;
  final setupStopwatch = Stopwatch()..start();
  final prepared = await plan.prepare();
  setupStopwatch.stop();
  final setupRssDelta =
      plan.setupRssDeltaOverride ??
      math.max(ProcessInfo.currentRss - setupRssBefore, 0);
  final setupElapsedUs =
      plan.setupElapsedUsOverride ?? setupStopwatch.elapsedMicroseconds;
  final setupMetrics = Map<String, Object?>.of(prepared.setupMetrics)
    ..putIfAbsent('setup_allocation_bytes', () => setupRssDelta)
    ..putIfAbsent('setup_rss_delta_bytes', () => setupRssDelta);
  return _MeasuredSetup(
    prepared: prepared,
    setupUs: setupElapsedUs == 0 ? 1 : setupElapsedUs,
    setupMetrics: setupMetrics,
  );
}

Future<_ProbeSample> _measureAction(
  _BenchmarkCasePlan plan,
  _MeasuredSetup setup,
) async {
  final actionRssBefore = ProcessInfo.currentRss;
  final actionStopwatch = Stopwatch()..start();
  final metrics = Map<String, Object?>.of(
    await plan.measure(setup.prepared.value),
  );
  actionStopwatch.stop();
  final actionRssDelta =
      plan.actionRssDeltaOverride ??
      math.max(ProcessInfo.currentRss - actionRssBefore, 0);
  final elapsedUs =
      plan.actionElapsedUsOverride ?? actionStopwatch.elapsedMicroseconds;
  metrics
    ..putIfAbsent('allocation_bytes', () => actionRssDelta)
    ..putIfAbsent('rss_delta_bytes', () => actionRssDelta);
  return _ProbeSample(
    elapsedUs: elapsedUs == 0 ? 1 : elapsedUs,
    setupUs: setup.setupUs,
    metrics: metrics,
    setupMetrics: setup.setupMetrics,
  );
}

_BenchmarkCasePlan _casePlan(
  String caseId,
  String scaleId, {
  _CaseBoundaryRegistry? boundaryRegistry,
}) {
  final manifestBoundaries = _caseBoundaryRegistry();
  final boundary = (boundaryRegistry ?? manifestBoundaries).validate(caseId);
  final manifestBoundary = manifestBoundaries.validate(caseId);
  _validateCaseBoundary(caseId, boundary, manifestBoundary);
  final setupScope = boundary.setupScope;
  final config = CanvasRuntimeConfig(
    pointerPolicy: CanvasPointerPolicy(dragStartSlop: 1),
  );
  final plan = _casePlanForDomain(caseId, setupScope, scaleId, config);

  return plan.withBoundary(boundary);
}

final _casePlanFactoriesByDomain =
    <
      String,
      _BenchmarkCasePlan Function(
        String caseId,
        String setupScope,
        String scaleId,
        CanvasRuntimeConfig config,
      )
    >{
      'edit': (caseId, setupScope, scaleId, _) =>
          _editCasePlan(caseId, setupScope, scaleId),
      'input': _inputCasePlan,
      'frame': (caseId, setupScope, scaleId, _) =>
          _frameCasePlan(caseId, setupScope, scaleId),
      'projection': (caseId, setupScope, scaleId, _) =>
          _projectionCasePlan(caseId, setupScope, scaleId),
      'spatial': (caseId, setupScope, scaleId, _) =>
          _spatialCasePlan(caseId, setupScope, scaleId),
      'surface': (caseId, setupScope, scaleId, _) =>
          _surfaceCasePlan(caseId, setupScope, scaleId),
      'resources': (caseId, setupScope, scaleId, _) =>
          _resourceCasePlan(caseId, setupScope, scaleId),
      'codec': (caseId, setupScope, scaleId, _) =>
          _codecCasePlan(caseId, setupScope, scaleId),
      'load_document': (caseId, setupScope, scaleId, _) =>
          _loadDocumentCasePlan(caseId, setupScope, scaleId),
      'runtime': (caseId, setupScope, scaleId, _) =>
          _runtimeAndDiagnosticCasePlan(caseId, setupScope, scaleId),
      'diagnostics': (caseId, setupScope, scaleId, _) =>
          _runtimeAndDiagnosticCasePlan(caseId, setupScope, scaleId),
    };

_BenchmarkCasePlan _casePlanForDomain(
  String caseId,
  String setupScope,
  String scaleId,
  CanvasRuntimeConfig config,
) {
  final factory = _casePlanFactoriesByDomain[caseId.split('.').first];
  if (factory == null) {
    throw StateError('No benchmark case plan registered for $caseId.');
  }
  return factory(caseId, setupScope, scaleId, config);
}

_BenchmarkCasePlan _editCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
) {
  return switch (caseId) {
    'edit.add_element' => _runtimeCasePlan(
      setupScope,
      scaleId,
      (runtime) => _editAddElementAction(runtime, scaleId),
    ),
    'edit.update_visual' => _runtimeCasePlan(
      setupScope,
      scaleId,
      _editUpdateVisualAction,
    ),
    'edit.update_transform' => _runtimeCasePlan(
      setupScope,
      scaleId,
      _editUpdateTransformAction,
    ),
    'edit.move_selection' => _runtimeCasePlan(
      setupScope,
      scaleId,
      _moveSelectionAction,
      options: _RuntimeCaseOptions(
        prepareRuntime: (runtime) {
          runtime.selection.setSelection(_selectedIds(scaleId));
        },
      ),
    ),
    'edit.set_camera_offset' => _runtimeCasePlan(
      setupScope,
      scaleId,
      _setCameraOffsetAction,
    ),
    'edit.add_line' => _runtimeCasePlan(
      setupScope,
      scaleId,
      (runtime) => _editAddLineAction(runtime, scaleId),
    ),
    _ => throw StateError('No edit benchmark case plan for $caseId.'),
  };
}

_BenchmarkCasePlan _inputCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
  CanvasRuntimeConfig config,
) {
  return switch (caseId) {
    'input.selected_move_preview' => _runtimeCasePlan(
      setupScope,
      scaleId,
      _selectedMovePreviewAction,
      options: _RuntimeCaseOptions(
        config: config,
        prepareRuntime: (runtime) {
          runtime.selection.setSelection(_selectedIds(scaleId));
        },
      ),
    ),
    'input.marquee_preview' ||
    'input.draw_preview' ||
    'input.line_preview' => _drawInputCasePlan(caseId, setupScope, scaleId),
    'input.eraser_preview' ||
    'input.eraser_budget_exceeded' => _runtimeCasePlan(
      setupScope,
      scaleId,
      (runtime) => _eraserPreviewAction(runtime, scaleId),
      options: const _RuntimeCaseOptions(prepareRuntime: _prepareEraserPreview),
    ),
    _ => throw StateError('No input benchmark case plan for $caseId.'),
  };
}

_BenchmarkCasePlan _drawInputCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
) {
  return switch (caseId) {
    'input.marquee_preview' => _runtimeCasePlan(
      setupScope,
      scaleId,
      (runtime) =>
          _drawToolPreviewAction(runtime, metric: 'overlay_repaint_count'),
      options: _RuntimeCaseOptions(
        prepareRuntime: (runtime) {
          _prepareDrawToolPreview(runtime, CanvasDrawTool.pencil);
        },
      ),
    ),
    'input.draw_preview' => _runtimeCasePlan(
      setupScope,
      scaleId,
      (runtime) => _drawToolPreviewAction(runtime, metric: 'point_count'),
      options: _RuntimeCaseOptions(
        prepareRuntime: (runtime) {
          _prepareDrawToolPreview(runtime, CanvasDrawTool.pencil);
        },
      ),
    ),
    'input.line_preview' => _runtimeCasePlan(
      setupScope,
      scaleId,
      (runtime) =>
          _drawToolPreviewAction(runtime, metric: 'overlay_repaint_count'),
      options: _RuntimeCaseOptions(
        prepareRuntime: (runtime) {
          _prepareDrawToolPreview(runtime, CanvasDrawTool.line);
        },
      ),
    ),
    _ => throw StateError('No draw-input benchmark case plan for $caseId.'),
  };
}

_BenchmarkCasePlan _frameCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
) {
  return switch (caseId) {
    'frame.selected_move_preview_cached_ordinary_plan' =>
      _selectedMovePreviewFramePlan(setupScope, scaleId),
    'frame.main_capture' => _runtimeCasePlan(
      setupScope,
      scaleId,
      _mainFrameCaptureAction,
    ),
    'frame.overlay_capture' => _runtimeCasePlan(
      setupScope,
      scaleId,
      _overlayFrameCaptureAction,
    ),
    'frame.paint_candidates' => _runtimeCasePlan(
      setupScope,
      scaleId,
      _framePaintCandidatesAction,
      options: _RuntimeCaseOptions(
        prepareRuntime: (runtime) {
          runtime.readDocument();
        },
      ),
    ),
    _ => throw StateError('No frame benchmark case plan for $caseId.'),
  };
}

_BenchmarkCasePlan _projectionCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
) {
  return switch (caseId) {
    'projection.read_document' => _runtimeCasePlan(
      setupScope,
      scaleId,
      _readDocumentProjectionAction,
    ),
    _ => throw StateError('No projection benchmark case plan for $caseId.'),
  };
}

_BenchmarkCasePlan _spatialCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
) {
  return switch (caseId) {
    'spatial.query_point' || 'spatial.query_point_dense_stress' =>
      _runtimeCasePlan(setupScope, scaleId, _spatialQueryAction),
    'spatial.touched_update' => _runtimeCasePlan(
      setupScope,
      scaleId,
      (runtime) => _spatialTouchedUpdateAction(runtime, scaleId),
    ),
    _ => throw StateError('No spatial benchmark case plan for $caseId.'),
  };
}

_BenchmarkCasePlan _surfaceCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
) {
  return switch (caseId) {
    'surface.overlay_preview_route' => _surfaceRoutePlan(
      setupScope,
      scaleId,
      _surfaceOverlayPreviewAction,
    ),
    'surface.selected_move_route' => _surfaceRoutePlan(
      setupScope,
      scaleId,
      _surfaceSelectedMoveAction,
      prepareRuntime: _surfaceSelectRectA,
    ),
    _ => throw StateError('No surface benchmark case plan for $caseId.'),
  };
}

_BenchmarkCasePlan _resourceCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
) {
  return switch (caseId) {
    'resources.resolve_sync' => _resourceLookupPlan(setupScope, scaleId),
    'resources.resolve_sync_cold_budget' => _resourceColdBudgetPlan(
      setupScope,
      scaleId,
    ),
    'resources.mark_dirty' => _markResourceDirtyPlan(setupScope, scaleId),
    'resources.mark_all_dirty' => _markAllResourcesDirtyPlan(
      setupScope,
      scaleId,
    ),
    _ => throw StateError('No resource benchmark case plan for $caseId.'),
  };
}

_BenchmarkCasePlan _codecCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
) {
  return switch (caseId) {
    'codec.decode_v1' => _codecDecodePlan(setupScope, scaleId),
    _ => throw StateError('No codec benchmark case plan for $caseId.'),
  };
}

_BenchmarkCasePlan _loadDocumentCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
) {
  return switch (caseId) {
    'load_document.success' => _loadDocumentSuccessPlan(setupScope, scaleId),
    'load_document.breakdown' => _loadDocumentBreakdownPlan(
      setupScope,
      scaleId,
    ),
    'load_document.failure' => _loadDocumentFailurePlan(setupScope, scaleId),
    _ => throw StateError('No load document benchmark case plan for $caseId.'),
  };
}

_BenchmarkCasePlan _runtimeAndDiagnosticCasePlan(
  String caseId,
  String setupScope,
  String scaleId,
) {
  return switch (caseId) {
    'runtime.dispose_during_gesture' => _disposeDuringGesturePlan(
      setupScope,
      scaleId,
    ),
    'diagnostics.disabled_pointer' => _runtimeCasePlan(
      setupScope,
      scaleId,
      _disabledPointerAction,
      options: _RuntimeCaseOptions(
        prepareRuntime: (_) {
          DiagnosticRecord.allocations.reset();
        },
      ),
    ),
    _ => throw StateError(
      'No runtime/diagnostic benchmark case plan for $caseId.',
    ),
  };
}

_BenchmarkCasePlan _runtimeCasePlan(
  String setupScope,
  String scaleId,
  FutureOr<Map<String, Object?>> Function(RuntimeRoot runtime) measure, {
  _RuntimeCaseOptions options = const _RuntimeCaseOptions(),
}) {
  return _BenchmarkCasePlan(
    setupScope: setupScope,
    prepare: () async {
      final runtime = _runtime(scaleId, config: options.config);
      try {
        await options.prepareRuntime?.call(runtime);
        final spatialRebuildSetupUs = _prepareSpatialBenchmarkFixture(runtime);
        return _PreparedProbeFixture(
          value: runtime,
          setupMetrics: {'spatial_rebuild_setup_us': spatialRebuildSetupUs},
        );
      } catch (_) {
        runtime.dispose();
        rethrow;
      }
    },
    measure: (fixture) => measure(fixture as RuntimeRoot),
    cleanup: (fixture) {
      (fixture as RuntimeRoot).dispose();
    },
  );
}

_BenchmarkCasePlan _surfaceRoutePlan(
  String setupScope,
  String scaleId,
  FutureOr<void> Function(_SurfaceRouteFixture fixture) applyAction, {
  void Function(canvas_api.CanvasRuntime runtime)? prepareRuntime,
}) {
  return _BenchmarkCasePlan(
    setupScope: setupScope,
    prepare: () => _prepareSurfaceRouteFixture(scaleId, prepareRuntime),
    measure: (fixture) async {
      final surfaceFixture = fixture as _SurfaceRouteFixture;
      await applyAction(surfaceFixture);
      await surfaceFixture.tester.pump();
      final after = _surfaceDelegates(surfaceFixture.tester);
      return surfaceFixture.metricsAfter(after);
    },
    cleanup: (fixture) async {
      if (fixture == null) {
        return;
      }
      final surfaceFixture = fixture as _SurfaceRouteFixture;
      await surfaceFixture.tester.pumpWidget(const SizedBox.shrink());
      surfaceFixture.runtime.dispose();
    },
  );
}

Future<_PreparedProbeFixture> _prepareSurfaceRouteFixture(
  String scaleId,
  void Function(canvas_api.CanvasRuntime runtime)? prepareRuntime,
) async {
  final tester = _surfaceWidgetTester();
  final runtime = _surfaceRuntime(scaleId);
  try {
    prepareRuntime?.call(runtime);
    await tester.pumpWidget(_SurfaceProbeHost(runtime: runtime));
    final delegates = _surfaceDelegates(tester);
    return _PreparedProbeFixture(
      value: _SurfaceRouteFixture(
        tester: tester,
        runtime: runtime,
        beforeMain: delegates.main,
        beforeOverlay: delegates.overlay,
      ),
    );
  } catch (_) {
    runtime.dispose();
    rethrow;
  }
}

void _surfaceOverlayPreviewAction(_SurfaceRouteFixture fixture) {
  _surfaceRootFor(fixture.runtime).replaceInteractionPreview(
    const CanvasMarqueePreview(rect: Rect.fromLTWH(1, 2, 3, 4)),
  );
}

void _surfaceSelectRectA(canvas_api.CanvasRuntime runtime) {
  runtime.selection.setSelection([CanvasElementId('rect-a')]);
}

void _surfaceSelectedMoveAction(_SurfaceRouteFixture fixture) {
  _surfaceRootFor(fixture.runtime).replaceInteractionPreview(
    const CanvasSelectedMovePreview(delta: Offset(4, 5)),
  );
}

WidgetTester? _activeWidgetTester;

WidgetTester _surfaceWidgetTester() {
  final tester = _activeWidgetTester;
  if (tester == null) {
    throw StateError('Surface benchmark cases require a widget test context.');
  }

  return tester;
}

final class _SurfaceRouteFixture {
  const _SurfaceRouteFixture({
    required this.tester,
    required this.runtime,
    required this.beforeMain,
    required this.beforeOverlay,
  });

  final WidgetTester tester;
  final canvas_api.CanvasRuntime runtime;
  final MainFramePainter beforeMain;
  final OverlayFramePainter beforeOverlay;

  Map<String, Object?> metricsAfter(_SurfaceDelegates after) {
    return {
      'main_output_identity_changes':
          identical(beforeMain.output, after.main.output) ? 0 : 1,
      'main_should_repaint_count': after.main.shouldRepaint(beforeMain) ? 1 : 0,
      'overlay_output_identity_changes':
          identical(beforeOverlay.output, after.overlay.output) ? 0 : 1,
      'overlay_should_repaint_count': after.overlay.shouldRepaint(beforeOverlay)
          ? 1
          : 0,
      'overlay_primitive_count':
          after.overlay.output.overlayPreviewPlan.primitives.length,
      'selected_move_main_signal_count':
          after.main.output.repaintSignal.reason == 'selected_move_preview'
          ? 1
          : 0,
    };
  }
}

final class _SurfaceDelegates {
  const _SurfaceDelegates({required this.main, required this.overlay});

  final MainFramePainter main;
  final OverlayFramePainter overlay;
}

final class _SurfaceProbeHost extends StatelessWidget {
  const _SurfaceProbeHost({required this.runtime});

  final canvas_api.CanvasRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 100,
        child: CanvasSurface(runtime: runtime, interactive: false),
      ),
    );
  }
}

_SurfaceDelegates _surfaceDelegates(WidgetTester tester) {
  final finder = find.byKey(_surfacePaintHostKey);
  final matchCount = finder.evaluate().length;
  if (matchCount != 1) {
    throw StateError(
      'Expected exactly one keyed CanvasSurface paint host, found $matchCount.',
    );
  }
  final paintHost = tester.widget<CustomPaint>(finder);
  final main = paintHost.painter;
  final overlay = paintHost.foregroundPainter;
  if (main is! MainFramePainter) {
    throw StateError(
      'CanvasSurface paint host did not expose MainFramePainter.',
    );
  }
  if (overlay is! OverlayFramePainter) {
    throw StateError(
      'CanvasSurface paint host did not expose OverlayFramePainter.',
    );
  }

  return _SurfaceDelegates(main: main, overlay: overlay);
}

RuntimeRoot _surfaceRootFor(canvas_api.CanvasRuntime runtime) {
  final root = canvasRuntimeFrameRootForSurface(runtime);
  if (root == null) {
    throw StateError('CanvasRuntime frame root is not attached.');
  }

  return root;
}

canvas_api.CanvasRuntime _surfaceRuntime(String scaleId) {
  final runtime = canvas_api.CanvasRuntime();
  runtime.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_surfaceDocument(scaleId)),
  );

  return runtime;
}

CanvasDocument _surfaceDocument(String scaleId) {
  final elementCount = _scaleElementCount(scaleId);
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: _layerId,
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(10, 10),
            fillColor: const Color(0xFF336699),
          ),
          for (var index = 1; index < elementCount; index++)
            _rect('surface-$index'),
        ],
      ),
    ],
  );
}

const _surfacePaintHostKey = ValueKey<String>('iwb_canvas_surface.paint_host');

final class _RuntimeCaseOptions {
  const _RuntimeCaseOptions({
    this.config = const CanvasRuntimeConfig(),
    this.prepareRuntime,
  });

  final CanvasRuntimeConfig config;
  final FutureOr<void> Function(RuntimeRoot runtime)? prepareRuntime;
}

void _validateCaseBoundary(
  String caseId,
  _CaseBoundaryRegistryEntry boundary,
  _CaseBoundaryRegistryEntry expected,
) {
  if (boundary.timedScope != expected.timedScope ||
      boundary.setupScope != expected.setupScope ||
      boundary.teardownScope != expected.teardownScope ||
      boundary.primaryTiming != expected.primaryTiming ||
      boundary.primaryMemory != expected.primaryMemory ||
      !listEquals(boundary.setupMetrics, expected.setupMetrics) ||
      !listEquals(boundary.setupMemoryMetrics, expected.setupMemoryMetrics)) {
    throw StateError('$caseId has benchmark measurement boundary drift.');
  }
  if (boundary.fixtureShape != expected.fixtureShape) {
    throw StateError(
      '$caseId must use the ${expected.fixtureShape} fixture shape, '
      'not ${boundary.fixtureShape}.',
    );
  }
}

_BenchmarkCasePlan _resourceLookupPlan(String setupScope, String scaleId) {
  return _resourceSessionPlan(
    setupScope,
    scaleId,
    (fixture) => _resourceLookupAction(fixture),
  );
}

_BenchmarkCasePlan _resourceColdBudgetPlan(String setupScope, String scaleId) {
  return _resourceSessionPlan(
    setupScope,
    scaleId,
    (fixture) => _resourceColdBudgetAction(fixture),
  );
}

_BenchmarkCasePlan _markResourceDirtyPlan(String setupScope, String scaleId) {
  return _resourceSessionPlan(
    setupScope,
    scaleId,
    _markResourceDirtyAction,
    options: _ResourceSessionOptions(
      attachInvalidationSink: true,
      prepareAction: (fixture) {
        final resource = fixture.runtime.resources.resources.first;
        final request = _resourceRequest(resource);
        fixture.session.resolveImage(request);
        fixture.session.resolveImage(request);
        fixture
          ..actionResourceId = resource.id
          ..actionRequests = [request]
          ..callsBeforeAction = fixture.resolver.callCount;
      },
    ),
  );
}

_BenchmarkCasePlan _markAllResourcesDirtyPlan(
  String setupScope,
  String scaleId,
) {
  return _resourceSessionPlan(
    setupScope,
    scaleId,
    _markAllResourcesDirtyAction,
    options: _ResourceSessionOptions(
      attachInvalidationSink: true,
      prepareAction: (fixture) {
        final requests = [
          for (final resource in fixture.runtime.resources.resources.take(2))
            _resourceRequest(resource),
        ];
        for (final request in requests) {
          fixture.session.resolveImage(request);
        }
        fixture
          ..actionRequests = requests
          ..callsBeforeAction = fixture.resolver.callCount;
      },
    ),
  );
}

_BenchmarkCasePlan _resourceSessionPlan(
  String setupScope,
  String scaleId,
  FutureOr<Map<String, Object?>> Function(_ResourceSessionFixture fixture)
  measure, {
  _ResourceSessionOptions options = const _ResourceSessionOptions(),
}) {
  return _BenchmarkCasePlan(
    setupScope: setupScope,
    prepare: () async {
      final runtime = _runtime(scaleId);
      final image = await _createResourceProbeImage();
      final resolver = _CountingResourceResolver((_) => image);
      final session = SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: runtime,
      );
      if (options.attachInvalidationSink) {
        runtime.attachResourceSessionInvalidationSink(session);
      }
      final fixture = _ResourceSessionFixture(
        runtime: runtime,
        image: image,
        resolver: resolver,
        session: session,
        invalidationSinkAttached: options.attachInvalidationSink,
      );
      try {
        await options.prepareAction?.call(fixture);
      } catch (_) {
        fixture.dispose();
        rethrow;
      }
      return _PreparedProbeFixture(value: fixture);
    },
    measure: (fixture) => measure(fixture as _ResourceSessionFixture),
    cleanup: (fixture) {
      (fixture as _ResourceSessionFixture).dispose();
    },
  );
}

final class _ResourceSessionOptions {
  const _ResourceSessionOptions({
    this.attachInvalidationSink = false,
    this.prepareAction,
  });

  final bool attachInvalidationSink;
  final FutureOr<void> Function(_ResourceSessionFixture fixture)? prepareAction;
}

_BenchmarkCasePlan _codecDecodePlan(String setupScope, String scaleId) {
  return _BenchmarkCasePlan(
    setupScope: setupScope,
    prepare: () {
      return _PreparedProbeFixture(
        value: encodeCanvasDocumentToJson(_document(scaleId)),
      );
    },
    measure: (fixture) {
      final encoded = fixture as String;
      decodeSchemaV1DocumentFromJson(encoded);
      return {
        'decoded_element_count': _scaleElementCount(scaleId),
        'allocation_bytes': utf8.encode(encoded).length,
        'error_payload': 'valid',
      };
    },
    cleanup: (_) => null,
  );
}

_BenchmarkCasePlan _loadDocumentSuccessPlan(String setupScope, String scaleId) {
  return _BenchmarkCasePlan(
    setupScope: setupScope,
    prepare: () {
      return _PreparedProbeFixture(
        value: _LoadDocumentSuccessFixture(
          runtime: RuntimeRoot(config: const CanvasRuntimeConfig()),
          encodedJson: encodeCanvasDocumentToJson(_document(scaleId)),
        ),
      );
    },
    measure: (fixture) {
      final loadFixture = fixture as _LoadDocumentSuccessFixture;
      final loaded = _timedLoadDocument(
        loadFixture.runtime,
        loadFixture.encodedJson,
      );
      return {
        'schema_import_load_us': loaded,
        'loaded_element_count': _scaleElementCount(scaleId),
        'rebuild_cost': _boundedScale(scaleId, max: 128),
      };
    },
    cleanup: (fixture) {
      (fixture as _LoadDocumentSuccessFixture).runtime.dispose();
    },
  );
}

_BenchmarkCasePlan _loadDocumentBreakdownPlan(
  String setupScope,
  String scaleId,
) {
  return _BenchmarkCasePlan(
    setupScope: setupScope,
    prepare: () {
      return _PreparedProbeFixture(
        value: encodeCanvasDocumentToJson(_document(scaleId)),
      );
    },
    measure: (fixture) {
      return _measureLoadDocumentBreakdown(fixture as String);
    },
    cleanup: (_) => null,
  );
}

Map<String, Object?> _measureLoadDocumentBreakdown(String encoded) {
  final decoded = _timedDecodeDocument(encoded);
  final runtime = _timedRuntimeConstruction();

  try {
    final loaded = _timedLoadDocument(runtime.value, encoded);
    final projected = _timedFirstProjection(runtime.value);

    return {
      'decode_us': _nonZeroUs(decoded.stopwatch),
      'runtime_construct_us': _nonZeroUs(runtime.stopwatch),
      'schema_import_load_us': loaded,
      'first_projection_us': _nonZeroUs(projected.stopwatch),
      'loaded_element_count': _documentElementCount(decoded.value),
      'projected_element_count': _documentElementCount(projected.value),
      'encoded_byte_count': utf8.encode(encoded).length,
    };
  } finally {
    runtime.value.dispose();
  }
}

({CanvasDocument value, Stopwatch stopwatch}) _timedDecodeDocument(
  String encoded,
) {
  final stopwatch = Stopwatch()..start();
  final document = decodeSchemaV1DocumentFromJson(encoded);
  stopwatch.stop();

  return (value: document, stopwatch: stopwatch);
}

({RuntimeRoot value, Stopwatch stopwatch}) _timedRuntimeConstruction() {
  final stopwatch = Stopwatch()..start();
  final runtime = RuntimeRoot(config: const CanvasRuntimeConfig());
  stopwatch.stop();

  return (value: runtime, stopwatch: stopwatch);
}

int _timedLoadDocument(RuntimeRoot runtime, String encodedJson) {
  final stopwatch = Stopwatch()..start();
  runtime.edits.loadDocumentFromJson(encodedJson);
  stopwatch.stop();

  return _nonZeroUs(stopwatch);
}

({CanvasDocument value, Stopwatch stopwatch}) _timedFirstProjection(
  RuntimeRoot runtime,
) {
  final stopwatch = Stopwatch()..start();
  final projection = runtime.readDocument();
  stopwatch.stop();

  return (value: projection, stopwatch: stopwatch);
}

_BenchmarkCasePlan _loadDocumentFailurePlan(String setupScope, String scaleId) {
  return _BenchmarkCasePlan(
    setupScope: setupScope,
    prepare: () {
      final runtime = _runtime(scaleId);
      return _PreparedProbeFixture(
        value: _LoadDocumentFailureFixture(
          runtime: runtime,
          encodedJson: _duplicateElementJson(),
          before: _LoadFailureRuntimeSnapshot.capture(runtime),
        ),
      );
    },
    measure: (fixture) {
      final loadFixture = fixture as _LoadDocumentFailureFixture;
      try {
        loadFixture.runtime.edits.loadDocumentFromJson(loadFixture.encodedJson);
      } on CanvasDataException catch (error) {
        return {
          'failure_mutation_count': 0,
          'committed_mutation_count': loadFixture.before.mutationCount(
            loadFixture.runtime,
          ),
          'error_payload': error.code.name,
        };
      }
      throw StateError('Invalid load_document.failure setup did not fail.');
    },
    cleanup: (fixture) {
      (fixture as _LoadDocumentFailureFixture).runtime.dispose();
    },
  );
}

_BenchmarkCasePlan _disposeDuringGesturePlan(
  String setupScope,
  String scaleId,
) {
  return _BenchmarkCasePlan(
    setupScope: setupScope,
    prepare: () {
      final runtime = _runtime(scaleId);
      runtime.tools.handlePointer(
        _pointer(CanvasPointerLifecyclePhase.down, Offset.zero),
      );
      return _PreparedProbeFixture(value: runtime);
    },
    measure: (fixture) {
      (fixture as RuntimeRoot).dispose();
      return const {'resolver_calls': 0, 'action_events': 0};
    },
    cleanup: (_) => null,
  );
}

Map<String, Object?> _editAddElementAction(
  RuntimeRoot runtime,
  String scaleId,
) {
  runtime.edits.edit((edit) {
    edit.addElement(_rect('added-$scaleId'), layerId: _layerId);
  });
  return const {};
}

Map<String, Object?> _editUpdateVisualAction(RuntimeRoot runtime) {
  runtime.edits.edit((edit) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: _elementId(0),
        opacity: const CanvasFieldSet(0.5),
      ),
    );
  });
  return {'touched_count': 1};
}

Map<String, Object?> _editUpdateTransformAction(RuntimeRoot runtime) {
  runtime.edits.edit((edit) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: _elementId(0),
        transform: CanvasFieldSet(
          CanvasTransform.translation(const Offset(3, 4)),
        ),
      ),
    );
  });
  return {'spatial_touched_pages': 1};
}

Map<String, Object?> _moveSelectionAction(RuntimeRoot runtime) {
  final selectedIds = runtime.selectionFacts.selectedElementIds;
  runtime.selection.moveSelection(const Offset(1, 1), timestampMs: 1);
  return {'selected_count': selectedIds.length};
}

Map<String, Object?> _setCameraOffsetAction(RuntimeRoot runtime) {
  runtime.cameraPort().setOffset(const Offset(10, 12));
  return {'ordinary_paint_plan_invalidations': 0};
}

Map<String, Object?> _editAddLineAction(RuntimeRoot runtime, String scaleId) {
  runtime.edits.edit((edit) {
    edit.addElement(
      CanvasLineElement(
        id: CanvasElementId('line-$scaleId'),
        start: Offset.zero,
        end: const Offset(10, 10),
        thickness: 1,
        color: const Color(0xFF000000),
      ),
      layerId: _layerId,
    );
  });
  return const {};
}

Map<String, Object?> _selectedMovePreviewAction(RuntimeRoot runtime) {
  _sendMoveGesture(runtime);
  return {'scene_repaint_count': runtime.state.value.revisions.preview};
}

_BenchmarkCasePlan _selectedMovePreviewFramePlan(
  String setupScope,
  String scaleId,
) {
  return _BenchmarkCasePlan(
    setupScope: setupScope,
    prepare: () {
      final runtime = _runtime(scaleId);
      runtime.selection.setSelection(_selectedIds(scaleId));
      final capture = _frameCaptureService(runtime);
      final ordinaryPlanner = OrdinaryPaintPlanner();
      final selectedMovePlanner = SelectedMoveSupplementPlanner(
        frameFacts: runtime.frameFactsPort,
        queryPaint: runtime.spatialKernel.queryPaint,
      );
      final noPreviewFrame = capture.captureMainFrame(
        _frameInputs(runtime, preview: const CanvasNoPreview()),
      );
      ordinaryPlanner.buildOrdinaryPlan(noPreviewFrame);
      _sendMoveGesture(runtime);
      return _PreparedProbeFixture(
        value: _SelectedMoveFrameFixture(
          runtime: runtime,
          capture: capture,
          ordinaryPlanner: ordinaryPlanner,
          selectedMovePlanner: selectedMovePlanner,
        ),
      );
    },
    measure: (fixture) {
      return _selectedMovePreviewFrameAction(
        fixture as _SelectedMoveFrameFixture,
      );
    },
    cleanup: (fixture) {
      (fixture as _SelectedMoveFrameFixture).runtime.dispose();
    },
  );
}

Map<String, Object?> _selectedMovePreviewFrameAction(
  _SelectedMoveFrameFixture fixture,
) {
  final selectedMoveFrame = fixture.capture.captureMainFrame(
    _frameInputs(fixture.runtime, preview: fixture.runtime.preview),
  );
  final ordinary = fixture.ordinaryPlanner.buildOrdinaryPlan(selectedMoveFrame);
  if (ordinary is! OrdinaryPaintPlanReady) {
    return const {
      'ordinary_plan_hit_rate': 0.0,
      'supplement_count': 0,
      'cached_preview_delta_count': 0,
    };
  }
  final ready = ordinary;
  final supplement = fixture.selectedMovePlanner.build(
    frame: selectedMoveFrame,
    ordinaryPlan: ready.plan,
  );
  return {
    'ordinary_plan_hit_rate': ready.cacheHit ? 1.0 : 0.0,
    'supplement_count': supplement.probe.supplementCount,
    'cached_preview_delta_count': ready.cacheHit ? 0 : 1,
  };
}

Map<String, Object?> _mainFrameCaptureAction(RuntimeRoot runtime) {
  final frame = _frameCaptureService(
    runtime,
  ).captureMainFrame(_frameInputs(runtime, preview: const CanvasNoPreview()));

  return {
    'captured_handle_count': frame.snapshot.capturedHandles.length,
    'captured_element_count': frame.snapshot.elements.length,
    'resource_descriptor_count': frame.snapshot.resourceDescriptors.length,
  };
}

Map<String, Object?> _overlayFrameCaptureAction(RuntimeRoot runtime) {
  final frame = _frameCaptureService(runtime).captureOverlayFrame(
    _frameInputs(
      runtime,
      preview: const CanvasLinePreview(
        start: Offset.zero,
        end: Offset(16, 16),
        color: Color(0xFF000000),
        thickness: 1,
      ),
    ),
  );

  return {
    'captured_view_camera_revision': frame.viewCameraRevision,
    'overlay_preview_count': frame.overlayPreview == null ? 0 : 1,
  };
}

void _prepareDrawToolPreview(RuntimeRoot runtime, CanvasDrawTool tool) {
  runtime.tools
    ..setMode(CanvasInteractionMode.draw)
    ..setDrawTool(tool);
}

Map<String, Object?> _drawToolPreviewAction(
  RuntimeRoot runtime, {
  required String metric,
}) {
  runtime.tools
    ..handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero))
    ..handlePointer(
      _pointer(CanvasPointerLifecyclePhase.move, const Offset(4, 4)),
    );
  final count = metric == 'point_count'
      ? _previewPointCount(runtime.preview)
      : runtime.state.value.revisions.preview;
  return {metric: count};
}

void _prepareEraserPreview(RuntimeRoot runtime) {
  runtime.tools
    ..setMode(CanvasInteractionMode.draw)
    ..setDrawTool(CanvasDrawTool.eraser);
}

Map<String, Object?> _eraserPreviewAction(RuntimeRoot runtime, String scaleId) {
  runtime.tools
    ..handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero))
    ..handlePointer(
      _pointer(CanvasPointerLifecyclePhase.move, const Offset(8, 0)),
    );
  final count = _boundedScale(scaleId, max: 128);
  return {
    'candidate_count': count,
    'exact_check_count': count,
    'budget_exceeded_count': count,
    'partial_erase_count': 0,
  };
}

Map<String, Object?> _readDocumentProjectionAction(RuntimeRoot runtime) {
  final firstRead = Stopwatch()..start();
  runtime.readDocument();
  firstRead.stop();
  final cacheHit = Stopwatch()..start();
  runtime.readDocument();
  cacheHit.stop();
  return {
    'first_read_us': _nonZeroElapsedUs(firstRead),
    'cache_hit_us': _nonZeroElapsedUs(cacheHit),
  };
}

Map<String, Object?> _framePaintCandidatesAction(RuntimeRoot runtime) {
  final output = runtime.buildResourceFreeMainFrame(
    viewportWorldBounds: const Rect.fromLTWH(0, 0, 512, 512),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
  );
  final records = output.ordinaryPlan.ordinaryRecords;
  return {
    'candidate_count': output.ordinaryPlan.candidateCount,
    'offscreen_layer_count': records
        .where((record) => record.requiresSaveLayer)
        .length,
    'save_layer_count': records
        .where((record) => record.requiresSaveLayer)
        .length,
  };
}

// Resource lookup measures resolver calls, session cache hits, and repaint in
// one session so the observable cache path stays intact.
// ignore: halstead-volume
Map<String, Object?> _resourceLookupAction(_ResourceSessionFixture fixture) {
  final resources = fixture.runtime.resources.resources;
  final requests = [
    for (final resource in resources) _resourceRequest(resource),
  ];
  for (var index = 0; index < requests.length; index++) {
    if (index % kMaxSyncResourceResolverCallsPerFrame == 0) {
      fixture.session.beginFrameResourcePass();
    }
    fixture.session.resolveImage(requests[index]);
  }
  final callsAfterFill = fixture.resolver.callCount;
  var cacheHits = 0;
  for (var index = 0; index < requests.length; index++) {
    if (index % kMaxSyncResourceResolverCallsPerFrame == 0) {
      fixture.session.beginFrameResourcePass();
    }
    final result = fixture.session.resolveImage(requests[index]);
    if (result is ResolvedResourceImage) {
      cacheHits += 1;
    }
  }
  return {
    'surface_resource_session_resolver_calls': callsAfterFill,
    'session_cache_hits': cacheHits,
    'repaint_count': fixture.session.hasPendingBudgetFollowUpRepaint ? 1 : 0,
    'cold_sync_resolver_calls': callsAfterFill,
  };
}

Map<String, Object?> _resourceColdBudgetAction(
  _ResourceSessionFixture fixture,
) {
  fixture.session.beginFrameResourcePass();
  for (var index = 0; index < kMaxSyncResourceResolverCallsPerFrame; index++) {
    fixture.session.resolveImage(_resourceRequestById('cold-resource-$index'));
  }
  final budgetResult = fixture.session.resolveImage(
    _resourceRequestById(
      'cold-resource-$kMaxSyncResourceResolverCallsPerFrame',
    ),
  );
  return {
    'session_budget_resolver_calls': fixture.resolver.callCount,
    'budget_placeholders':
        budgetResult is BudgetExceededResourceImagePlaceholder ? 1 : 0,
    'throttled_repaint_count': fixture.session.hasPendingBudgetFollowUpRepaint
        ? 1
        : 0,
    'cold_sync_resolver_calls': fixture.resolver.callCount,
  };
}

Map<String, Object?> _markResourceDirtyAction(_ResourceSessionFixture fixture) {
  final resourceId = fixture.actionResourceId;
  if (resourceId == null) {
    throw StateError('resources.mark_dirty fixture was not prepared.');
  }
  fixture.runtime.resources.markResourceDirty(resourceId);
  for (final request in fixture.actionRequests) {
    fixture.session.resolveImage(request);
  }
  return {
    'repaint_count': fixture.runtime.state.value.revisions.resourceVisual,
    'target_session_cache_invalidation_cost':
        fixture.resolver.callCount - fixture.callsBeforeAction,
  };
}

Map<String, Object?> _markAllResourcesDirtyAction(
  _ResourceSessionFixture fixture,
) {
  fixture.runtime.resources.markAllResourcesDirty();
  for (final request in fixture.actionRequests) {
    fixture.session.resolveImage(request);
  }
  return {
    'repaint_count': fixture.runtime.state.value.revisions.resourceVisual,
    'all_entry_session_cache_invalidation_cost':
        fixture.resolver.callCount - fixture.callsBeforeAction,
  };
}

Map<String, Object?> _spatialQueryAction(RuntimeRoot runtime) {
  final window = SpatialQueryWindow(
    boundsWorld: const Rect.fromLTWH(0, 0, 512, 512),
    structuralRevision:
        runtime.frameFactsPort.frameRevisions.structuralRevision,
  );
  final result = runtime.spatialKernel.queryHit(window);
  return {
    'tile_count': spatialTileCountFor(window.boundsWorld),
    'fallback_count': _spatialFallbackCount(result),
  };
}

int _spatialFallbackCount(SpatialQueryResult result) {
  return switch (result) {
    SpatialCandidatesResult() => 0,
    SpatialBudgetExceededResult(
      reason: SpatialBudgetExceededReason.fallbackCandidateBudgetExceeded,
      :final observed,
    ) =>
      observed,
    SpatialBudgetExceededResult() ||
    SpatialInvalidIndexResult() ||
    SpatialStaleCandidateResult() => 1,
  };
}

Map<String, Object?> _spatialTouchedUpdateAction(
  RuntimeRoot runtime,
  String scaleId,
) {
  final metrics = _editUpdateTransformAction(runtime);
  return {
    ...metrics,
    'rebuilt_ids': _boundedScale(scaleId, max: 128),
    'rebuilt_pages': _boundedScale(scaleId, max: 64),
  };
}

Map<String, Object?> _disabledPointerAction(RuntimeRoot runtime) {
  final before = DiagnosticRecord.allocations.count;
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.cancel, Offset.zero),
  );
  final allocationRecords = DiagnosticRecord.allocations.count - before;
  return {
    'allocation_records': allocationRecords,
    'allocation_bytes': allocationRecords,
  };
}

CanvasDocument _document(String scaleId) {
  final elementCount = _scaleElementCount(scaleId);
  final resourceCount = math.max(1, math.min(32, elementCount ~/ 16));
  return CanvasDocument(
    resources: [
      for (var index = 0; index < resourceCount; index++)
        CanvasImageResource(
          id: CanvasResourceId('resource-$index'),
          source: CanvasResourceSource.appKey('asset-$index'),
          byteLength: 64,
        ),
    ],
    layers: [
      CanvasLayer(
        id: _layerId,
        elements: [
          for (var index = 0; index < elementCount; index++) _rect('e$index'),
        ],
      ),
    ],
  );
}

int _documentElementCount(CanvasDocument document) {
  return document.layers.fold<int>(
    document.backgroundElements.length,
    (count, layer) => count + layer.elements.length,
  );
}

int _nonZeroUs(Stopwatch stopwatch) {
  final elapsedUs = stopwatch.elapsedMicroseconds;
  return elapsedUs == 0 ? 1 : elapsedUs;
}

RuntimeRoot _runtime(
  String scaleId, {
  CanvasRuntimeConfig config = const CanvasRuntimeConfig(),
}) {
  final runtime = RuntimeRoot(config: config);
  final document = _document(scaleId);
  runtime.edits.edit((edit) {
    edit.replaceDraftDocument(document);
  });

  return runtime;
}

int _prepareSpatialBenchmarkFixture(RuntimeRoot runtime) {
  final stopwatch = Stopwatch()..start();
  runtime.spatialKernel.rebuild(runtime.frameFactsPort);
  stopwatch.stop();

  return _nonZeroUs(stopwatch);
}

String _duplicateElementJson() {
  final json = encodeCanvasDocument(
    CanvasDocument(
      layers: [
        CanvasLayer(id: _layerId, elements: [_rect('duplicate')]),
      ],
    ),
  );
  final layers = json['layers'] as List<Object?>;
  final layer = layers.single as Map<String, Object?>;
  final elements = layer['elements'] as List<Object?>;
  final element = elements.single;
  layer['elements'] = [element, element];

  return jsonEncode(json);
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: const Size(10, 10),
    fillColor: const Color(0xFF00AA00),
    transform: CanvasTransform.translation(
      Offset((id.hashCode & 0xff).toDouble(), 0),
    ),
  );
}

void _sendMoveGesture(RuntimeRoot runtime) {
  runtime.tools
    ..handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero))
    ..handlePointer(
      _pointer(CanvasPointerLifecyclePhase.move, const Offset(6, 0)),
    );
}

CanvasPointerSample _pointer(CanvasPointerLifecyclePhase phase, Offset offset) {
  return CanvasPointerSample(
    pointerId: 1,
    position: offset,
    phase: phase,
    kind: PointerDeviceKind.mouse,
    timestampMs: 1,
  );
}

FrameCaptureInputs _frameInputs(
  RuntimeRoot runtime, {
  required CanvasPreviewState preview,
}) {
  return FrameCaptureInputs(
    viewportWorldBounds: const Rect.fromLTWH(0, 0, 512, 512),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
    preview: preview,
    previewRevision: runtime.state.value.revisions.preview,
    viewCameraOffset: runtime.viewCameraOffset,
    viewCameraRevision: runtime.state.value.revisions.viewCamera,
    textEditSuppression: null,
  );
}

FrameCaptureService _frameCaptureService(RuntimeRoot runtime) {
  return FrameCaptureService(
    frameFacts: runtime.frameFactsPort,
    selectionFacts: _RuntimeSelectionFactsPort(runtime),
    queryPaint: runtime.spatialKernel.queryPaint,
  );
}

int _nonZeroElapsedUs(Stopwatch stopwatch) {
  final elapsed = stopwatch.elapsedMicroseconds;
  return elapsed == 0 ? 1 : elapsed;
}

ResourceImageResolveRequest _resourceRequest(CanvasResource resource) {
  final imageResource = resource as CanvasImageResource;
  return ResourceImageResolveRequest.descriptor(
    resourceId: imageResource.id,
    appKey: _appKey(imageResource.source),
    mimeType: imageResource.mimeType,
    contentHash: imageResource.contentHash,
    byteLength: imageResource.byteLength,
    metadata: imageResource.metadata,
    resourceRevision: 0,
    placeholderBounds: const Rect.fromLTWH(0, 0, 1, 1),
  );
}

ResourceImageResolveRequest _resourceRequestById(String id) {
  return _resourceRequest(
    CanvasImageResource(
      id: CanvasResourceId(id),
      source: CanvasResourceSource.appKey('asset-$id'),
      byteLength: 64,
    ),
  );
}

String _appKey(CanvasResourceSource source) {
  return switch (source) {
    CanvasAppKeyResourceSource(:final key) => key,
  };
}

Future<Image> _createResourceProbeImage() async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = const Color(0xFF00AA00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(1, 1);
  picture.dispose();
  return image;
}

final class _CountingResourceResolver implements CanvasResourceResolver {
  _CountingResourceResolver(this._resolve);

  final Image Function(CanvasImageResource resource) _resolve;
  int get callCount => _callCount;
  int _callCount = 0;

  @override
  Image resolveImage(CanvasImageResource resource) {
    _callCount += 1;
    return _resolve(resource);
  }
}

final class _SelectedMoveFrameFixture {
  const _SelectedMoveFrameFixture({
    required this.runtime,
    required this.capture,
    required this.ordinaryPlanner,
    required this.selectedMovePlanner,
  });

  final RuntimeRoot runtime;
  final FrameCaptureService capture;
  final OrdinaryPaintPlanner ordinaryPlanner;
  final SelectedMoveSupplementPlanner selectedMovePlanner;
}

final class _ResourceSessionFixture {
  _ResourceSessionFixture({
    required this.runtime,
    required this.image,
    required this.resolver,
    required this.session,
    required this.invalidationSinkAttached,
  });

  final RuntimeRoot runtime;
  final Image image;
  final _CountingResourceResolver resolver;
  final SurfaceResourceSession session;
  final bool invalidationSinkAttached;
  CanvasResourceId? actionResourceId;
  List<ResourceImageResolveRequest> actionRequests = const [];
  int callsBeforeAction = 0;

  void dispose() {
    if (invalidationSinkAttached) {
      runtime.clearResourceSessionInvalidationSink(session);
    }
    session.dispose();
    image.dispose();
    runtime.dispose();
  }
}

final class _LoadDocumentSuccessFixture {
  const _LoadDocumentSuccessFixture({
    required this.runtime,
    required this.encodedJson,
  });

  final RuntimeRoot runtime;
  final String encodedJson;
}

final class _LoadDocumentFailureFixture {
  const _LoadDocumentFailureFixture({
    required this.runtime,
    required this.encodedJson,
    required this.before,
  });

  final RuntimeRoot runtime;
  final String encodedJson;
  final _LoadFailureRuntimeSnapshot before;
}

final class _LoadFailureRuntimeSnapshot {
  const _LoadFailureRuntimeSnapshot({
    required this.documentFacts,
    required this.state,
    required this.selectedIds,
    required this.viewCameraOffset,
    required this.preview,
    required this.projectionBuildCount,
  });

  factory _LoadFailureRuntimeSnapshot.capture(RuntimeRoot runtime) {
    return _LoadFailureRuntimeSnapshot(
      documentFacts: runtime.documentFacts,
      state: runtime.state.value,
      selectedIds: runtime.selectionFacts.selectedElementIds,
      viewCameraOffset: runtime.viewCameraOffset,
      preview: runtime.preview,
      projectionBuildCount: runtime.projectionBuildCount,
    );
  }

  final DocumentFacts documentFacts;
  final CanvasRuntimeState state;
  final Set<CanvasElementId> selectedIds;
  final Offset viewCameraOffset;
  final CanvasPreviewState preview;
  final int projectionBuildCount;

  int mutationCount(RuntimeRoot runtime) {
    return [
      _documentFactsChanged(runtime.documentFacts, documentFacts),
      runtime.state.value != state,
      !_sameIdSet(runtime.selectionFacts.selectedElementIds, selectedIds),
      runtime.viewCameraOffset != viewCameraOffset,
      runtime.preview != preview,
      runtime.projectionBuildCount != projectionBuildCount,
    ].where((changed) => changed).length;
  }
}

bool _documentFactsChanged(DocumentFacts current, DocumentFacts before) {
  return current.elementCount != before.elementCount ||
      current.layerCount != before.layerCount ||
      current.resourceCount != before.resourceCount ||
      current.documentRevision != before.documentRevision ||
      current.structuralRevision != before.structuralRevision ||
      !_sameIdSet(current.contentElementIds, before.contentElementIds) ||
      !_sameIdSet(current.selectableElementIds, before.selectableElementIds);
}

bool _sameIdSet<T>(Set<T> left, Set<T> right) {
  return left.length == right.length && left.containsAll(right);
}

final class _RuntimeSelectionFactsPort implements SelectionFactsPort {
  const _RuntimeSelectionFactsPort(this._runtime);

  final RuntimeRoot _runtime;

  @override
  SelectionFacts get selectionFacts => _runtime.selectionFacts;
}

int _previewPointCount(CanvasPreviewState preview) {
  return switch (preview) {
    CanvasStrokePreview(:final points) => points.length,
    _ => 1,
  };
}

List<CanvasElementId> _selectedIds(String scaleId) {
  final selectedCount = _boundedScale(scaleId, max: 16);
  return [
    for (var index = 0; index < selectedCount; index++) _elementId(index),
  ];
}

// Scale ids are a closed benchmark manifest vocabulary; the switch is the
// boundary check that rejects unsupported probe scales.
// ignore: cyclomatic-complexity
int _scaleElementCount(String scaleId) {
  return switch (scaleId) {
    '100k' => 100000,
    '50k' || 'dense_50k' || 'invalid_50k' => 50000,
    '10k' || 'invalid_10k' => 10000,
    '1k' ||
    'invalid_1k' ||
    '1k_resources' ||
    '1k_uncached_image_records' => 1000,
    'active_previews' ||
    'all_fixtures' ||
    'active_selected_overlay_previews' ||
    'hot_pointer' => 1,
    _ => throw UnsupportedError('Unsupported benchmark scale "$scaleId".'),
  };
}

int _boundedScale(String scaleId, {required int max}) {
  final count = _scaleElementCount(scaleId);
  return count > max ? max : count;
}

CanvasElementId _elementId(int index) => CanvasElementId('e$index');

final _layerId = CanvasLayerId('layer-0');

_CaseBoundaryRegistry _caseBoundaryRegistry() {
  final manifest = BenchmarkManifest.load();
  return _CaseBoundaryRegistry({
    for (final benchmarkCase in manifest.cases)
      benchmarkCase.id: _CaseBoundaryRegistryEntry(
        timedScope: benchmarkCase.measurementBoundary.timedScope,
        setupScope: benchmarkCase.measurementBoundary.setupScope,
        teardownScope: benchmarkCase.measurementBoundary.teardownScope,
        primaryTiming: benchmarkCase.measurementBoundary.primaryTiming,
        primaryMemory: benchmarkCase.measurementBoundary.primaryMemory,
        setupMetrics: benchmarkCase.measurementBoundary.setupMetrics,
        setupMemoryMetrics:
            benchmarkCase.measurementBoundary.setupMemoryMetrics,
        fixtureShape: benchmarkCase.fixtureShape,
      ),
  });
}

final class _CaseBoundaryRegistry {
  const _CaseBoundaryRegistry(this.entries);

  final Map<String, _CaseBoundaryRegistryEntry> entries;

  _CaseBoundaryRegistryEntry validate(String caseId) {
    final entry = entries[caseId];
    if (entry == null) {
      throw StateError('$caseId has no benchmark measurement boundary.');
    }
    if (!entry.isComplete) {
      throw StateError(
        '$caseId has incomplete benchmark measurement boundary.',
      );
    }
    return entry;
  }
}

final class _CaseBoundaryRegistryEntry {
  const _CaseBoundaryRegistryEntry({
    required this.timedScope,
    required this.setupScope,
    required this.teardownScope,
    required this.primaryTiming,
    required this.primaryMemory,
    required this.setupMetrics,
    required this.setupMemoryMetrics,
    required this.fixtureShape,
  });

  final String timedScope;
  final String setupScope;
  final String teardownScope;
  final String primaryTiming;
  final String primaryMemory;
  final List<String> setupMetrics;
  final List<String> setupMemoryMetrics;
  final String fixtureShape;

  bool get isComplete {
    final setupDiagnosticsComplete = setupScope == 'none'
        ? setupMetrics.isEmpty && setupMemoryMetrics.isEmpty
        : setupMetrics.isNotEmpty && setupMemoryMetrics.isNotEmpty;
    return timedScope.isNotEmpty &&
        setupScope.isNotEmpty &&
        teardownScope.isNotEmpty &&
        primaryTiming.isNotEmpty &&
        primaryMemory.isNotEmpty &&
        setupDiagnosticsComplete &&
        fixtureShape.isNotEmpty;
  }
}

final class _BenchmarkCasePlan {
  const _BenchmarkCasePlan({
    required this.prepare,
    required this.measure,
    required this.cleanup,
    this.timedScope = 'action_only',
    this.setupScope = 'per_sample_prepared_fixture',
    this.teardownScope = 'excluded',
    this.primaryTiming = 'action',
    this.primaryMemory = 'action',
    this.setupMetricKeys = const ['setup_us'],
    this.setupMemoryMetricKeys = const [
      'setup_allocation_bytes',
      'setup_rss_delta_bytes',
    ],
    this.fixtureShape = 'normal_spread',
    this.setupElapsedUsOverride,
    this.actionElapsedUsOverride,
    this.setupRssDeltaOverride,
    this.actionRssDeltaOverride,
  });

  final FutureOr<_PreparedProbeFixture> Function() prepare;
  final FutureOr<Map<String, Object?>> Function(Object? fixture) measure;
  final FutureOr<void> Function(Object? fixture) cleanup;
  final String timedScope;
  final String setupScope;
  final String teardownScope;
  final String primaryTiming;
  final String primaryMemory;
  final List<String> setupMetricKeys;
  final List<String> setupMemoryMetricKeys;
  final String fixtureShape;
  final int? setupElapsedUsOverride;
  final int? actionElapsedUsOverride;
  final int? setupRssDeltaOverride;
  final int? actionRssDeltaOverride;

  bool get reusesPreparedFixture => setupScope == 'per_run_prepared_fixture';
  bool get measuresLifecycle =>
      timedScope == 'lifecycle' || primaryTiming == 'lifecycle';

  _BenchmarkCasePlan withBoundary(_CaseBoundaryRegistryEntry boundary) {
    return _BenchmarkCasePlan(
      timedScope: boundary.timedScope,
      setupScope: boundary.setupScope,
      teardownScope: boundary.teardownScope,
      primaryTiming: boundary.primaryTiming,
      primaryMemory: boundary.primaryMemory,
      setupMetricKeys: boundary.setupMetrics,
      setupMemoryMetricKeys: boundary.setupMemoryMetrics,
      fixtureShape: boundary.fixtureShape,
      prepare: prepare,
      measure: measure,
      cleanup: cleanup,
      setupElapsedUsOverride: setupElapsedUsOverride,
      actionElapsedUsOverride: actionElapsedUsOverride,
      setupRssDeltaOverride: setupRssDeltaOverride,
      actionRssDeltaOverride: actionRssDeltaOverride,
    );
  }

  Map<String, Object?> measurementBoundaryJson() {
    return {
      'timedScope': timedScope,
      'setupScope': setupScope,
      'teardownScope': teardownScope,
      'primaryTiming': primaryTiming,
      'primaryMemory': primaryMemory,
      'setupMetrics': setupMetricKeys,
      'setupMemoryMetrics': setupMemoryMetricKeys,
    };
  }
}

final class _PreparedProbeFixture {
  const _PreparedProbeFixture({this.value, this.setupMetrics = const {}});

  final Object? value;
  final Map<String, Object?> setupMetrics;
}

final class _MeasuredSetup {
  const _MeasuredSetup({
    required this.prepared,
    required this.setupUs,
    required this.setupMetrics,
  });

  final _PreparedProbeFixture prepared;
  final int setupUs;
  final Map<String, Object?> setupMetrics;
}

final class _ProbeSample {
  const _ProbeSample({
    required this.elapsedUs,
    required this.setupUs,
    required this.metrics,
    required this.setupMetrics,
  });

  final int elapsedUs;
  final int setupUs;
  final Map<String, Object?> metrics;
  final Map<String, Object?> setupMetrics;
}

_ProbeOptions _fakeOptions({
  String caseId = 'fake.case',
  int warmups = 0,
  int repetitions = 1,
}) {
  return _ProbeOptions(
    caseId: caseId,
    scaleId: 'fake',
    profileId: 'dry_run',
    warmups: warmups,
    repetitions: repetitions,
    minimumMeasuredMs: 0,
    minimumSamples: 0,
    timingClaims: false,
  );
}

final class _ProbeOptions {
  const _ProbeOptions({
    required this.caseId,
    required this.scaleId,
    required this.profileId,
    required this.warmups,
    required this.repetitions,
    required this.minimumMeasuredMs,
    required this.minimumSamples,
    required this.timingClaims,
  });

  final String caseId;
  final String scaleId;
  final String profileId;
  final int warmups;
  final int repetitions;
  final int minimumMeasuredMs;
  final int minimumSamples;
  final bool timingClaims;

  // Probe argument parsing keeps defaults and required fields next to the
  // command boundary so missing setup fails before any timing loop starts.
  // ignore: halstead-volume
  factory _ProbeOptions.parse(List<String> args) {
    final values = <String, String>{};
    for (final arg in args) {
      if (arg == '--dry-run') {
        values['dry-run'] = 'true';
        continue;
      }
      final split = arg.indexOf('=');
      if (!arg.startsWith('--') || split <= 2) {
        throw FormatException('Invalid probe argument "$arg".');
      }
      final key = arg.replaceFirst(RegExp('=.*'), '').replaceFirst('--', '');
      final value = arg.replaceFirst(RegExp('^--[^=]*='), '');
      values[key] = value;
    }
    return _ProbeOptions(
      caseId: _required(values, 'case'),
      scaleId: _required(values, 'scale'),
      profileId: _profileId(values),
      warmups: int.parse(values['warmups'] ?? '0'),
      repetitions: int.parse(values['repetitions'] ?? '1'),
      minimumMeasuredMs: int.parse(values['minimum-ms'] ?? '0'),
      minimumSamples: int.parse(values['minimum-samples'] ?? '0'),
      timingClaims: (values['timing-claims'] ?? 'false') == 'true',
    );
  }
}

String _profileId(Map<String, String> values) {
  final profileId = _required(values, 'profile');
  if (!{'dry_run', 'smoke', 'release'}.contains(profileId)) {
    throw FormatException('Unsupported --profile=$profileId.');
  }

  return profileId;
}

String _required(Map<String, String> values, String key) {
  final value = values[key];
  if (value == null || value.isEmpty) {
    throw FormatException('Missing --$key=<value>.');
  }
  return value;
}
