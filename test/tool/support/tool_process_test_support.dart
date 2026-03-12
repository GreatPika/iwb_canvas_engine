import 'dart:io';

Future<Directory> createToolSandbox({
  required String tempPrefix,
  required List<String> toolFiles,
  bool includeAnalyzer = true,
}) async {
  final sandbox = await Directory.systemTemp.createTemp(tempPrefix);

  final pubspec = StringBuffer()
    ..writeln('name: iwb_canvas_engine')
    ..writeln('environment:')
    ..writeln('  sdk: ">=3.0.0 <4.0.0"');
  if (includeAnalyzer) {
    pubspec
      ..writeln('dev_dependencies:')
      ..writeln('  analyzer: ^8.4.0');
  }
  writeSandboxFile(sandbox, 'pubspec.yaml', pubspec.toString());

  final sourceRoot = Directory.current.path;
  for (final toolFile in toolFiles) {
    _copyPath('$sourceRoot/$toolFile', '${sandbox.path}/$toolFile');
  }

  return sandbox;
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
}) {
  return Process.run('dart', <String>[
    'run',
    'tool/$toolFileName',
    ...args,
  ], workingDirectory: sandbox.path);
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
