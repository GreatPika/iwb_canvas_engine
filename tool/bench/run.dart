import 'dart:io';

import 'src/benchmark_runner.dart';

Future<void> main(List<String> args) async {
  try {
    final outputPath = await runBenchmarkCli(args);
    stdout.writeln('Benchmark report written to $outputPath');
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
