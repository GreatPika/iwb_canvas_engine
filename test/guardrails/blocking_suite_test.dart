import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_registry.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';

// The runner inventory proof stays in one suite so expected ids, suite routing,
// and command selection cannot drift through separate metric-shaped tests.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void main() {
  test(
    'guardrail inventory entries have executable runner routes',
    () => expect(_inventoryEntriesHaveRunnerRoutes(), isTrue),
  );
  test(
    'default runner selection routes executable blocking guardrails',
    () async {
      expect(await _selectedGuardrailIds(), blockingGuardrailIds());
    },
  );
  test('explicit guardrail selection routes one guardrail path', () async {
    expect(
      await _selectedGuardrailIds(['--guardrail=api.public_exports_complete']),
      {'api.public_exports_complete'},
    );
  });
  test('api suite selection routes only api guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=api']),
      suiteGuardrailIds('api'),
    );
  });
  test('core suite selection routes only core guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=core']),
      suiteGuardrailIds('core'),
    );
  });
  test('codec suite selection routes only codec guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=codec']),
      suiteGuardrailIds('codec'),
    );
  });
  test(
    'diagnostics suite selection routes only diagnostics guardrails',
    () async {
      expect(
        await _selectedGuardrailIds(['--suite=diagnostics']),
        suiteGuardrailIds('diagnostics'),
      );
    },
  );
  test('store suite selection routes only store guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=store']),
      suiteGuardrailIds('store'),
    );
  });
  test(
    'projection suite selection routes only projection guardrails',
    () async {
      expect(
        await _selectedGuardrailIds(['--suite=projection']),
        suiteGuardrailIds('projection'),
      );
    },
  );
  test('selection suite selection routes only selection guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=selection']),
      suiteGuardrailIds('selection'),
    );
  });
  test(
    'interaction suite selection routes only interaction guardrails',
    () async {
      expect(
        await _selectedGuardrailIds(['--suite=interaction']),
        suiteGuardrailIds('interaction'),
      );
    },
  );
  test('edit suite selection routes only edit guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=edit']),
      suiteGuardrailIds('edit'),
    );
  });
  test('events suite selection routes only event guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=events']),
      suiteGuardrailIds('events'),
    );
  });
  test('load suite selection routes only load guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=load']),
      suiteGuardrailIds('load'),
    );
  });
  test('frame suite selection routes only frame guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=frame']),
      suiteGuardrailIds('frame'),
    );
  });
  test('cache suite selection routes only cache guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=cache']),
      suiteGuardrailIds('cache'),
    );
  });
  test('preview suite selection routes only preview guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=preview']),
      suiteGuardrailIds('preview'),
    );
  });
  test('tools suite selection routes only tools guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=tools']),
      suiteGuardrailIds('tools'),
    );
  });
  test('selection and move guardrails are blocking', () {
    expect(
      blockingGuardrailIds(),
      containsAll({
        'load.prepares_before_interrupt',
        'load.success_interrupts_before_install',
        'interaction.no_concrete_store_imports',
        'interaction.no_concrete_selection_imports',
        'interaction.read_port_immutable_facts',
        'interaction.no_command_facts_import',
        'interaction.cleanup_coordinator_dependency_bans',
        'interaction.pointer_cleanup_coordinator_only',
        'interaction.no_resolver_on_cancel_paths',
        'interaction.no_stale_terminal_commit',
        'interaction.text_edit_stale_commit_guard',
        'events.action_after_state_order',
        'preview.selected_move_main_only',
        'preview.marquee_overlay_only',
        'tools.public_port_behavior',
      }),
    );
  });
  test('frame, cache, and preview guardrails are blocking', () {
    expect(
      blockingGuardrailIds(),
      containsAll({
        'api.preview_state_sealed_union_publicly_readable',
        'frame.committed_facts_via_frame_facts_port',
        'frame.no_global_scene_sort',
        'frame.paint_plan_excludes_preview_delta',
        'frame.paint_plan_excludes_selection_state',
        'text.single_measured_layout_source',
        'text.no_overlay_textpainter_measurement',
        'surface.editable_text_surface_only',
        'cache.keys_use_next_revisions_only',
        'cache.background_grid_not_element_visual',
        'cache.hot_caches_have_capacity_eviction',
      }),
    );
  });
  test('shared proof files run once for all covered guardrail ids', () async {
    final proofRuns = <String, int>{};
    final result = await runGuardrailsWithProofRunner(
      [
        'api.resource_source_app_key_publicly_readable',
        'api.preview_state_sealed_union_publicly_readable',
      ],
      runDartTest: (_, path) async {
        proofRuns[path] = (proofRuns[path] ?? 0) + 1;

        return 0;
      },
    );

    expect(result.exitCode, 0);
    expect(result.ranGuardrailIds, [
      'api.resource_source_app_key_publicly_readable',
      'api.preview_state_sealed_union_publicly_readable',
    ]);
    expect(proofRuns, {
      'test/api_contract/public_readable_union_variants_test.dart': 1,
    });
  });
  test('public integration guardrail runs prepared vector boundary proof', () async {
    final proofRuns = <String>[];

    final result = await runGuardrailsWithProofRunner(
      ['api.integration_surface_complete'],
      runDartTest: (_, path) async {
        proofRuns.add(path);

        return 0;
      },
    );

    expect(result.exitCode, 0);
    expect(proofRuns, [
      'test/api_contract/public_integration_compile_fixture_test.dart',
      'test/api_contract/prepared_vector_public_api_test.dart',
    ]);
  });
  for (final scanCase in _runnerStructuralScanCases) {
    test('${scanCase.id} runs proof tests before structural scan', () async {
      await expectLater(_expectProofBeforeStructuralScan(scanCase), completes);
    });
  }
  test('runner structural guardrails all have structural scan proof', () {
    expect(
      _runnerStructuralScanCases.map((scanCase) => scanCase.id).toSet(),
      runnerStructuralProofGuardrailIds(),
    );
  });
  test('unknown or empty suite selection fails', () async {
    expect(await _badSuiteSelectionsFail(), isTrue);
  });
}

