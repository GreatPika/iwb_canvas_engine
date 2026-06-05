import 'dart:io';

String get repositoryRoot => Directory.current.absolute.path;

String? get analysisDartSdkPath {
  for (final path in [
    Platform.environment['DART_SDK'],
    _flutterRootDartSdkPath(Platform.environment['FLUTTER_ROOT']),
    ..._executableAdjacentDartSdkPaths(),
  ]) {
    if (path != null && _isDartSdkPath(path)) {
      return path;
    }
  }

  return null;
}

final class GuardrailSourceFile {
  const GuardrailSourceFile({required this.path, required this.absolutePath});

  final String path;
  final String absolutePath;
}

Iterable<File> dartFilesUnder(String relativeDirectory) {
  final root = Directory('$repositoryRoot/$relativeDirectory');
  if (!root.existsSync()) {
    return const [];
  }

  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

String relativePath(File file) {
  final path = file.absolute.path;
  final prefix = '$repositoryRoot/';

  return path.startsWith(prefix) ? path.replaceFirst(prefix, '') : path;
}

Iterable<GuardrailSourceFile> dartSourceFilesUnder(String relativeDirectory) {
  return dartFilesUnder(relativeDirectory).map((file) {
    return GuardrailSourceFile(
      path: relativePath(file),
      absolutePath: file.absolute.path,
    );
  });
}

String? _flutterRootDartSdkPath(String? flutterRoot) {
  if (flutterRoot == null || flutterRoot.isEmpty) {
    return null;
  }

  return '$flutterRoot/bin/cache/dart-sdk';
}

Iterable<String> _executableAdjacentDartSdkPaths() sync* {
  var directory = File(Platform.resolvedExecutable).absolute.parent;
  for (var depth = 0; depth < 10; depth += 1) {
    yield '${directory.path}/dart-sdk';
    yield '${directory.path}/cache/dart-sdk';
    yield '${directory.path}/bin/cache/dart-sdk';
    final parent = directory.parent;
    if (parent.path == directory.path) {
      break;
    }
    directory = parent;
  }
}

bool _isDartSdkPath(String path) {
  return File(
    '$path/lib/_internal/sdk_library_metadata/lib/libraries.dart',
  ).existsSync();
}
