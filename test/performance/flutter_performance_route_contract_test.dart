import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';

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

const _redesignedPhaseMetadata = {
  'load_document.100k': {
    'warm.load_document': {
      'canonicalPreparation': 'empty_runtime_with_prepared_json_fixture',
      'resetReason': 'load_writes_document_state',
      'measuredAction': 'load_document',
    },
    'steady.load_document': {
      'canonicalPreparation': 'empty_runtime_with_prepared_json_fixture',
      'resetReason': 'load_writes_document_state',
      'measuredAction': 'load_document',
    },
  },
  'first_canvas_frame.50k': {
    'warm.first_canvas_frame': {
      'canonicalPreparation':
          'preloaded_runtime_not_rendered_by_measured_surface',
      'resetReason': 'first_frame_cost_disappears_after_render',
      'measuredAction': 'first_canvas_frame',
    },
    'steady.first_canvas_frame': {
      'canonicalPreparation':
          'preloaded_runtime_not_rendered_by_measured_surface',
      'resetReason': 'first_frame_cost_disappears_after_render',
      'measuredAction': 'first_canvas_frame',
    },
  },
  'camera_pan.100k': {
    'warm.camera_pan': {
      'canonicalPreparation': 'loaded_document_camera_origin_settled_surface',
      'resetReason': 'pan_accumulates_camera_offset',
      'measuredAction': 'camera_pan',
    },
    'steady.camera_pan': {
      'canonicalPreparation': 'loaded_document_camera_origin_settled_surface',
      'resetReason': 'pan_accumulates_camera_offset',
      'measuredAction': 'camera_pan',
    },
  },
  'selection_move.50k': {
    'warm.selection_move': {
      'canonicalPreparation': 'loaded_selected_document_original_geometry',
      'resetReason': 'move_translates_selected_geometry',
      'measuredAction': 'selection_move',
    },
    'steady.selection_move': {
      'canonicalPreparation': 'loaded_selected_document_original_geometry',
      'resetReason': 'move_translates_selected_geometry',
      'measuredAction': 'selection_move',
    },
  },
  'marquee_select.50k': {
    'warm.marquee_select': {
      'canonicalPreparation':
          'loaded_document_move_mode_no_selection_settled_surface',
      'resetReason': 'marquee_commit_replaces_selection',
      'measuredAction': 'marquee_select',
    },
    'steady.marquee_select': {
      'canonicalPreparation':
          'loaded_document_move_mode_no_selection_settled_surface',
      'resetReason': 'marquee_commit_replaces_selection',
      'measuredAction': 'marquee_select',
    },
  },
  'json_export.50k': {
    'warm.json_export': {
      'canonicalPreparation': 'loaded_document_stable_order_no_pending_edit',
      'resetReason': 'export_reset_keeps_repeats_comparable',
      'measuredAction': 'json_export',
    },
    'steady.json_export': {
      'canonicalPreparation': 'loaded_document_stable_order_no_pending_edit',
      'resetReason': 'export_reset_keeps_repeats_comparable',
      'measuredAction': 'json_export',
    },
  },
  'eraser_dense_50k': {
    'warm.eraser_dense': {
      'canonicalPreparation':
          'loaded_draw_mode_eraser_document_without_prior_erasure',
      'resetReason': 'eraser_removes_elements',
      'measuredAction': 'eraser_dense',
    },
    'steady.eraser_dense': {
      'canonicalPreparation':
          'loaded_draw_mode_eraser_document_without_prior_erasure',
      'resetReason': 'eraser_removes_elements',
      'measuredAction': 'eraser_dense',
    },
  },
};

void main() {
  _registerDescriptorCatalogContractTest();
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

String _runtimeCatalogContractTestSource() {
  final redesignedGroupsJson = jsonEncode(_redesignedGroups);
  final singleGroupsJson = jsonEncode(_singleCurrentBehaviorGroups);
  final redesignedPhaseMetadataJson = jsonEncode(_redesignedPhaseMetadata);
  return '''
import 'dart:convert';

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
    final expectedMetadata = (jsonDecode(r'$redesignedPhaseMetadataJson')
            as Map<String, dynamic>)
        .map(
      (groupId, phases) => MapEntry(
        groupId,
        (phases as Map<String, dynamic>).map(
          (phaseKey, metadata) => MapEntry(
            phaseKey,
            (metadata as Map<String, dynamic>).cast<String, String>(),
          ),
        ),
      ),
    );
    final groupsById = {
      for (final group in catalog.performanceScenarioCatalogGroups)
        group.id: group,
    };

    expect(catalog.performanceScenarioCatalogGroups, hasLength(26));
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
      final expectedGroupMetadata = expectedMetadata[entry.key]!;
      final actualGroupMetadata = {
        for (final phase in group.phases.where((phase) => phase.kind != 'setup'))
          '\${phase.kind}.\${phase.name}': {
            'canonicalPreparation': phase.canonicalPreparation,
            'resetReason': phase.resetReason,
            'measuredAction': phase.measuredAction,
          },
      };
      expect(actualGroupMetadata, expectedGroupMetadata, reason: entry.key);
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
    expect(catalog.performanceScenarioCatalogRuns, hasLength(68));
    expect(allPerformanceScenarioActionPhaseRuns, hasLength(68));
    expect(
      allPerformanceScenarioActionPhaseRuns.map((run) => run.reportKey),
      catalog.performanceScenarioCatalogRuns.map((run) => run.reportKey),
    );
    for (final run in catalog.performanceScenarioCatalogRuns) {
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
      'PERF_SCENARIO_START \${run.reportKey}',
      'PERF_SCENARIO_DONE \${run.reportKey}',
    ]);
    expect(traceReports, [run.reportKey]);
    expect(find.byKey(performanceHostSurfaceKey), findsOneWidget);
  });
}
''';
}