bool _inventoryEntriesHaveRunnerRoutes() {
  return guardrailInventory().keys.every((id) => guardrailRouteFor(id) != null);
}

Future<bool> _badSuiteSelectionsFail() async {
  final results = await Future.wait([
    _runGuardrails(['--suite=runner-structural']),
    _runGuardrails(['--suite=release']),
    _runGuardrails(['--suite=']),
  ]);

  return results.every((result) {
    return result.exitCode == 64 &&
        result.stderr.toString().contains('Unknown or empty guardrail suite');
  });
}

Future<Set<String>> _selectedGuardrailIds([
  List<String> arguments = const [],
]) async {
  final result = await _runGuardrails(arguments);

  if (result.exitCode != 0) {
    throw StateError('${result.stdout}\n${result.stderr}');
  }
  return _ranGuardrailIds(result);
}

Future<ProcessResult> _runGuardrails(
  List<String> arguments, {
  bool dryRun = true,
}) {
  return Process.run('dart', [
    'run',
    'tool/guardrails/run.dart',
    if (dryRun) '--dry-run',
    ...arguments,
  ], workingDirectory: Directory.current.path);
}

Set<String> _ranGuardrailIds(ProcessResult result) {
  return result.stdout
      .toString()
      .split('\n')
      .where((line) => line.startsWith('would run '))
      .map((line) {
        final withoutPrefix = line.replaceFirst('would run ', '');

        return withoutPrefix.split(' via ').first;
      })
      .toSet();
}

Future<void> _expectProofBeforeStructuralScan(
  _StructuralScanCase scanCase,
) async {
  final proofPaths = <String>[];
  List<String>? pathsObservedByStructuralScan;
  var violationCreated = false;

  final result = await runGuardrailsWithProofRunner(
    [scanCase.id],
    runDartTest: (_, path) async {
      proofPaths.add(path);
      violationCreated = true;

      return 0;
    },
    violationChecks: {
      scanCase.id: () async {
        pathsObservedByStructuralScan = List.of(proofPaths);

        return [
          GuardrailViolation(
            guardrailId: scanCase.id,
            path: scanCase.violationPath,
            message: 'test structural violation',
          ),
        ];
      },
    },
  );

  expect(result.exitCode, 1);
  expect(proofPaths, scanCase.proofPaths);
  expect(pathsObservedByStructuralScan, scanCase.proofPaths);
  expect(violationCreated, isTrue);
}

