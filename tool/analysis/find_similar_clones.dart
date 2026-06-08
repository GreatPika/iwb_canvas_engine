import 'dart:io';

import 'src/clone_analysis_cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCloneAnalysisCli(args, stdout: stdout, stderr: stderr);
}
