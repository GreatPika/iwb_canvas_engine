import 'dart:convert';
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

/// Returns the first value passed as `--flag=value` without interpreting it.
String? toolCommandStringFlag(List<String> args, String flag) {
  final prefix = '$flag=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      return arg.replaceFirst(prefix, '');
    }
  }
  return null;
}

/// Returns every value passed as `--flag=value`, retaining argument order.
List<String> toolCommandRepeatedStringFlag(List<String> args, String flag) => [
  for (final arg in args)
    if (arg.startsWith('$flag=')) arg.replaceFirst('$flag=', ''),
];

/// Parses a `--flag=value` option as an integer when its value is valid.
int? toolCommandIntFlag(List<String> args, String flag) =>
    int.tryParse(toolCommandStringFlag(args, flag) ?? '');

/// Uses the common two-space JSON representation used by root tool commands.
String encodeToolCommandJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// Writes a tool report relative to [root], while preserving absolute paths.
void writeToolCommandOutputFile(Directory root, String path, String content) {
  final target = File(
    _isAbsoluteToolPath(path)
        ? path
        : '${root.path}${Platform.pathSeparator}$path',
  );
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(content);
}

bool _isAbsoluteToolPath(String path) =>
    path.startsWith('/') ||
    (Platform.isWindows && RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path));
