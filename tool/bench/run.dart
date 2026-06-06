import 'dart:io';

import 'src/benchmark_runner.dart';

Future<void> main(List<String> args) async {
  try {
    final result = await runBenchmarkCliDetailed(args);
    stdout.writeln('Benchmark report written to ${result.reportPath}');
    final historyPath = result.historyPath;
    if (historyPath != null) {
      stdout.writeln('Benchmark history written to $historyPath');
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
