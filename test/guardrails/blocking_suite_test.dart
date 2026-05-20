import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/guardrail_registry.dart';

void main() {
  test(
    'runner inventories the executable blocking hard-boundary suite',
    () => expect(_blockingInventoryMatchesExpectedIds(), isTrue),
  );
  test(
    'blocking suite contains only executable inventory entries',
    () => expect(_blockingSuiteUsesInventoryEntries(), isTrue),
  );
  test('explicit guardrail selection runs one guardrail path', () async {
    expect(
      await _selectedGuardrailIds('--guardrail=api.public_exports_complete'),
      {'api.public_exports_complete'},
    );
  });
  test('api suite selection runs only api guardrails', () async {
    expect(await _selectedGuardrailIds('--suite=api'), _expectedApiIds);
  });
  test('core suite selection runs only core guardrails', () async {
    expect(await _selectedGuardrailIds('--suite=core'), _expectedCoreIds);
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

Future<Set<String>> _selectedGuardrailIds(String argument) async {
  final result = await _runGuardrails([argument]);

  if (result.exitCode != 0) {
    throw StateError('${result.stdout}\n${result.stderr}');
  }
  return _ranGuardrailIds(result);
}

Future<ProcessResult> _runGuardrails(List<String> arguments) {
  return Process.run('dart', [
    'run',
    'tool/guardrails/run.dart',
    ...arguments,
  ], workingDirectory: Directory.current.path);
}

Set<String> _ranGuardrailIds(ProcessResult result) {
  return result.stdout
      .toString()
      .split('\n')
      .where((line) => line.startsWith('ran '))
      .map((line) => line.substring('ran '.length))
      .toSet();
}

bool _setEquals(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();

  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

const _expectedApiIds = {
  'api.no_legacy_public_types',
  'api.public_exports_complete',
  'api.public_types_complete',
};

const _expectedCoreIds = {
  'core.no_legacy_imports',
  'core.import_boundaries',
  'core.no_unapproved_part_files',
  'core.no_scene_controller_shape_dependency',
  'core.no_node_spec_patch_shape_dependency',
  'core.single_runtime_root',
};

const _expectedBlockingHardBoundaryIds = {
  ..._expectedApiIds,
  ..._expectedCoreIds,
};
