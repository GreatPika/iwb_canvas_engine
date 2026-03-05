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
    _copyFile('$sourceRoot/$toolFile', '${sandbox.path}/$toolFile');
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

void _copyFile(String from, String to) {
  final source = File(from);
  final target = File(to);
  target.parent.createSync(recursive: true);
  source.copySync(target.path);
}
