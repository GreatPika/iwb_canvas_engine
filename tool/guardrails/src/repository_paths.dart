import 'dart:io';

String get repositoryRoot => Directory.current.absolute.path;

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
