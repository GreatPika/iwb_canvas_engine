import 'dart:io';

import 'package:yaml/yaml.dart';

import 'repository_paths.dart';

Set<String> readPublicApiRegistry() {
  return readPublicApiRegistryData().publicExports;
}

PublicApiRegistry readPublicApiRegistryData() {
  final file = File('$repositoryRoot/docs/_registry/public_api_v1.yaml');

  return readPublicApiRegistryFromYaml(file.readAsStringSync());
}

PublicApiRegistry readPublicApiRegistryFromYaml(String yamlSource) {
  final parsed = _readYamlMap(yamlSource);
  final publicExports = _readStringSet(parsed, 'public_exports');
  final retiredPublicExports = _readStringSet(parsed, 'retired_public_exports');
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

  final activeRetiredOverlap = publicExports.intersection(retiredPublicExports);
  if (activeRetiredOverlap.isNotEmpty) {
    throw StateError(
      'retired_public_exports entries must not be present in public_exports: '
      '${_list(activeRetiredOverlap)}',
    );
  }

  return PublicApiRegistry(
    publicExports: publicExports,
    retiredPublicExports: retiredPublicExports,
    diagnosticsPublicSurface: diagnosticsPublicSurface,
  );
}

YamlMap _readYamlMap(String yamlSource) {
  final parsed = loadYaml(yamlSource);
  if (parsed is! YamlMap) {
    throw StateError('public API registry must be a YAML map');
  }

  return parsed;
}

Set<String> _readStringSet(YamlMap parsed, String key) {
  final value = parsed[key];
  if (value is! YamlList) {
    throw StateError('$key must be a YAML list');
  }

  final names = <String>[];
  for (final entry in value.nodes) {
    final item = entry.value;
    if (item is! String) {
      throw StateError('$key must contain only strings');
    }
    names.add(item);
  }

  final duplicates = _duplicates(names);
  if (duplicates.isNotEmpty) {
    throw StateError('$key contains duplicate entries: ${_list(duplicates)}');
  }

  return names.toSet();
}

Set<String> _duplicates(Iterable<String> names) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final name in names) {
    if (!seen.add(name)) {
      duplicates.add(name);
    }
  }

  return duplicates;
}

String _list(Iterable<String> names) {
  final sorted = names.toList()..sort();

  return sorted.join(', ');
}

final class PublicApiRegistry {
  const PublicApiRegistry({
    required this.publicExports,
    required this.retiredPublicExports,
    required this.diagnosticsPublicSurface,
  });

  final Set<String> publicExports;
  final Set<String> retiredPublicExports;
  final Set<String> diagnosticsPublicSurface;
}
