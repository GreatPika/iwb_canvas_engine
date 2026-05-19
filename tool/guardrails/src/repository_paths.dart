import 'dart:io';

String get repositoryRoot => Directory.current.absolute.path;

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

  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}
