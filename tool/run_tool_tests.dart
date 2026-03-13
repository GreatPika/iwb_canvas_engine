import 'dart:io';

import 'src/tool_test_runner.dart';

Future<void> main(List<String> args) async {
  try {
    final config = parseToolTestRunnerConfig(args);
    final testFiles = config.explicitTestFiles ?? await discoverToolTestFiles();

    if (testFiles.isEmpty) {
      stderr.writeln('No tool test files found.');
      exitCode = 1;
      return;
    }

    stdout.writeln(
      'Running ${testFiles.length} tool test files with up to '
      '${config.jobs} concurrent process(es).',
    );

    final results = await runToolTests(
      testFiles: testFiles,
      jobs: config.jobs,
      runSingleTest: (testFile) async {
        stdout.writeln('START $testFile');
        final result = await runSingleToolTestProcess(testFile);
        final status = result.exitCode == 0 ? 'PASS' : 'FAIL';
        final millis = (result.duration.inMilliseconds % 1000)
            .toString()
            .padLeft(3, '0');
        stdout.writeln(
          '$status $testFile (${result.duration.inSeconds}.$millis s)',
        );
        stdout.write(result.stdout);
        stderr.write(result.stderr);
        return result;
      },
    );
    final failedResults = results
        .where((result) => result.exitCode != 0)
        .toList();

    stdout.writeln('');
    stdout.writeln(
      'Tool test summary: ${results.length - failedResults.length} passed, '
      '${failedResults.length} failed.',
    );

    if (failedResults.isEmpty) {
      return;
    }

    stderr.writeln('Failed tool test files:');
    for (final result in failedResults) {
      stderr.writeln('  ${result.testFile}');
    }
    exitCode = 1;
  } on RunnerExit catch (error) {
    if (error.exitCode == 0) {
      stdout.write(error.message);
    } else {
      stderr.write(error.message);
    }
    exitCode = error.exitCode;
  }
}