final class _StructuralScanCase {
  const _StructuralScanCase({
    required this.id,
    required this.proofPaths,
    required this.violationPath,
  });

  final String id;
  final List<String> proofPaths;
  final String violationPath;
}

const _runnerStructuralScanCases = [
  _StructuralScanCase(
    id: 'core.owner_dag_import_boundaries',
    proofPaths: ['test/guardrails/owner_dag_import_boundaries_test.dart'],
    violationPath: 'lib/src/runtime/bad_runner_owner_dag.dart',
  ),
  _StructuralScanCase(
    id: 'store.no_public_document_live_state',
    proofPaths: [
      'test/store/public_document_is_projection_only_test.dart',
      'test/guardrails/store_projection_checks_test.dart',
    ],
    violationPath: 'lib/src/store/bad_runner_live_document.dart',
  ),
  _StructuralScanCase(
    id: 'projection.only_explicit_read_paths',
    proofPaths: [
      'test/store/no_projection_hot_path_test.dart',
      'test/guardrails/store_projection_checks_test.dart',
      'test/guardrails/edit_sparse_routes_no_eager_projection_guardrail_test.dart',
      'test/guardrails/edit_accepted_finalization_guardrail_test.dart',
    ],
    violationPath: 'lib/src/runtime/bad_runner_projection.dart',
  ),
  _StructuralScanCase(
    id: 'selection.owner_separate_from_document',
    proofPaths: [
      'test/selection/runtime_owner_separation_test.dart',
      'test/guardrails/selection_boundary_checks_test.dart',
    ],
    violationPath: 'lib/src/runtime/bad_runner_selection.dart',
  ),
  _StructuralScanCase(
    id: 'interaction.no_concrete_store_imports',
    proofPaths: [
      'test/guardrails/import_boundaries_test.dart',
      'test/guardrails/interaction_guardrail_enforcement_test.dart',
    ],
    violationPath: 'lib/src/interaction/bad_store_import.dart',
  ),
  _StructuralScanCase(
    id: 'interaction.no_concrete_selection_imports',
    proofPaths: [
      'test/guardrails/import_boundaries_test.dart',
      'test/guardrails/interaction_guardrail_enforcement_test.dart',
    ],
    violationPath: 'lib/src/interaction/bad_selection_import.dart',
  ),
  _StructuralScanCase(
    id: 'interaction.read_port_immutable_facts',
    proofPaths: [
      'test/interaction/interaction_read_port_test.dart',
      'test/guardrails/interaction_guardrail_enforcement_test.dart',
    ],
    violationPath: 'lib/src/interaction/interaction_read_port.dart',
  ),
  _StructuralScanCase(
    id: 'interaction.no_command_facts_import',
    proofPaths: [
      'test/guardrails/import_boundaries_test.dart',
      'test/guardrails/interaction_guardrail_enforcement_test.dart',
    ],
    violationPath: 'lib/src/interaction/bad_command_facts_import.dart',
  ),
  _StructuralScanCase(
    id: 'interaction.cleanup_coordinator_dependency_bans',
    proofPaths: [
      'test/guardrails/import_boundaries_test.dart',
      'test/guardrails/interaction_guardrail_enforcement_test.dart',
    ],
    violationPath: 'lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
  ),
  _StructuralScanCase(
    id: 'interaction.pointer_cleanup_coordinator_only',
    proofPaths: [
      'test/guardrails/import_boundaries_test.dart',
      'test/interaction/pointer_tool_cleanup_coordinator_test.dart',
    ],
    violationPath: 'lib/src/runtime/bad_cleanup_caller.dart',
  ),
  _StructuralScanCase(
    id: 'interaction.text_edit_stale_commit_guard',
    proofPaths: [
      'test/interaction/text_edit_stale_commit_guard_test.dart',
      'test/guardrails/interaction_guardrail_enforcement_test.dart',
    ],
    violationPath: 'lib/src/runtime/runtime_root.dart',
  ),
  _StructuralScanCase(
    id: 'resources.resolver_boundary_owned_by_surface_session',
    proofPaths: [
      'test/guardrails/import_boundaries_test.dart',
      'test/contracts/internal_seam_shape_test.dart',
      'test/resources/resource_resolver_adapter_shape_test.dart',
    ],
    violationPath: 'lib/src/frame/bad_runner_resolver_boundary.dart',
  ),
  _StructuralScanCase(
    id: 'surface.pointer_samples_normalized_before_runtime',
    proofPaths: [
      'test/guardrails/import_boundaries_test.dart',
      'test/surface/pointer_adapter_finite_normalization_test.dart',
    ],
    violationPath: 'lib/src/surface/bad_runtime_import.dart',
  ),
  _StructuralScanCase(
    id: 'surface.interactive_false_pending_line_preserved',
    proofPaths: [
      'test/guardrails/import_boundaries_test.dart',
      'test/surface/interactive_false_pointer_routing_test.dart',
      'test/surface/interactive_false_active_session_cancel_test.dart',
      'test/surface/interactive_false_pending_line_preserved_test.dart',
      'test/surface/interactive_false_state_isolation_test.dart',
    ],
    violationPath: 'lib/src/api/canvas_runtime_surface_bridge.dart',
  ),
  _StructuralScanCase(
    id: 'text.single_measured_layout_source',
    proofPaths: [
      'test/frame/measured_text_layout_test.dart',
      'test/guardrails/text_surface_guardrail_checks_test.dart',
    ],
    violationPath: 'lib/src/geometry/geometry_policy.dart',
  ),
  _StructuralScanCase(
    id: 'text.no_overlay_textpainter_measurement',
    proofPaths: [
      'test/surface/text_editing_overlay_test.dart',
      'test/guardrails/text_surface_guardrail_checks_test.dart',
    ],
    violationPath: 'example/lib/src/canvas_text_edit_overlay.dart',
  ),
  _StructuralScanCase(
    id: 'surface.editable_text_surface_only',
    proofPaths: [
      'test/surface/text_editing_overlay_test.dart',
      'test/guardrails/text_surface_guardrail_checks_test.dart',
    ],
    violationPath: 'lib/src/runtime/runtime_root.dart',
  ),
  _StructuralScanCase(
    id: 'geometry.committed_handle_order',
    proofPaths: [
      'test/geometry/hit_policy_test.dart',
      'test/guardrails/geometry_committed_handle_order_guardrail_test.dart',
    ],
    violationPath: 'lib/src/geometry/bad_runner_scene_order.dart',
  ),
  _StructuralScanCase(
    id: 'geometry.eraser_exact_budget_no_partial',
    proofPaths: [
      'test/geometry/eraser_exact_budget_no_partial_commit_test.dart',
      'test/guardrails/geometry_eraser_exact_budget_inputs_guardrail_test.dart',
    ],
    violationPath: 'lib/src/geometry/bad_runner_eraser_budget.dart',
  ),
  _StructuralScanCase(
    id: 'spatial.no_full_clone_ordinary_edit',
    proofPaths: [
      'test/guardrails/spatial_no_full_clone_ordinary_edit_guardrail_test.dart',
    ],
    violationPath: 'lib/src/geometry/bad_runner_full_clone.dart',
  ),
  _StructuralScanCase(
    id: 'spatial.stale_candidate_rejected',
    proofPaths: [
      'test/guardrails/spatial_stale_candidate_rejected_guardrail_test.dart',
    ],
    violationPath: 'lib/src/geometry/bad_runner_stale_candidate.dart',
  ),
  _StructuralScanCase(
    id: 'spatial.fallback_budget_enforced',
    proofPaths: [
      'test/guardrails/spatial_fallback_budget_enforced_guardrail_test.dart',
    ],
    violationPath: 'lib/src/geometry/bad_runner_fallback_budget.dart',
  ),
];
