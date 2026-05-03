@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/tool_process_test_support.dart';

void main() {
  group('tool/audit_terminal_cleanup_safety.dart', () {
    test(
      'flags terminal cleanup that depends on successful hazardous path',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeViolatingFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_terminal_cleanup_safety.dart',
            args: const <String>['lib/src/interactive/internal/violating.dart'],
          );

          expect(result.exitCode, 1, reason: result.stderr.toString());
          expect(result.stdout.toString(), contains('DrawRouter.handleUp'));
          expect(result.stdout.toString(), contains('StrokeEngine.commitOnUp'));
          expect(result.stdout.toString(), contains('cleanup-after: clear'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'stays quiet when terminal cleanup is guaranteed in finally',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCleanFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_terminal_cleanup_safety.dart',
            args: const <String>['lib/src/interactive/internal/clean.dart'],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('Terminal cleanup safety audit passed'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'stays quiet when later cleanup is unreachable after terminal return',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeEarlyReturnFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_terminal_cleanup_safety.dart',
            args: const <String>[
              'lib/src/interactive/internal/early_return.dart',
            ],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('Terminal cleanup safety audit passed'),
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
    tempPrefix: 'iwb_canvas_engine_audit_terminal_cleanup_safety_tool_test_',
    toolFiles: const <String>[
      'tool/audit_terminal_cleanup_safety.dart',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeViolatingFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/interactive/internal/violating.dart', '''
class Session {
  void clear() {}
}

class DrawRouter {
  DrawRouter(this.session, this.strokeEngine);

  final Session session;
  final StrokeEngine strokeEngine;

  void handleUp() {
    strokeEngine.commitOnUp();
    session.clear();
  }
}

class StrokeEngine {
  void commitOnUp() {
    _emitCommit();
    clear();
  }

  void _emitCommit() {
    commitDrawStroke();
  }

  void commitDrawStroke() {}

  void clear() {}
}
''');
}

void _writeCleanFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/interactive/internal/clean.dart', '''
class Session {
  void clear() {}
}

class DrawRouter {
  DrawRouter(this.session, this.strokeEngine);

  final Session session;
  final StrokeEngine strokeEngine;

  void handleUp() {
    try {
      strokeEngine.commitOnUp();
    } finally {
      session.clear();
    }
  }
}

class StrokeEngine {
  void commitOnUp() {
    try {
      _emitCommit();
    } finally {
      clear();
    }
  }

  void _emitCommit() {
    commitDrawStroke();
  }

  void commitDrawStroke() {}

  void clear() {}
}
''');
}

void _writeEarlyReturnFixture(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/early_return.dart',
    '''
class Router {
  void handleUp(bool shouldCommit) {
    if (shouldCommit) {
      _commit();
      return;
    }

    clear();
  }

  void _commit() {
    commitDrawStroke();
  }

  void commitDrawStroke() {}

  void clear() {}
}
''',
  );
}
