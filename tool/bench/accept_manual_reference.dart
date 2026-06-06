import 'dart:io';

import 'src/manual_benchmark_reference.dart';

Future<void> main(List<String> args) async {
  try {
    final outputPath = await runManualBenchmarkReferenceCli(args);
    stdout.writeln('Manual benchmark reference written to $outputPath');
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
