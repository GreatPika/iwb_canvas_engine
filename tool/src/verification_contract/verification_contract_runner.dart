import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'verification_contract_models.dart';

Future<void> runVerificationPlan(ResolvedVerificationPlan plan) async {
  for (final step in plan.steps) {
    final watch = Stopwatch()..start();
    final result = await _runCommand(step.command, cwd: step.cwd);
    watch.stop();

    final seconds = result.elapsed.inMilliseconds / 1000;
    final status = result.exitCode == 0 ? 'PASS' : 'FAIL';
    stdout.writeln('$status ${step.id} (${seconds.toStringAsFixed(3)} s)');
    if (result.exitCode == 0) {
      continue;
    }

    if (result.stdout.isNotEmpty) {
      stdout.write(result.stdout);
      if (!result.stdout.endsWith('\n')) {
        stdout.writeln();
      }
    }
    if (result.stderr.isNotEmpty) {
      stderr.write(result.stderr);
      if (!result.stderr.endsWith('\n')) {
        stderr.writeln();
      }
    }
    throw VerificationExit(exitCode: result.exitCode, message: '');
  }
}

Future<_CommandResult> _runCommand(
  String command, {
  required String cwd,
}) async {
  final shell = Platform.isWindows ? 'cmd' : '/bin/sh';
  final shellArgs = Platform.isWindows
      ? <String>['/c', command]
      : <String>['-c', command];
  final watch = Stopwatch()..start();
  final process = await Process.start(
    shell,
    shellArgs,
    workingDirectory: cwd == '.' ? null : cwd,
    runInShell: false,
  );
  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode;
  watch.stop();
  return _CommandResult(
    exitCode: exitCode,
    elapsed: watch.elapsed,
    stdout: await stdoutFuture,
    stderr: await stderrFuture,
  );
}

class _CommandResult {
  const _CommandResult({
    required this.exitCode,
    required this.elapsed,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final Duration elapsed;
  final String stdout;
  final String stderr;
}
