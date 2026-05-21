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
    'runner inventories the executable blocking hard-boundary suite',
    () => expect(_blockingInventoryMatchesExpectedIds(), isTrue),
  );
  test(
    'blocking suite contains only executable inventory entries',
    () => expect(_blockingSuiteUsesInventoryEntries(), isTrue),
  );
  test(
    'default runner selection routes executable blocking guardrails',
    () async {
      expect(await _selectedGuardrailIds(), _expectedBlockingHardBoundaryIds);
    },
  );
  test('explicit guardrail selection routes one guardrail path', () async {
    expect(
      await _selectedGuardrailIds(['--guardrail=api.public_exports_complete']),
      {'api.public_exports_complete'},
    );
  });
  test('api suite selection routes only api guardrails', () async {
    expect(await _selectedGuardrailIds(['--suite=api']), _expectedApiIds);
  });
  test('core suite selection routes only core guardrails', () async {
    expect(await _selectedGuardrailIds(['--suite=core']), _expectedCoreIds);
  });
  test('codec suite selection routes only codec guardrails', () async {
    expect(await _selectedGuardrailIds(['--suite=codec']), _expectedCodecIds);
  });
  test(
    'diagnostics suite selection routes only diagnostics guardrails',
    () async {
      expect(
        await _selectedGuardrailIds(['--suite=diagnostics']),
        _expectedDiagnosticsIds,
      );
    },
  );
  test('store suite selection routes only store guardrails', () async {
    expect(await _selectedGuardrailIds(['--suite=store']), _expectedStoreIds);
  });
  test(
    'projection suite selection routes only projection guardrails',
    () async {
      expect(
        await _selectedGuardrailIds(['--suite=projection']),
        _expectedProjectionIds,
      );
    },
  );
  test('selection suite selection routes only selection guardrails', () async {
    expect(
      await _selectedGuardrailIds(['--suite=selection']),
      _expectedSelectionIds,
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
  for (final scanCase in _p4StructuralScanCases) {
    test('${scanCase.id} runs proof tests before structural scan', () async {
      await expectLater(_expectProofBeforeStructuralScan(scanCase), completes);
    });
  }
  test('P4 guardrails all have runner-level structural scan proof', () {
    expect(
      _p4StructuralScanCases.map((scanCase) => scanCase.id).toSet(),
      _p4StructuralGuardrailIds,
    );
  });
  test('unknown or empty suite selection fails', () async {
    expect(await _badSuiteSelectionsFail(), isTrue);
  });
}

bool _blockingInventoryMatchesExpectedIds() {
  return _setEquals(
        guardrailInventory().keys,
        _expectedBlockingHardBoundaryIds,
      ) &&
      _setEquals(blockingGuardrailIds(), _expectedBlockingHardBoundaryIds);
}

bool _blockingSuiteUsesInventoryEntries() {
  return _setEquals(guardrailInventory().keys, blockingGuardrailIds());
}

Future<bool> _badSuiteSelectionsFail() async {
  final results = await Future.wait([
    _runGuardrails(['--suite=interaction']),
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

Future<ProcessResult> _runGuardrails(List<String> arguments) {
  return Process.run('dart', [
    'run',
    'tool/guardrails/run.dart',
    '--dry-run',
    ...arguments,
  ], workingDirectory: Directory.current.path);
}

Set<String> _ranGuardrailIds(ProcessResult result) {
  return result.stdout
      .toString()
      .split('\n')
      .where((line) => line.startsWith('would run '))
      .map((line) {
        final withoutPrefix = line.substring('would run '.length);

        return withoutPrefix.substring(0, withoutPrefix.indexOf(' via '));
      })
      .toSet();
}

bool _setEquals(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();

  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
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

const _expectedApiIds = {
  'api.integration_surface_complete',
  'api.no_legacy_public_types',
  'api.public_exports_complete',
  'api.public_types_complete',
  'api.public_api_compiles_as_written',
  'api.resource_source_app_key_publicly_readable',
  'api.preview_state_sealed_union_publicly_readable',
  'api.exported_dartdoc_complete',
  'api.public_class_modifiers_explicit',
  'api.no_public_api_import_cycles',
  'api.public_signature_shape',
  'api.no_undefined_public_type_references',
  'api.dto_immutability',
  'api.equality_policy_explicit',
  'api.id_validation_no_extension_type_escape',
};

const _expectedCodecIds = {
  'codec.schema_v1_exact',
  'codec.known_fields_validated',
  'codec.no_runtime_side_effects',
};

const _expectedCoreIds = {
  'core.no_legacy_imports',
  'core.import_boundaries',
  'core.no_unapproved_part_files',
  'core.no_scene_controller_shape_dependency',
  'core.no_node_spec_patch_shape_dependency',
  'core.single_runtime_root',
};

const _expectedDiagnosticsIds = {
  'diagnostics.disabled_no_alloc_hot_path',
  'diagnostics.sanitized_public_projection',
};

const _expectedStoreIds = {
  'store.no_public_document_live_state',
  'projection.only_explicit_read_paths',
};

const _expectedProjectionIds = {'projection.only_explicit_read_paths'};

const _expectedSelectionIds = {'selection.owner_separate_from_document'};

const _p4StructuralGuardrailIds = {
  'store.no_public_document_live_state',
  'projection.only_explicit_read_paths',
  'selection.owner_separate_from_document',
};

const _p4StructuralScanCases = [
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
];

const _expectedBlockingHardBoundaryIds = {
  ..._expectedApiIds,
  ..._expectedCodecIds,
  ..._expectedCoreIds,
  ..._expectedDiagnosticsIds,
  ..._expectedStoreIds,
  ..._expectedSelectionIds,
};
