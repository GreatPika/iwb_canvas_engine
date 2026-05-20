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

  test('api suite selection runs only api guardrails', () async {
    final result = await _runGuardrails(['--suite=api']);

    expect(result.exitCode, 0);
    expect(_ranGuardrailIds(result), unorderedEquals(_expectedApiIds));
  });

  test('core suite selection runs only core guardrails', () async {
    final result = await _runGuardrails(['--suite=core']);

    expect(result.exitCode, 0);
    expect(_ranGuardrailIds(result), unorderedEquals(_expectedCoreIds));
  });

  test('unknown or empty suite selection fails', () async {
    for (final argument in ['--suite=interaction', '--suite=']) {
      final result = await _runGuardrails([argument]);

      expect(result.exitCode, 64, reason: argument);
      expect(
        result.stderr,
        contains('Unknown or empty guardrail suite'),
        reason: argument,
      );
    }
  });
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
