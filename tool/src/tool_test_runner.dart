import 'dart:async';
import 'dart:collection';
import 'dart:io';

const String toolTestRunnerUsage = '''
Usage: dart run tool/run_tool_tests.dart [--jobs=N] [test/tool/path_test.dart ...]

Runs tool tests file-by-file with limited parallelism via dart test.

Options:
  --jobs=N   Maximum number of concurrent dart test processes.
''';

const String _toolTestDartExecutableEnv = 'IWB_TOOL_TEST_RUNNER_DART';

Future<List<String>> discoverToolTestFiles({String root = 'test/tool'}) async {
  final files = <String>[];
  await for (final entity in Directory(root).list(recursive: true)) {
    if (entity is! File) {
      continue;
    }
    final path = entity.path.replaceAll(r'\', '/');
    if (!path.endsWith('_test.dart') || path.contains('/support/')) {
      continue;
    }
    files.add(path);
  }
  files.sort();
  return files;
}

RunnerConfig parseToolTestRunnerConfig(
  List<String> args, {
  int? processorCount,
}) {
  var jobs = defaultToolTestRunnerJobs(
    processorCount: processorCount ?? Platform.numberOfProcessors,
  );
  final explicitTestFiles = <String>[];

  for (final arg in args) {
    if (arg == '--help' || arg == '-h') {
      throw const RunnerExit(exitCode: 0, message: toolTestRunnerUsage);
    }
    if (arg.startsWith('--jobs=')) {
      final rawValue = arg.substring('--jobs='.length);
      jobs =
          int.tryParse(rawValue) ??
          _failConfig('Invalid --jobs value: $rawValue');
      if (jobs < 1) {
        _failConfig('--jobs must be at least 1.');
      }
      continue;
    }
    if (arg.startsWith('-')) {
      _failConfig('Unsupported option: $arg');
    }
    explicitTestFiles.add(arg.replaceAll(r'\', '/'));
  }

  return RunnerConfig(
    jobs: jobs,
    explicitTestFiles: explicitTestFiles.isEmpty
        ? null
        : List<String>.unmodifiable(explicitTestFiles),
  );
}

int defaultToolTestRunnerJobs({required int processorCount}) {
  if (processorCount <= 2) {
    return 1;
  }
  if (processorCount <= 4) {
    return 2;
  }
  if (processorCount <= 8) {
    return 4;
  }
  return 6;
}

Future<List<ToolTestResult>> runToolTests({
  required List<String> testFiles,
  required int jobs,
  Future<ToolTestResult> Function(String testFile)? runSingleTest,
}) async {
  final normalizedJobs = jobs < 1 ? 1 : jobs;
  final queue = ListQueue<String>.from(testFiles);
  final results = <ToolTestResult>[];
  final workerCount = normalizedJobs < testFiles.length
      ? normalizedJobs
      : testFiles.length;
  final runner = runSingleTest ?? _runSingleToolTest;

  Future<void> worker() async {
    while (queue.isNotEmpty) {
      final testFile = queue.removeFirst();
      results.add(await runner(testFile));
    }
  }

  await Future.wait(<Future<void>>[
    for (var i = 0; i < workerCount; i++) worker(),
  ]);

  results.sort((left, right) => left.testFile.compareTo(right.testFile));
  return results;
}

Future<ToolTestResult> runSingleToolTestProcess(String testFile) {
  return _runSingleToolTest(testFile);
}

Future<ToolTestResult> _runSingleToolTest(String testFile) async {
  final watch = Stopwatch()..start();
  final process = await Process.start(_toolTestDartExecutable(), <String>[
    'test',
    '--reporter=compact',
    testFile,
  ]);

  final stdoutFuture = process.stdout
      .transform(SystemEncoding().decoder)
      .join();
  final stderrFuture = process.stderr
      .transform(SystemEncoding().decoder)
      .join();
  final exitCode = await process.exitCode;
  final output = await stdoutFuture;
  final error = await stderrFuture;
  watch.stop();

  return ToolTestResult(
    testFile: testFile,
    exitCode: exitCode,
    duration: watch.elapsed,
    stdout: output,
    stderr: error,
  );
}

String _toolTestDartExecutable() {
  final override = Platform.environment[_toolTestDartExecutableEnv]?.trim();
  if (override == null || override.isEmpty) {
    return Platform.resolvedExecutable;
  }
  return override;
}

Never _failConfig(String message) {
  throw RunnerExit(exitCode: 64, message: '$message\n$toolTestRunnerUsage');
}

class RunnerConfig {
  const RunnerConfig({required this.jobs, required this.explicitTestFiles});

  final int jobs;
  final List<String>? explicitTestFiles;
}

class ToolTestResult {
  const ToolTestResult({
    required this.testFile,
    required this.exitCode,
    required this.duration,
    required this.stdout,
    required this.stderr,
  });

  final String testFile;
  final int exitCode;
  final Duration duration;
  final String stdout;
  final String stderr;

  bool get succeeded => exitCode == 0;
}

class RunnerExit implements Exception {
  const RunnerExit({required this.exitCode, required this.message});

  final int exitCode;
  final String message;
}
