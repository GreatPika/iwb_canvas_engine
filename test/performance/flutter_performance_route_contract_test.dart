import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';

const _scenarioSourcePath = 'example/lib/perf/performance_scenario.dart';
const _integrationTestPath =
    'example/integration_test/perf_canvas_surface_test.dart';

const _redesignedGroups = {
  'load_document.100k': [
    'setup.fixture_json',
    'warm.load_document',
    'steady.load_document',
  ],
  'first_canvas_frame.50k': [
    'setup.preloaded_runtime',
    'warm.first_canvas_frame',
    'steady.first_canvas_frame',
  ],
  'camera_pan.100k': [
    'setup.loaded_document',
    'warm.camera_pan',
    'steady.camera_pan',
  ],
  'selection_move.50k': [
    'setup.loaded_selected_document',
    'warm.selection_move',
    'steady.selection_move',
  ],
  'marquee_select.50k': [
    'setup.loaded_document',
    'warm.marquee_select',
    'steady.marquee_select',
  ],
  'json_export.50k': [
    'setup.loaded_document',
    'warm.json_export',
    'steady.json_export',
  ],
  'eraser_dense_50k': [
    'setup.loaded_draw_mode_document',
    'warm.eraser_dense',
    'steady.eraser_dense',
  ],
};

const _singleCurrentBehaviorGroups = [
  'load_document.1k',
  'load_document.10k',
  'load_document.50k',
  'camera_pan.50k',
  'selection_tap.10k',
  'selection_move.10k',
  'pencil_draw.10k',
  'marker_draw.10k',
  'line_two_tap.50k',
  'eraser_normal.50k',
  'context_delete.10k',
  'text_edit.open_commit',
  'text_style_change.10k',
  'resource_image_cold',
  'resource_image_warm',
  'resource_mark_dirty',
  'missing_resource',
  'surface_runtime_swap',
  'dispose_during_preview',
];

const _retiredRouteKeys = [
  'startup',
  'benchmark',
  'SceneController',
  'SceneView',
  'CanvasMode',
  'DrawTool',
];

void main() {
  _registerDescriptorCatalogContractTest();
  _registerIntegrationRouteContractTest();
  _registerTracedRunnerContractTest();
  _registerRouteSourceGuardrailTest();
}

void _registerDescriptorCatalogContractTest() {
  test('executable descriptor catalog owns the fixed phase catalog', () async {
    expect(_runtimeCatalogContractTestSource(), contains('run.runTraced('));
    await _expectExecutableCatalogRuntime();
  });
}

Future<void> _expectExecutableCatalogRuntime() async {
  final runtimeTest = File(
    'example/test/.performance_catalog_contract_runtime_test.dart',
  );
  runtimeTest.writeAsStringSync(_runtimeCatalogContractTestSource());
  addTearDown(() {
    if (runtimeTest.existsSync()) {
      runtimeTest.deleteSync();
    }
  });

  final result = await Process.run('flutter', [
    'test',
    'test/.performance_catalog_contract_runtime_test.dart',
  ], workingDirectory: 'example');

  expect(
    result.exitCode,
    0,
    reason: [
      result.stdout,
      result.stderr,
    ].where((output) => output.toString().isNotEmpty).join('\n'),
  );
}

void _expectPublicImportBoundary(String source) {
  expect(source, contains("package:iwb_canvas_engine/iwb_canvas_engine.dart"));
  expect(source, isNot(contains("package:iwb_canvas_engine/src/")));
}

