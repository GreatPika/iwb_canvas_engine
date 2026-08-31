import 'dart:io';

import 'package:test/test.dart';

void main() {
  _registerDescriptorCatalogContractTest();
}

void _registerDescriptorCatalogContractTest() {
  test(
    'executable descriptor catalog owns route composition and phase rules',
    () async {
      await expectLater(_expectExecutableCatalogRuntime(), completes);
    },
  );
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

String _runtimeCatalogContractTestSource() {
  return r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../integration_test/perf_canvas_surface_test.dart' as performance_route;
import 'package:iwb_canvas_engine_example/perf/performance_host.dart';
import 'package:iwb_canvas_engine_example/perf/performance_scenario.dart';
import 'package:iwb_canvas_engine_example/perf/performance_scenario_catalog.dart'
    as catalog;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('runtime performance descriptor catalog matches route contract', () {
    final groups = catalog.performanceScenarioCatalogGroups;
    expect(groups, isNotEmpty);
    expect(groups.map((group) => group.id).toSet(), hasLength(groups.length));

    for (final group in groups) {
      expect(group.phases.map((phase) => phase.key).toSet(),
          hasLength(group.phases.length), reason: group.id);
      switch (group.migration) {
        case 'redesigned':
          expect(group.phases.map((phase) => phase.kind),
              ['setup', 'warm', 'steady'], reason: group.id);
          final setup = group.phases[0];
          final warm = group.phases[1];
          final steady = group.phases[2];
          expect(setup.repeats, 1);
          expect(warm.repeats, 1);
          expect(steady.repeats, 5);
          expect(
            [setup.comparisonRole, warm.comparisonRole, steady.comparisonRole],
            ['setup_context', 'first_use_action', 'steady_action'],
          );
          expect(warm.canonicalPreparation, isNotEmpty);
          expect(warm.resetReason, isNotEmpty);
          expect(warm.measuredAction, isNotEmpty);
          expect(steady.canonicalPreparation, warm.canonicalPreparation);
          expect(steady.resetReason, warm.resetReason);
          expect(steady.measuredAction, warm.measuredAction);
        case 'single.current_behavior':
          expect(group.phases, hasLength(1), reason: group.id);
          final phase = group.phases.single;
          expect(phase.key, 'single.current_behavior', reason: group.id);
          expect(phase.repeats, 1, reason: group.id);
          expect(phase.comparisonRole, 'current_behavior', reason: group.id);
          expect(phase.canonicalPreparation, isNull);
          expect(phase.resetReason, isNull);
          expect(phase.measuredAction, isNull);
        default:
          fail('Unexpected migration for ${group.id}: ${group.migration}');
      }
    }

    final expectedRunKeys = [
      for (final group in groups)
        for (final phase in group.phases)
          for (var repeat = 1; repeat <= phase.repeats; repeat += 1)
            '${group.id}__${phase.key}__repeat_${repeat.toString().padLeft(3, '0')}',
    ];
    final catalogRuns = catalog.performanceScenarioCatalogRuns;
    expect(catalogRuns.map((run) => run.reportKey), expectedRunKeys);
    expect(
      allPerformanceScenarioActionPhaseRuns.map((run) => run.reportKey),
      expectedRunKeys,
    );
    final reportKeyPattern = RegExp(
      r'^[a-z0-9_.]+__[a-z]+\.[a-z0-9_]+__repeat_\d{3}$',
    );
    for (var index = 0; index < catalogRuns.length; index += 1) {
      final expected = catalogRuns[index];
      final actual = allPerformanceScenarioActionPhaseRuns[index];
      expect(reportKeyPattern.hasMatch(actual.reportKey), isTrue,
          reason: actual.reportKey);
      expect(actual.scenarioGroupId, expected.scenarioGroupId);
      expect(actual.phaseKey, expected.phaseKey);
      expect(actual.repeat, expected.repeat);
      expect(actual.phase.kind, expected.phase.kind);
      expect(actual.phase.name, expected.phase.name);
      expect(actual.phase.canonicalPreparation,
          expected.phase.canonicalPreparation);
      expect(actual.phase.resetReason, expected.phase.resetReason);
      expect(actual.phase.measuredAction, expected.phase.measuredAction);
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

  test('load document preparation pump stays outside trace action', () async {
    final host = PerformanceHostController();
    addTearDown(host.dispose);
    final run = allPerformanceScenarioActionPhaseRuns.singleWhere(
      (candidate) =>
          candidate.scenarioGroupId == 'load_document.100k' &&
          candidate.phaseKey == 'warm.load_document',
    );
    final events = <String>[];
    var insideTrace = false;

    await run.runTraced(
      binding: binding,
      host: host,
      pumpFrame: ([duration = Duration.zero]) async {
        events.add(insideTrace ? 'tracePump' : 'preparePump');
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

    expect(events.first, 'preparePump');
    expect(events.indexOf('preparePump'), lessThan(events.indexOf('traceStart')));
    expect(events, contains('tracePump'));
    expect(events.last, 'traceEnd');
  });

  testWidgets('integration route runner delegates to traced phase runs', (tester) async {
    final run = allPerformanceScenarioActionPhaseRuns.singleWhere(
      (candidate) =>
          candidate.scenarioGroupId == 'load_document.1k' &&
          candidate.phaseKey == 'single.current_behavior',
    );
    final routeLog = <String>[];
    final traceReports = <String>[];

    await performance_route.runFlutterPerformanceScenarioCatalog(
      binding: binding,
      tester: tester,
      options: performance_route.FlutterPerformanceRouteOptions(
        phaseRuns: [run],
        log: routeLog.add,
        traceAction: (action, {required reportKey}) async {
          expect(reportKey, run.reportKey);
          traceReports.add(reportKey);
          await action();
        },
        traceSettleFrameCount: 1,
        postSettleRasterDelay: Duration.zero,
      ),
    );

    expect(routeLog, [
      'PERF_SCENARIO_START ${run.reportKey}',
      'PERF_SCENARIO_DONE ${run.reportKey}',
    ]);
    expect(traceReports, [run.reportKey]);
    expect(find.byKey(performanceHostSurfaceKey), findsOneWidget);
  });
}
''';
}
