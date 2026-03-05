@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tool/check_coverage.dart', () {
    test('rejects lib/src file that is missing from lcov', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/a.dart', 'int covered() => 1;\n');
        _writeFile(sandbox, 'lib/src/b.dart', 'int uncovered() => 2;\n');
        _writeFile(sandbox, 'coverage/lcov.info', '''
TN:
SF:lib/src/a.dart
DA:1,1
LF:1
LH:1
end_of_record
''');

        final result = await _runTool(sandbox, 'check_coverage.dart');
        expect(result.exitCode, isNonZero);
        expect(result.stderr.toString(), contains('lib/src/b.dart'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('passes when every lib/src file is present in lcov', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/a.dart', 'int first() => 1;\n');
        _writeFile(sandbox, 'lib/src/b.dart', 'int second() => 2;\n');
        _writeFile(sandbox, 'coverage/lcov.info', '''
TN:
SF:lib/src/a.dart
DA:1,1
LF:1
LH:1
end_of_record
TN:
SF:lib/src/b.dart
DA:1,1
LF:1
LH:1
end_of_record
''');

        final result = await _runTool(sandbox, 'check_coverage.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('passes when missing file is a pure export-only shim', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/contract/a.dart', 'int covered() => 1;\n');
        _writeFile(
          sandbox,
          'lib/src/shim.dart',
          "export 'package:iwb_canvas_engine/src/contract/a.dart';\n",
        );
        _writeFile(sandbox, 'coverage/lcov.info', '''
TN:
SF:lib/src/contract/a.dart
DA:1,1
LF:1
LH:1
end_of_record
''');

        final result = await _runTool(sandbox, 'check_coverage.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects missing shim file when logic leaks back into it', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/contract/a.dart', 'int covered() => 1;\n');
        _writeFile(sandbox, 'lib/src/shim.dart', '''
export 'package:iwb_canvas_engine/src/contract/a.dart';
int leaked() => 1;
''');
        _writeFile(sandbox, 'coverage/lcov.info', '''
TN:
SF:lib/src/contract/a.dart
DA:1,1
LF:1
LH:1
end_of_record
''');

        final result = await _runTool(sandbox, 'check_coverage.dart');
        expect(result.exitCode, isNonZero);
        expect(result.stderr.toString(), contains('lib/src/shim.dart'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('passes when export-only shim includes comment wrapper', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/contract/a.dart', 'int covered() => 1;\n');
        _writeFile(sandbox, 'lib/src/shim.dart', '''
// comment
export 'package:iwb_canvas_engine/src/contract/a.dart';
''');
        _writeFile(sandbox, 'coverage/lcov.info', '''
TN:
SF:lib/src/contract/a.dart
DA:1,1
LF:1
LH:1
end_of_record
''');

        final result = await _runTool(sandbox, 'check_coverage.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() async {
  final sandbox = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_coverage_tool_test_',
  );

  _writeFile(sandbox, 'pubspec.yaml', '''
name: iwb_canvas_engine
environment:
  sdk: ">=3.0.0 <4.0.0"
''');

  final sourceRoot = Directory.current.path;
  _copyFile(
    '$sourceRoot/tool/check_coverage.dart',
    '${sandbox.path}/tool/check_coverage.dart',
  );

  return sandbox;
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

Future<ProcessResult> _runTool(Directory sandbox, String toolFileName) {
  return Process.run('dart', <String>[
    'run',
    'tool/$toolFileName',
  ], workingDirectory: sandbox.path);
}
