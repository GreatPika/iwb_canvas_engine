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

bool _blockingInventoryMatchesExpectedIds() {
  return _setEquals(guardrailInventory().keys, blockingGuardrailIds()) &&
      _setEquals(blockingGuardrailIds(), suiteGuardrailIds('blocking'));
}

bool _inventoryEntriesHaveRunnerRoutes() {
  return guardrailInventory().keys.every((id) => guardrailRouteFor(id) != null);
}

Future<bool> _badSuiteSelectionsFail() async {
  final results = await Future.wait([
    _runGuardrails(['--suite=interaction']),
    _runGuardrails(['--suite=runner-structural']),
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
