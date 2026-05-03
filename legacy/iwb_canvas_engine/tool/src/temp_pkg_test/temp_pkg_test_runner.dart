import 'dart:async';
import 'dart:io';

const String tempPkgTestUsage = '''
Usage: dart run tool/run_temp_pkg_test.dart (--test-file=<path> | --snippet-file=<path> | --stdin) [--keep-temp]

Runs a temporary Flutter test package wired to the current repository with a
path dependency on `iwb_canvas_engine`.

Options:
  --test-file=<path>     Run an existing full test file inside a temporary package.
  --snippet-file=<path>  Wrap a Dart test snippet into a standard test shell.
  --stdin                Read a Dart test snippet from stdin and wrap it.
  --keep-temp            Keep the generated temporary package on disk.
''';

TempPkgTestConfig parseTempPkgTestConfig(List<String> args) {
  TempPkgTestInput? input;
  var keepTemp = false;

  for (final arg in args) {
    if (arg == '--help' || arg == '-h') {
      throw const TempPkgTestExit(exitCode: 0, message: tempPkgTestUsage);
    }
    if (arg == '--keep-temp') {
      keepTemp = true;
      continue;
    }
    if (arg == '--stdin') {
      input = _setInput(
        current: input,
        next: const TempPkgTestInput.stdinSnippet(),
      );
      continue;
    }
    if (arg.startsWith('--test-file=')) {
      input = _setInput(
        current: input,
        next: TempPkgTestInput.testFile(arg.substring('--test-file='.length)),
      );
      continue;
    }
    if (arg.startsWith('--snippet-file=')) {
      input = _setInput(
        current: input,
        next: TempPkgTestInput.snippetFile(
          arg.substring('--snippet-file='.length),
        ),
      );
      continue;
    }
    if (arg.startsWith('-')) {
      _fail('Unsupported option: $arg');
    }
    _fail('Unexpected positional argument: $arg');
  }

  if (input == null) {
    _fail('Provide exactly one input source.');
  }

  return TempPkgTestConfig(input: input, keepTemp: keepTemp);
}

Future<TempPkgTestSource> readTempPkgTestSource(
  TempPkgTestConfig config,
) async {
  switch (config.input.mode) {
    case TempPkgTestInputMode.testFile:
      final path = _requireInputValue(config.input);
      final file = File(_normalizePath(path));
      if (!file.existsSync()) {
        throw TempPkgTestExit(
          exitCode: 66,
          message: 'Test file not found: ${file.path}',
        );
      }
      return TempPkgTestSource(
        mode: TempPkgTestSourceMode.fullTestFile,
        content: await file.readAsString(),
      );
    case TempPkgTestInputMode.snippetFile:
      final path = _requireInputValue(config.input);
      final file = File(_normalizePath(path));
      if (!file.existsSync()) {
        throw TempPkgTestExit(
          exitCode: 66,
          message: 'Snippet file not found: ${file.path}',
        );
      }
      return TempPkgTestSource(
        mode: TempPkgTestSourceMode.snippet,
        content: await file.readAsString(),
      );
    case TempPkgTestInputMode.stdinSnippet:
      final content = await stdin.transform(SystemEncoding().decoder).join();
      if (content.trim().isEmpty) {
        throw const TempPkgTestExit(
          exitCode: 64,
          message: 'Stdin snippet is empty.\n$tempPkgTestUsage',
        );
      }
      return TempPkgTestSource(
        mode: TempPkgTestSourceMode.snippet,
        content: content,
      );
  }
}

String renderTempPkgTestFile(TempPkgTestSource source) {
  if (source.mode == TempPkgTestSourceMode.fullTestFile) {
    return source.content;
  }
  final snippet = source.content.trimRight();
  return '''
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
${_indentBlock(snippet)}
}
''';
}

String renderTempPkgPubspec({required String repositoryRoot}) {
  final escapedRoot = repositoryRoot.replaceAll("'", "''");
  return '''
name: iwb_canvas_engine_temp_pkg_test
publish_to: none

environment:
  sdk: ^3.10.4
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  iwb_canvas_engine:
    path: '$escapedRoot'

dev_dependencies:
  flutter_test:
    sdk: flutter
''';
}

