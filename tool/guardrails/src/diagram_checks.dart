import 'dart:io';

import 'package:yaml/yaml.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

List<GuardrailViolation> checkRequiredDiagramsPresent() {
  final catalog = _readDiagramCatalog();
  final ids = _requiredDiagramIds().union(_p0RegistryDiagramIds());
  final missing = ids.where((id) => !_isPresentInCatalogAndDisk(id, catalog));

  if (missing.isEmpty) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'diagrams.all_required_present',
      path: 'docs/diagrams/README.md',
      message: 'missing required P0 diagrams: ${missing.join(', ')}',
    ),
  ];
}

Set<String> _requiredDiagramIds() {
  return {'c4_context', 'c4_container', 'c4_component_runtime'};
}

Set<String> _p0RegistryDiagramIds() {
  final sections =
      loadYaml(
            File(
              '$repositoryRoot/docs/_registry/sections.yaml',
            ).readAsStringSync(),
          )
          as YamlList;

  return sections
      .cast<YamlMap>()
      .where(_feedsP0)
      .expand(_diagramsForSection)
      .where(_requiredDiagramIds().contains)
      .toSet();
}

bool _feedsP0(YamlMap section) {
  final phases = (section['phases'] as YamlList?)?.cast<String>() ?? const [];

  return phases.contains('P0');
}

Iterable<String> _diagramsForSection(YamlMap section) {
  return (section['diagrams'] as YamlList?)?.cast<String>() ?? const [];
}

bool _isPresentInCatalogAndDisk(String id, String catalog) {
  final path = 'docs/diagrams/$id.mmd';

  return catalog.contains('Planned path: `$path`') &&
      File('$repositoryRoot/$path').existsSync();
}

String _readDiagramCatalog() {
  return File('$repositoryRoot/docs/diagrams/README.md').readAsStringSync();
}
