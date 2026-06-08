@Tags(['tool'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/audit_post_commit_cleanup_order.dart' as post_commit_cleanup;
import '../../tool/audit_route_expectations.dart' as route_expectations;
import '../../tool/audit_terminal_cleanup_safety.dart' as terminal_cleanup;
import '../../tool/lsp_find_thin_wrappers.dart' as thin_wrappers;
import '../../tool/trace_export_namespace.dart' as export_namespace;

void main() {
  group('repo forensics root tools', () {
    test('clone analysis runs from the root tool directory', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'iwb_canvas_engine_forensics_clones_',
      );
      try {
        _writeFile(sandbox, 'duplicates.dart', '''
int alpha(int x) {
  var value = x + 1;
  value = value * 2;
  value = value - 3;
  value = value.abs();
  value = value + 4;
  value = value * 5;
  return value;
}

int beta(int y) {
  var value = y + 1;
  value = value * 2;
  value = value - 3;
  value = value.abs();
  value = value + 4;
  value = value * 5;
  return value;
}
''');

        final result = await Process.run('dart', [
          'run',
          'tool/analysis/find_similar_clones.dart',
          '--clusters',
          sandbox.path,
          '10',
          '5',
          '3',
          '2',
          '0.4',
          '20',
        ]);

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('Found clone clusters: 1'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('thin-wrapper scan classifies forwarding methods', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'iwb_canvas_engine_forensics_wrappers_',
      );
      try {
        _writeFile(sandbox, 'lib/src/flow.dart', '''
abstract interface class Sink {
  void addNode(int value);
}

final class Wrapper {
  const Wrapper(this.sink);

  final Sink sink;

  void addNode(int value) {
    sink.addNode(value);
  }
}
''');

        final result = await thin_wrappers.runLspFindThinWrappersTool(const [
          'lib/src',
        ], root: sandbox);

        expect(result.exitCode, 0, reason: result.stderr);
        expect(
          result.stdout,
          contains('pure-forwarder: Wrapper.addNode -> addNode'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'cleanup audits require explicit targets and flag risky order',
      () async {
        final sandbox = await Directory.systemTemp.createTemp(
          'iwb_canvas_engine_forensics_cleanup_',
        );
        try {
          _writeFile(sandbox, 'lib/src/terminal.dart', '''
class Router {
  Router(this.engine);

  final StrokeEngine engine;

  void handleUp() {
    engine.commitOnUp();
    clear();
  }

  void clear() {}
}

class StrokeEngine {
  void commitOnUp() {
    final id = commitDrawStroke();
    emitStrokeCommit(id);
    clear();
  }

  int commitDrawStroke() => 1;

  void emitStrokeCommit(int id) {}

  void clear() {}
}
''');

          final missingTerminalTarget = await terminal_cleanup
              .runAuditTerminalCleanupSafetyTool(const [], root: sandbox);
          expect(missingTerminalTarget.exitCode, 1);
          expect(missingTerminalTarget.stderr, contains('<path-or-dir>'));

          final terminalResult = await terminal_cleanup
              .runAuditTerminalCleanupSafetyTool(const [
                'lib/src/terminal.dart',
              ], root: sandbox);
          expect(terminalResult.exitCode, 1, reason: terminalResult.stderr);
          expect(terminalResult.stdout, contains('Router.handleUp'));

          final postCommitResult = await post_commit_cleanup
              .runAuditPostCommitCleanupOrderTool(const [
                'lib/src/terminal.dart',
              ], root: sandbox);
          expect(postCommitResult.exitCode, 1, reason: postCommitResult.stderr);
          expect(postCommitResult.stdout, contains('StrokeEngine.commitOnUp'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('route audit requires an explicit config path', () async {
      final result = await route_expectations.runAuditRouteExpectationsTool(
        const [],
      );

      expect(result.exitCode, 1);
      expect(result.stderr, contains('--config=<json>'));
    });

    test(
      'export namespace trace works from a package-neutral fixture',
      () async {
        final sandbox = await Directory.systemTemp.createTemp(
          'iwb_canvas_engine_forensics_exports_',
        );
        try {
          _writeFile(sandbox, 'pubspec.yaml', '''
name: forensics_fixture
environment:
  sdk: ^3.10.4
''');
          _writeFile(sandbox, 'lib/entrypoint.dart', '''
export 'src/direct.dart';
export 'src/barrel.dart';
''');
          _writeFile(sandbox, 'lib/src/direct.dart', '''
final class DirectExport {}
''');
          _writeFile(sandbox, 'lib/src/barrel.dart', '''
export 'nested.dart';
''');
          _writeFile(sandbox, 'lib/src/nested.dart', '''
final class NestedExport {}
''');

          final result = await export_namespace.runTraceExportNamespaceTool(
            const ['lib/entrypoint.dart', '--json'],
            root: sandbox,
          );

          expect(result.exitCode, 0, reason: result.stderr);
          final payload = jsonDecode(result.stdout) as Map<String, Object?>;
          expect(
            payload['directExportTargets'],
            contains('/lib/src/direct.dart'),
          );
          expect(
            payload['transitiveOwnerPaths'],
            contains('/lib/src/nested.dart'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}

void _writeFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
