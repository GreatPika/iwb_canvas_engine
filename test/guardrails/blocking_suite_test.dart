import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/guardrail_registry.dart';

void main() {
  test('runner inventories the executable blocking hard-boundary suite', () {
    expect(
      guardrailInventory().keys,
      unorderedEquals(_expectedBlockingHardBoundaryIds),
    );
    expect(
      blockingGuardrailIds(),
      unorderedEquals(_expectedBlockingHardBoundaryIds),
    );
  });

  test('blocking suite contains only executable inventory entries', () {
    expect(guardrailInventory().keys, unorderedEquals(blockingGuardrailIds()));
  });

  test('explicit guardrail selection runs one guardrail path', () async {
    final result = await _runGuardrails([
      '--guardrail=api.public_exports_complete',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('ran api.public_exports_complete'));
    expect(result.stdout, isNot(contains('ran api.public_types_complete')));
  });

  test('--changed conservatively falls back to the blocking suite', () async {
    final result = await _runGuardrails(['--changed']);

    expect(result.exitCode, 0);
    expect(
      _ranGuardrails(result.stdout as String),
      containsAll(_expectedBlockingHardBoundaryIds),
    );
  });
}

Set<String> _ranGuardrails(String stdout) {
  return stdout
      .split('\n')
      .where((line) => line.startsWith('ran '))
      .map((line) => line.substring('ran '.length))
      .toSet();
}

Future<ProcessResult> _runGuardrails(List<String> arguments) {
  return Process.run('dart', [
    'run',
    'tool/guardrails/run.dart',
    ...arguments,
  ], workingDirectory: Directory.current.path);
}

const _expectedBlockingHardBoundaryIds = {
  'api.no_legacy_public_types',
  'api.public_exports_complete',
  'api.public_types_complete',
  'core.no_legacy_imports',
  'core.import_boundaries',
  'core.no_unapproved_part_files',
  'core.no_scene_controller_shape_dependency',
  'core.no_node_spec_patch_shape_dependency',
  'core.single_runtime_root',
};
