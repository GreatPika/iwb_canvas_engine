@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/tool_process_test_support.dart';

void main() {
  group('tool/audit_validated_backing_structure.dart', () {
    test(
      'flags validated backing builders that skip matching structure validator',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeViolatingFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_validated_backing_structure.dart',
          );

          expect(result.exitCode, 1, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('boardBackingFromValidated'),
          );
          expect(
            result.stdout.toString(),
            contains('boardValidateBoardBackingStructure'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'allows builders that call the matching structure validator',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCleanFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_validated_backing_structure.dart',
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('Validated backing structure audit passed'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'allows builders that reach structure validator through helper hop',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeHelperHopFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_validated_backing_structure.dart',
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'ignores local value builders when no structure validator exists',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeLocalOnlyFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_validated_backing_structure.dart',
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_audit_validated_backing_structure_test_',
    toolFiles: const <String>[
      'tool/audit_validated_backing_structure.dart',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeViolatingFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/contract/sample_backing.dart', '''
final class BoardBacking {
  BoardBacking();
}

void boardValidateBoardBackingStructure(BoardBacking backing) {}

BoardBacking boardBackingFromValidated() {
  return BoardBacking();
}
''');
}

void _writeCleanFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/contract/sample_backing.dart', '''
final class SceneSnapshotBacking {
  SceneSnapshotBacking();
}

void sceneValidateSceneSnapshotBackingStructure(SceneSnapshotBacking backing) {}

SceneSnapshotBacking sceneSnapshotBackingFromValidated() {
  final backing = SceneSnapshotBacking();
  sceneValidateSceneSnapshotBackingStructure(backing);
  return backing;
}
''');
}

void _writeHelperHopFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/contract/sample_backing.dart', '''
final class BoardBacking {
  BoardBacking();
}

void validateBoardBackingStructure(BoardBacking backing) {}

BoardBacking boardBackingFromValidated() {
  return _boardBackingWithStructureValidation(BoardBacking());
}

BoardBacking _boardBackingWithStructureValidation(BoardBacking backing) {
  validateBoardBackingStructure(backing);
  return backing;
}
''');
}

void _writeLocalOnlyFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/contract/sample_backing.dart', '''
final class NodeSnapshotBacking {
  NodeSnapshotBacking();
}

NodeSnapshotBacking nodeSnapshotBackingFromValidated() {
  return NodeSnapshotBacking();
}
''');
}
