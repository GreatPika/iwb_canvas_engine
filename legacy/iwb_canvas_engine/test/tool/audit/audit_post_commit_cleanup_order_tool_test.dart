@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/tool_process_test_support.dart';

void main() {
  group('tool/audit_post_commit_cleanup_order.dart', () {
    test('flags cleanup that sits after post-commit side effects', () async {
      final sandbox = await _createSandbox();
      try {
        _writeViolatingFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'audit_post_commit_cleanup_order.dart',
          args: const <String>['lib/src/interactive/internal/violating.dart'],
        );

        expect(result.exitCode, 1, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('StrokeEngine.commitOnUp'));
        expect(result.stdout.toString(), contains('Router.handleUp'));
        expect(
          result.stdout.toString(),
          contains('cleanup-after: clear, resetGestureState'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('stays quiet when cleanup is guaranteed in finally', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCleanFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'audit_post_commit_cleanup_order.dart',
          args: const <String>['lib/src/interactive/internal/clean.dart'],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('Post-commit cleanup order audit passed'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_audit_post_commit_cleanup_order_tool_test_',
    toolFiles: const <String>[
      'tool/audit_post_commit_cleanup_order.dart',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeViolatingFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/interactive/internal/violating.dart', '''
class Router {
  Router(this.strokeEngine);

  final StrokeEngine strokeEngine;

  void handleUp() {
    strokeEngine.commitOnUp();
    clear();
    resetGestureState();
  }

  void clear() {}

  void resetGestureState() {}
}

class StrokeEngine {
  void commitOnUp() {
    final id = commitDrawStroke();
    emitStrokeCommit(id);
    clear();
  }

  int commitDrawStroke() {
    return 1;
  }

  void emitStrokeCommit(int id) {}

  void clear() {}
}
''');
}

void _writeCleanFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/interactive/internal/clean.dart', '''
class StrokeEngine {
  void commitOnUp() {
    try {
      final id = commitDrawStroke();
      emitStrokeCommit(id);
    } finally {
      clear();
    }
  }

  int commitDrawStroke() {
    return 1;
  }

  void emitStrokeCommit(int id) {}

  void clear() {}
}
''');
}
