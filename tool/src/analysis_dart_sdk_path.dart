import 'dart:io';

String? resolveAnalysisDartSdkPath() {
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
