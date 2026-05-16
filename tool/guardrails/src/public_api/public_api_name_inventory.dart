import 'dart:io';

import 'package:yaml/yaml.dart';

final class NameInventory {
  const NameInventory({required this.names, required this.violations});

  final Set<String> names;
  final List<String> violations;
}

NameInventory readExpectedPublicNames(Directory root) {
  final registry = File('${root.path}/docs/_registry/public_api_v1.yaml');
  if (!registry.existsSync()) {
    return const NameInventory(
      names: <String>{},
      violations: <String>['Missing public API registry'],
    );
  }

  final yaml = loadYaml(registry.readAsStringSync());
  if (yaml is! YamlMap || !_hasStringList(yaml['public_exports'])) {
    return const NameInventory(
      names: <String>{},
      violations: <String>['Invalid public API registry shape'],
    );
  }

  return NameInventory(
    names: (yaml['public_exports'] as YamlList).cast<String>().toSet(),
    violations: const <String>[],
  );
}

NameInventory readLegacyPublicNames(Directory root) {
  final golden = File(
    '${root.path}/legacy/iwb_canvas_engine/tool/goldens/'
    'public_api_symbols.txt',
  );

  if (!golden.existsSync()) {
    return const NameInventory(
      names: <String>{},
      violations: <String>['Missing legacy public symbol golden'],
    );
  }

  return NameInventory(
    names: golden
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet(),
    violations: const <String>[],
  );
}

bool _hasStringList(Object? value) {
  return value is YamlList && value.every((item) => item is String);
}
