import 'dart:io';

final class PublicApiFixture {
  const PublicApiFixture({
    required this.expectedNames,
    required this.apiSource,
    this.barrel = "export 'src/api/public.dart';",
    this.registrySource,
    this.extraApiFiles = const <String, String>{},
  });

  final List<String> expectedNames;
  final String apiSource;
  final String barrel;
  final String? registrySource;
  final Map<String, String> extraApiFiles;

  Future<Directory> createTempRepo() async {
    final root = await Directory.systemTemp.createTemp('iwb_public_api_');
    final registry = File('${root.path}/docs/_registry/public_api_v1.yaml');
    final api = File('${root.path}/lib/src/api/public.dart');
    final publicBarrel = File('${root.path}/lib/iwb_canvas_engine.dart');
    final pubspec = File('${root.path}/pubspec.yaml');

    registry.createSync(recursive: true);
    api.createSync(recursive: true);
    publicBarrel.createSync(recursive: true);
    pubspec.createSync(recursive: true);

    registry.writeAsStringSync(registrySource ?? _registryYaml(expectedNames));
    api.writeAsStringSync(apiSource);
    publicBarrel.writeAsStringSync(barrel);
    pubspec.writeAsStringSync('name: iwb_canvas_engine\n');
    _copyPackageConfig(root);
    _writeExtraApiFiles(root, extraApiFiles);

    return root;
  }
}

void _copyPackageConfig(Directory root) {
  final source = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  if (!source.existsSync()) {
    return;
  }

  final target = File('${root.path}/.dart_tool/package_config.json');
  target.createSync(recursive: true);
  target.writeAsStringSync(source.readAsStringSync());
}

void _writeExtraApiFiles(Directory root, Map<String, String> files) {
  for (final entry in files.entries) {
    final file = File('${root.path}/lib/src/api/${entry.key}');
    file.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }
}

String _registryYaml(List<String> names) {
  return [
    'public_exports:',
    for (final name in names) '  - $name',
    '',
  ].join('\n');
}
