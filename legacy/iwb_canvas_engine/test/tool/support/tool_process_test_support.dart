import 'dart:io';

import '../../../tool/src/guardrails/guardrails_runner.dart';
import '../../../tool/src/import_boundaries/import_boundaries_runner.dart';

Future<Directory> createToolSandbox({
  required String tempPrefix,
  required List<String> toolFiles,
  bool includeAnalyzer = true,
}) async {
  final sandbox = await Directory.systemTemp.createTemp(tempPrefix);
  final sdkConstraint = _currentPackageSdkConstraint();

  final pubspec = StringBuffer()
    ..writeln('name: iwb_canvas_engine')
    ..writeln('environment:')
    ..writeln("  sdk: '$sdkConstraint'")
    ..writeln('dev_dependencies:')
    ..writeln('  yaml: ^3.1.3');
  if (includeAnalyzer) {
    pubspec.writeln('  analyzer: ^8.4.0');
  }
  writeSandboxFile(sandbox, 'pubspec.yaml', pubspec.toString());

  final sourceRoot = Directory.current.path;
  for (final toolFile in toolFiles) {
    _copyPath('$sourceRoot/$toolFile', '${sandbox.path}/$toolFile');
  }

  return sandbox;
}

String _currentPackageSdkConstraint() {
  final pubspecFile = File('${Directory.current.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    throw StateError('Repository pubspec.yaml is required for tool sandbox.');
  }

  final match = RegExp(
    r'^\s*sdk:\s*([^\r\n#]+?)\s*$',
    multiLine: true,
  ).firstMatch(pubspecFile.readAsStringSync());
  if (match == null) {
    throw StateError(
      'Repository pubspec.yaml must define environment.sdk for tool sandboxes.',
    );
  }

  final rawConstraint = match.group(1);
  if (rawConstraint == null) {
    throw StateError(
      'Repository pubspec.yaml environment.sdk must include a constraint value.',
    );
  }

  final constraint = rawConstraint.trim();
  return constraint.replaceAll('"', '').replaceAll("'", '');
}

void writeSandboxFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

Future<ProcessResult> runSandboxTool(
  Directory sandbox,
  String toolFileName, {
  List<String> args = const <String>[],
  Map<String, String>? environment,
  String? stdinText,
}) async {
  final inProcessResult = await _runInProcessToolIfSupported(
    sandbox,
    toolFileName,
    args: args,
    environment: environment,
    stdinText: stdinText,
  );
  if (inProcessResult != null) {
    return inProcessResult;
  }

  if (stdinText == null) {
    return Process.run(
      'dart',
      <String>['run', 'tool/$toolFileName', ...args],
      workingDirectory: sandbox.path,
      environment: environment,
    );
  }

  final process = await Process.start(
    'dart',
    <String>['run', 'tool/$toolFileName', ...args],
    workingDirectory: sandbox.path,
    environment: environment,
  );
  process.stdin.write(stdinText);
  await process.stdin.close();

  final stdout = await process.stdout
      .transform(SystemEncoding().decoder)
      .join();
  final stderr = await process.stderr
      .transform(SystemEncoding().decoder)
      .join();
  final exitCode = await process.exitCode;
  return ProcessResult(process.pid, exitCode, stdout, stderr);
}

Future<ProcessResult?> _runInProcessToolIfSupported(
  Directory sandbox,
  String toolFileName, {
  required List<String> args,
  required Map<String, String>? environment,
  required String? stdinText,
}) async {
  // Keep the fast path narrow and explicit: only analyzer-heavy tools that
  // accept an alternate root run in-process. Everything else keeps the real
  // subprocess boundary so behavior stays aligned with production CLIs.
  if (environment != null || stdinText != null) {
    return null;
  }
  if (args.isNotEmpty) {
    return null;
  }

  final result = switch (toolFileName) {
    'check_guardrails.dart' => await evaluateGuardrailsTool(root: sandbox),
    'check_import_boundaries.dart' => evaluateImportBoundariesTool(
      root: sandbox,
    ),
    _ => null,
  };
  if (result == null) {
    return null;
  }

  return ProcessResult(0, result.exitCode, result.stdout, result.stderr);
}

void _copyPath(String from, String to) {
  final sourceFile = File(from);
  if (sourceFile.existsSync()) {
    final target = File(to);
    target.parent.createSync(recursive: true);
    sourceFile.copySync(target.path);
    return;
  }

  final sourceDir = Directory(from);
  if (!sourceDir.existsSync()) {
    throw FileSystemException('Tool path not found', from);
  }
  for (final entity in sourceDir.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final relativePath = entity.path.substring(sourceDir.path.length + 1);
    final target = File('$to/$relativePath');
    target.parent.createSync(recursive: true);
    entity.copySync(target.path);
  }
}
