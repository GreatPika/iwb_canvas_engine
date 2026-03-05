import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tool/check_public_api_surface.dart', () {
    test('passes when golden matches exported symbol set', () async {
      final sandbox = await _createSandbox();
      try {
        _writePublicApiFixture(sandbox);
        _writeFile(
          sandbox,
          'tool/goldens/public_api_symbols.txt',
          'Alias\nForwarded\nHiddenByShow\nMultiA\nMultiB\nPublicClass\nmultiLineFn\ntopFn\nviaPart\n',
        );

        final result = await _runTool(sandbox, const <String>[]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('Public API surface OK'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('fails with added and removed symbol diagnostics', () async {
      final sandbox = await _createSandbox();
      try {
        _writePublicApiFixture(sandbox);
        _writeFile(
          sandbox,
          'tool/goldens/public_api_symbols.txt',
          'Alias\nForwarded\nLegacyOnly\nMultiA\nMultiB\nPublicClass\nmultiLineFn\ntopFn\nviaPart\n',
        );

        final result = await _runTool(sandbox, const <String>[]);
        expect(result.exitCode, isNonZero);
        expect(result.stderr.toString(), contains('Added symbols'));
        expect(result.stderr.toString(), contains('+ HiddenByShow'));
        expect(result.stderr.toString(), contains('Removed symbols'));
        expect(result.stderr.toString(), contains('- LegacyOnly'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('fails when golden is not sorted', () async {
      final sandbox = await _createSandbox();
      try {
        _writePublicApiFixture(sandbox);
        _writeFile(
          sandbox,
          'tool/goldens/public_api_symbols.txt',
          'Alias\nForwarded\nHiddenByShow\nMultiA\nMultiB\nPublicClass\ntopFn\nmultiLineFn\nviaPart\n',
        );

        final result = await _runTool(sandbox, const <String>[]);
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('golden must be sorted lexicographically'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('fails when golden contains duplicate symbol entries', () async {
      final sandbox = await _createSandbox();
      try {
        _writePublicApiFixture(sandbox);
        _writeFile(
          sandbox,
          'tool/goldens/public_api_symbols.txt',
          'Alias\nAlias\nForwarded\nHiddenByShow\nMultiA\nMultiB\nPublicClass\nmultiLineFn\ntopFn\nviaPart\n',
        );

        final result = await _runTool(sandbox, const <String>[]);
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('golden has duplicate symbol entries'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('update mode regenerates golden from current exports', () async {
      final sandbox = await _createSandbox();
      try {
        _writePublicApiFixture(sandbox);

        final update = await _runTool(sandbox, const <String>['--update']);
        expect(update.exitCode, 0, reason: update.stderr.toString());

        final golden = File(
          '${sandbox.path}/tool/goldens/public_api_symbols.txt',
        ).readAsLinesSync();
        expect(golden, <String>[
          'Alias',
          'Forwarded',
          'HiddenByShow',
          'MultiA',
          'MultiB',
          'PublicClass',
          'multiLineFn',
          'topFn',
          'viaPart',
        ]);
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'captures part declarations, multiline functions, and multi-var declarations',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writePublicApiFixture(sandbox);
          final update = await _runTool(sandbox, const <String>['--update']);
          expect(update.exitCode, 0, reason: update.stderr.toString());

          final result = await _runTool(sandbox, const <String>[]);
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}

Future<Directory> _createSandbox() async {
  final sandbox = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_public_api_surface_tool_test_',
  );

  _writeFile(sandbox, 'pubspec.yaml', '''
name: iwb_canvas_engine
environment:
  sdk: ">=3.0.0 <4.0.0"
dev_dependencies:
  analyzer: ^8.4.0
''');

  final sourceRoot = Directory.current.path;
  _copyFile(
    '$sourceRoot/tool/check_public_api_surface.dart',
    '${sandbox.path}/tool/check_public_api_surface.dart',
  );

  return sandbox;
}

void _writePublicApiFixture(Directory sandbox) {
  _writeFile(sandbox, 'lib/iwb_canvas_engine.dart', '''
library;

export 'src/a.dart' show PublicClass, Forwarded, topFn, multiLineFn, viaPart;
export 'src/b.dart';
''');

  _writeFile(sandbox, 'lib/src/a.dart', '''
part 'a_part.dart';

class PublicClass {}
class _PrivateClass {}

void topFn() {}

String multiLineFn(
  int value,
) {
  return '\$value';
}

export 'c.dart' show Forwarded, HiddenByShow;
''');

  _writeFile(sandbox, 'lib/src/a_part.dart', '''
part of 'a.dart';

void viaPart() {}
''');

  _writeFile(sandbox, 'lib/src/b.dart', '''
typedef Alias = int;
const int MultiA = 1, MultiB = 2;

export 'c.dart' hide HiddenByHide;
''');

  _writeFile(sandbox, 'lib/src/c.dart', '''
class Forwarded {}
class HiddenByShow {}
class HiddenByHide {}
''');
}

void _copyFile(String from, String to) {
  final source = File(from);
  final target = File(to);
  target.parent.createSync(recursive: true);
  source.copySync(target.path);
}

void _writeFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

Future<ProcessResult> _runTool(Directory sandbox, List<String> args) {
  return Process.run('dart', <String>[
    'run',
    'tool/check_public_api_surface.dart',
    ...args,
  ], workingDirectory: sandbox.path);
}
