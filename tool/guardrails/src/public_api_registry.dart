import 'dart:io';

import 'package:yaml/yaml.dart';

import 'repository_paths.dart';

Set<String> readPublicApiRegistry() {
  final file = File('$repositoryRoot/docs/_registry/public_api_v1.yaml');

  return readPublicApiRegistryFromYaml(file.readAsStringSync()).publicExports;
}

PublicApiRegistry readPublicApiRegistryFromYaml(String yamlSource) {
  final parsed = loadYaml(yamlSource) as YamlMap;
  final publicExports = _readStringSet(parsed, 'public_exports');
  final diagnosticsPublicSurface = _readStringSet(
    parsed,
    'diagnostics_public_surface',
  );

  final missing = diagnosticsPublicSurface.difference(publicExports);
  if (missing.isNotEmpty) {
    throw StateError(
      'diagnostics_public_surface entries must be present in public_exports: '
      '${_list(missing)}',
    );
  }

  return PublicApiRegistry(
    publicExports: publicExports,
    diagnosticsPublicSurface: diagnosticsPublicSurface,
  );
}

Set<String> _readStringSet(YamlMap parsed, String key) {
  final entries = parsed[key] as YamlList;

  return entries.cast<String>().toSet();
}

String _list(Iterable<String> names) {
  final sorted = names.toList()..sort();

  return sorted.join(', ');
}

final class PublicApiRegistry {
  const PublicApiRegistry({
    required this.publicExports,
    required this.diagnosticsPublicSurface,
  });

  final Set<String> publicExports;
  final Set<String> diagnosticsPublicSurface;
}
