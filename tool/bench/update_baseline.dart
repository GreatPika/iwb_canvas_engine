import 'dart:io';

import 'src/benchmark_diff.dart';

Future<void> main(List<String> args) async {
  try {
    final exitCode = await runBenchmarkBaselineUpdateCli(args);
    exitCode == 0 ? exit(0) : exit(exitCode);
  } on FormatException catch (error) {
    stderr.writeln('FAIL: ${error.message}');
    exit(1);
  }
}
