import 'dart:io';

class ToolCommandResult {
  const ToolCommandResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get succeeded => exitCode == 0;
}

void writeToolCommandResult(
  ToolCommandResult result, {
  StringSink? stdoutSink,
  StringSink? stderrSink,
}) {
  final out = stdoutSink ?? stdout;
  final err = stderrSink ?? stderr;
  if (result.stdout.isNotEmpty) {
    out.write(result.stdout);
  }
  if (result.stderr.isNotEmpty) {
    err.write(result.stderr);
  }
}
