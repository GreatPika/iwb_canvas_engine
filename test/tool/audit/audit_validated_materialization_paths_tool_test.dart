@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/tool_process_test_support.dart';

void main() {
  group('tool/audit_validated_materialization_paths.dart', () {
    test('flags direct raw materialization from validated wrapper', () async {
      final sandbox = await _createSandbox();
      try {
        _writeViolatingFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'audit_validated_materialization_paths.dart',
          args: const <String>['lib/src/contract/internal/sample_paths.dart'],
        );

        expect(result.exitCode, 1, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('nodeSnapshotFromValidatedBacking'),
        );
        expect(
          result.stdout.toString(),
          contains('materializeNodeSnapshotForInternalUse'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'stays quiet when validated wrapper goes through helper hop',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCleanFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_validated_materialization_paths.dart',
            args: const <String>['lib/src/contract/internal/clean_paths.dart'],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('Validated materialization path audit passed'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix:
        'iwb_canvas_engine_audit_validated_materialization_paths_tool_test_',
    toolFiles: const <String>[
      'tool/audit_validated_materialization_paths.dart',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeViolatingFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/contract/internal/sample_paths.dart', '''
class NodeSnapshotBacking {}
class NodeSnapshot {}

NodeSnapshot materializeNodeSnapshotForInternalUse(
  NodeSnapshotBacking backing,
) => NodeSnapshot();

NodeSnapshot nodeSnapshotFromValidatedBacking(NodeSnapshotBacking backing) {
  return materializeNodeSnapshotForInternalUse(backing);
}
''');
}

void _writeCleanFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/contract/internal/clean_paths.dart', '''
class NodeSnapshotBacking {
  const NodeSnapshotBacking(this.value);

  final int value;
}

class NodeSnapshot {}

NodeSnapshot materializeNodeSnapshotForInternalUse(
  NodeSnapshotBacking backing,
) => NodeSnapshot();

NodeSnapshotBacking nodeSnapshotBackingFromValidated(int value) {
  return NodeSnapshotBacking(value);
}

NodeSnapshot nodeSnapshotFromValidated(int value) {
  final backing = nodeSnapshotBackingFromValidated(value);
  return materializeNodeSnapshotForInternalUse(backing);
}
''');
}
