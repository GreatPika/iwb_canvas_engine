import 'dart:io';

import 'src/temp_pkg_test/temp_pkg_test_runner.dart';

Future<void> main(List<String> args) async {
  try {
    final config = parseTempPkgTestConfig(args);
    final source = await readTempPkgTestSource(config);
    final result = await runTempPkgTest(config, source);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exitCode = result.exitCode;
  } on TempPkgTestExit catch (error) {
    final sink = error.exitCode == 0 ? stdout : stderr;
    sink.write(error.message);
    if (!error.message.endsWith('\n')) {
      sink.writeln();
    }
    exitCode = error.exitCode;
  }
}