String _runtimeCatalogContractTestSource() {
  final redesignedGroupsJson = jsonEncode(_redesignedGroups);
  final singleGroupsJson = jsonEncode(_singleCurrentBehaviorGroups);
  return '''
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iwb_canvas_engine_example/perf/performance_host.dart';
import 'package:iwb_canvas_engine_example/perf/performance_scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('runtime performance descriptor catalog matches route contract', () {
    final redesignedGroups = (jsonDecode(r'$redesignedGroupsJson')
            as Map<String, dynamic>)
        .map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>).cast<String>(),
      ),
    );
    final singleGroups = (jsonDecode(r'$singleGroupsJson') as List<dynamic>)
        .cast<String>();
    final groupsById = {
      for (final group in allPerformanceScenarioActionGroups) group.id: group,
    };

    expect(allPerformanceScenarioActionGroups, hasLength(26));
    expect(groupsById.keys.toSet(), {
      ...redesignedGroups.keys,
      ...singleGroups,
    });

    for (final entry in redesignedGroups.entries) {
      final group = groupsById[entry.key]!;
      expect(group.migration, 'redesigned', reason: entry.key);
      expect(group.phases.map((phase) => '\${phase.kind}.\${phase.name}'),
          entry.value);
      expect(group.phases.map((phase) => phase.kind).toSet(),
          {'setup', 'warm', 'steady'});
      expect(group.phases.singleWhere((phase) => phase.kind == 'setup').repeats,
          1);
      expect(group.phases.singleWhere((phase) => phase.kind == 'warm').repeats,
          1);
      expect(group.phases.singleWhere((phase) => phase.kind == 'steady').repeats,
          5);
    }

    for (final groupId in singleGroups) {
      final group = groupsById[groupId]!;
      expect(group.migration, 'single.current_behavior', reason: groupId);
      expect(group.phases, hasLength(1), reason: groupId);
      final phase = group.phases.single;
      expect(phase.kind, 'single', reason: groupId);
      expect(phase.name, 'current_behavior', reason: groupId);
      expect(phase.repeats, 1, reason: groupId);
    }

    final allowedKinds = {'setup', 'warm', 'steady', 'single'};
    final reportKeyPattern = RegExp(
      r'^[a-z0-9_.]+__[a-z]+\\.[a-z0-9_]+__repeat_\\d{3}\$',
    );
    expect(allPerformanceScenarioActionPhaseRuns, hasLength(68));
    for (final run in allPerformanceScenarioActionPhaseRuns) {
      expect(allowedKinds, contains(run.phase.kind), reason: run.reportKey);
      expect(reportKeyPattern.hasMatch(run.reportKey), isTrue,
          reason: run.reportKey);
      expect(run.reportKey,
          '\${run.scenarioGroupId}__\${run.phaseKey}__repeat_\${run.repeat.toString().padLeft(3, '0')}');
    }
  });

  test('traced runner passes report key and settles inside trace action', () async {
    final host = PerformanceHostController();
    addTearDown(host.dispose);
    final run = allPerformanceScenarioActionPhaseRuns.singleWhere(
      (candidate) =>
          candidate.scenarioGroupId == 'load_document.1k' &&
          candidate.phaseKey == 'single.current_behavior',
    );
    final events = <String>[];
    var insideTrace = false;

    await run.runTraced(
      binding: binding,
      host: host,
      pumpFrame: ([duration = Duration.zero]) async {
        events.add('pump');
      },
      settle: () async {
        expect(insideTrace, isTrue);
        events.add('settle');
      },
      traceAction: (action, {required reportKey}) async {
        expect(reportKey, run.reportKey);
        insideTrace = true;
        events.add('traceStart');
        await action();
        events.add('traceEnd');
        insideTrace = false;
      },
    );

    expect(events.first, 'traceStart');
    expect(events, contains('pump'));
    expect(events, contains('settle'));
    expect(events.last, 'traceEnd');
  });
}
''';
}

void _registerIntegrationRouteContractTest() {
  test('integration route uses the single traced phase runner', () {
    final integrationSource = File(_integrationTestPath).readAsStringSync();

    expect(
      integrationSource,
      contains('allPerformanceScenarioActionPhaseRuns'),
    );
    expect(integrationSource, contains('phaseRun.runTraced('));
    expect(
      integrationSource,
      contains('pumpFrame: ([duration = Duration.zero])'),
    );
    expect(integrationSource, contains('PERF_SCENARIO_START'));
    expect(integrationSource, contains('PERF_SCENARIO_DONE'));
    expect(
      integrationSource,
      contains('settle: () => _settlePerformanceTraceWindow(tester)'),
    );
    expect(integrationSource, contains('tester.runAsync'));
    expect(integrationSource, isNot(contains('traceAction')));
    expect(integrationSource, isNot(contains('settle: tester.pumpAndSettle')));
    _expectTraceSettleIsBounded(integrationSource);
  });
}

void _expectTraceSettleIsBounded(String integrationSource) {
  final helperPattern = RegExp(
    r'Future<void> _settlePerformanceTraceWindow[\s\S]*?\n}\n?$',
  );
  final helperBody = helperPattern.firstMatch(integrationSource)?.group(0);

  expect(helperBody, isNotNull);
  expect(helperBody, contains('_traceSettleFrameCount'));
  expect(helperBody, contains('await tester.pump(_traceSettleFrameStep);'));
  expect(helperBody, isNot(contains('pumpAndSettle')));
  expect(helperBody, isNot(contains('endOfFrame')));
}

void _registerTracedRunnerContractTest() {
  test('traced phase runner has no fallback tracing path', () {
    final source = File(_scenarioSourcePath).readAsStringSync();

    expect(source, isNotEmpty);
    _expectNoTraceFallback(source);
  });
}

void _expectNoTraceFallback(String source) {
  expect(source, isNot(contains('.onError(')));
  expect(source, isNot(contains('Failed to connect to VM Service')));
  expect(source, isNot(contains('WithoutTimeline')));
}

void _registerRouteSourceGuardrailTest() {
  test(
    'route source guardrails reject private docs and retired route names',
    () {
      final scenarioSource = File(_scenarioSourcePath).readAsStringSync();

      expect(
        scenarioSource,
        isNot(contains('docs/verification/performance.md')),
      );
      expect(scenarioSource, isNot(contains('.md')));
      _expectPublicImportBoundary(scenarioSource);
      _expectNoRetiredRouteKeys(scenarioSource);
    },
  );
}

void _expectNoRetiredRouteKeys(String source) {
  for (final key in _retiredRouteKeys) {
    final pattern = RegExp(
      '(?<![A-Za-z0-9_])${RegExp.escape(key)}'
      '(?![A-Za-z0-9_])',
    );
    expect(pattern.hasMatch(source), isFalse, reason: key);
  }
}