Future<TempPkgTestRunResult> runTempPkgTest(
  TempPkgTestConfig config,
  TempPkgTestSource source,
) async {
  final sandbox = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_temp_pkg_test_',
  );
  final sandboxPath = sandbox.path.replaceAll(r'\', '/');

  try {
    File('$sandboxPath/pubspec.yaml').writeAsStringSync(
      renderTempPkgPubspec(
        repositoryRoot: Directory.current.path.replaceAll(r'\', '/'),
      ),
    );
    final testFile = File('$sandboxPath/test/temp_pkg_test.dart');
    testFile.parent.createSync(recursive: true);
    testFile.writeAsStringSync(renderTempPkgTestFile(source));

    final pubGet = await Process.run('flutter', const <String>[
      'pub',
      'get',
    ], workingDirectory: sandboxPath);
    if (pubGet.exitCode != 0) {
      return TempPkgTestRunResult(
        exitCode: pubGet.exitCode,
        stdout: pubGet.stdout.toString(),
        stderr: _appendTempPath(
          pubGet.stderr.toString(),
          sandboxPath: sandboxPath,
          keepTemp: config.keepTemp,
        ),
      );
    }

    final testRun = await Process.run('flutter', const <String>[
      'test',
      '--no-pub',
      'test/temp_pkg_test.dart',
    ], workingDirectory: sandboxPath);
    return TempPkgTestRunResult(
      exitCode: testRun.exitCode,
      stdout: testRun.stdout.toString(),
      stderr: _appendTempPath(
        testRun.stderr.toString(),
        sandboxPath: sandboxPath,
        keepTemp: config.keepTemp,
      ),
    );
  } finally {
    if (!config.keepTemp && sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  }
}

TempPkgTestInput _setInput({
  required TempPkgTestInput? current,
  required TempPkgTestInput next,
}) {
  if (current != null) {
    _fail('Provide exactly one input source.');
  }
  return next;
}

String _normalizePath(String path) => path.replaceAll(r'\', '/');

String _requireInputValue(TempPkgTestInput input) {
  final value = input.value;
  if (value == null) {
    throw TempPkgTestExit(
      exitCode: 64,
      message: 'Selected input mode requires a path.\n$tempPkgTestUsage',
    );
  }
  return value;
}

Never _fail(String message) {
  throw TempPkgTestExit(exitCode: 64, message: '$message\n$tempPkgTestUsage');
}

String _indentBlock(String value) {
  return value
      .split('\n')
      .map((line) => line.isEmpty ? '  ' : '  $line')
      .join('\n');
}

String _appendTempPath(
  String stderr, {
  required String sandboxPath,
  required bool keepTemp,
}) {
  if (!keepTemp) {
    return stderr;
  }
  final suffix = 'Temporary package kept at: $sandboxPath\n';
  if (stderr.isEmpty) {
    return suffix;
  }
  if (stderr.endsWith('\n')) {
    return '$stderr$suffix';
  }
  return '$stderr\n$suffix';
}

final class TempPkgTestConfig {
  const TempPkgTestConfig({required this.input, required this.keepTemp});

  final TempPkgTestInput input;
  final bool keepTemp;
}

enum TempPkgTestInputMode { testFile, snippetFile, stdinSnippet }

final class TempPkgTestInput {
  const TempPkgTestInput._({required this.mode, this.value});

  const TempPkgTestInput.testFile(String path)
    : this._(mode: TempPkgTestInputMode.testFile, value: path);

  const TempPkgTestInput.snippetFile(String path)
    : this._(mode: TempPkgTestInputMode.snippetFile, value: path);

  const TempPkgTestInput.stdinSnippet()
    : this._(mode: TempPkgTestInputMode.stdinSnippet);

  final TempPkgTestInputMode mode;
  final String? value;
}

enum TempPkgTestSourceMode { fullTestFile, snippet }

final class TempPkgTestSource {
  const TempPkgTestSource({required this.mode, required this.content});

  final TempPkgTestSourceMode mode;
  final String content;
}

final class TempPkgTestRunResult {
  const TempPkgTestRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

class TempPkgTestExit implements Exception {
  const TempPkgTestExit({required this.exitCode, required this.message});

  final int exitCode;
  final String message;
}
