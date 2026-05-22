import 'dart:io';

import 'package:yaml/yaml.dart';

const _diagramRegistryPath = 'docs/_registry/diagrams.yaml';
const _diagramCompatibilityCatalogPath = 'docs/diagrams/README.md';
const _generatedMarker =
    '<!-- GENERATED: docs/tool/sync_generated_docs.dart from docs/_registry/diagrams.yaml -->';

void main(List<String> arguments) {
  final checkOnly = arguments.contains('--check');
  final result = _syncGeneratedDocs(checkOnly: checkOnly);

  if (result.errors.isNotEmpty) {
    stderr.writeln(
      checkOnly
          ? 'Generated docs check failed:'
          : 'Generated docs sync failed:',
    );
    for (final error in result.errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  if (checkOnly) {
    stdout.writeln('Generated docs check passed.');
    return;
  }

  if (result.changedFiles.isEmpty) {
    stdout.writeln('Generated docs already up to date.');
    return;
  }

  stdout.writeln('Generated docs synced:');
  for (final path in result.changedFiles) {
    stdout.writeln('- $path');
  }
}

class _GeneratedDocsSyncResult {
  const _GeneratedDocsSyncResult({
    required this.errors,
    required this.changedFiles,
  });

  final List<String> errors;
  final List<String> changedFiles;
}

class _CommandResult {
  const _CommandResult({required this.description, required this.exitCode});

  final String description;
  final int exitCode;
}

class _DiagramEntry {
  const _DiagramEntry({
    required this.id,
    required this.kind,
    required this.plannedPath,
    required this.classification,
    required this.relatedPhases,
    required this.relatedSections,
    required this.graphViewSource,
  });

  final String id;
  final String kind;
  final String plannedPath;
  final String classification;
  final List<String> relatedPhases;
  final List<String> relatedSections;
  final String graphViewSource;

  bool get isGenerated => classification == 'generated';
}

_GeneratedDocsSyncResult _syncGeneratedDocs({required bool checkOnly}) {
  final errors = <String>[];
  final changedFiles = <String>[];

  for (final command in _runDelegatedGenerators(checkOnly: checkOnly)) {
    if (command.exitCode != 0) {
      errors.add('${command.description} exited ${command.exitCode}');
    }
  }

  final diagrams = _loadDiagrams(errors);
  if (errors.isEmpty) {
    _syncDiagramCompatibilityCatalog(
      diagrams,
      checkOnly: checkOnly,
      errors: errors,
      changedFiles: changedFiles,
    );
  }

  return _GeneratedDocsSyncResult(errors: errors, changedFiles: changedFiles);
}

List<_CommandResult> _runDelegatedGenerators({required bool checkOnly}) {
  final contextArgs = [
    'run',
    'docs/tool/generate_context_capsules.dart',
    if (checkOnly) '--check',
  ];
  final graphArgs = [
    'run',
    'tool/architecture_graph/generate_views.dart',
    '--phase',
    'P4',
    if (checkOnly) '--check',
  ];

  return [
    _runCommand('context capsule generator', contextArgs),
    _runCommand('architecture graph view generator', graphArgs),
  ];
}

_CommandResult _runCommand(String description, List<String> arguments) {
  final result = Process.runSync(Platform.resolvedExecutable, arguments);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  return _CommandResult(description: description, exitCode: result.exitCode);
}

List<_DiagramEntry> _loadDiagrams(List<String> errors) {
  final entries = <_DiagramEntry>[];
  final seenIds = <String>{};
  final seenPaths = <String>{};
  final yaml = _loadYamlList(_diagramRegistryPath, errors);

  for (final item in yaml) {
    if (item is! YamlMap) {
      errors.add('$_diagramRegistryPath must contain only YAML map entries');
      continue;
    }
    final entry = _diagramEntry(item, errors);
    if (entry.id.isEmpty || entry.plannedPath.isEmpty) {
      continue;
    }
    if (!seenIds.add(entry.id)) {
      errors.add('duplicate diagram id ${entry.id}');
      continue;
    }
    if (!seenPaths.add(entry.plannedPath)) {
      errors.add('duplicate diagram path ${entry.plannedPath}');
    }
    if (!File(entry.plannedPath).existsSync()) {
      errors.add('${entry.id} references missing file ${entry.plannedPath}');
    }
    if (entry.classification != 'semantic' &&
        entry.classification != 'generated') {
      errors.add('${entry.id} classification must be semantic or generated');
    }
    if (entry.isGenerated &&
        entry.graphViewSource != 'docs/architecture/architecture_graph.yaml') {
      errors.add('${entry.id} generated diagram must name graph view source');
    }
    if (!entry.isGenerated && entry.graphViewSource != 'none') {
      errors.add(
        '${entry.id} semantic diagram must not name graph view source',
      );
    }
    entries.add(entry);
  }

  return entries;
}

_DiagramEntry _diagramEntry(YamlMap map, List<String> errors) {
  final id = _stringField(map, 'id', 'diagram entry', errors);
  return _DiagramEntry(
    id: id,
    kind: _stringField(map, 'kind', id, errors),
    plannedPath: _stringField(map, 'planned_path', id, errors),
    classification: _stringField(map, 'classification', id, errors),
    relatedPhases: _stringListField(map, 'related_phases', id, errors),
    relatedSections: _stringListField(map, 'related_sections', id, errors),
    graphViewSource: _stringField(map, 'graph_view_source', id, errors),
  );
}

void _syncDiagramCompatibilityCatalog(
  List<_DiagramEntry> diagrams, {
  required bool checkOnly,
  required List<String> errors,
  required List<String> changedFiles,
}) {
  final expected = _renderDiagramCompatibilityCatalog(diagrams);
  final file = File(_diagramCompatibilityCatalogPath);
  final actual = file.existsSync() ? file.readAsStringSync() : '';

  if (actual == expected) {
    return;
  }
  if (checkOnly) {
    errors.add(
      '$_diagramCompatibilityCatalogPath is not generated from $_diagramRegistryPath',
    );
    return;
  }

  file.writeAsStringSync(expected);
  changedFiles.add(_diagramCompatibilityCatalogPath);
}

String _renderDiagramCompatibilityCatalog(List<_DiagramEntry> diagrams) {
  final generated = diagrams.where((diagram) => diagram.isGenerated).toList();
  final semantic = diagrams.where((diagram) => !diagram.isGenerated).toList();
  final buffer = StringBuffer()
    ..writeln(_generatedMarker)
    ..writeln('# Diagram catalog')
    ..writeln()
    ..writeln(
      'Every item below is a required Mermaid deliverable. The catalog links docs to',
    )
    ..writeln('the planned Mermaid file paths under `docs/diagrams/`.')
    ..writeln(
      'Frame, cache, lifecycle, and public edit diagrams use the public runtime state',
    )
    ..writeln(
      'model: `CanvasRuntime.state` carries runtime-visible revisions, runtime view',
    )
    ..writeln(
      'camera is distinct from persisted document camera, and retired separate public',
    )
    ..writeln('listener getters are not diagram seams.')
    ..writeln()
    ..writeln(
      'Generated graph-backed Mermaid files live under the generated diagrams',
    )
    ..writeln('subdirectory. Their source of truth is')
    ..writeln(
      '`docs/architecture/architecture_graph.yaml`; regenerate or check them with:',
    )
    ..writeln()
    ..writeln('```bash')
    ..writeln('dart run tool/architecture_graph/generate_views.dart --phase P4')
    ..writeln(
      'dart run tool/architecture_graph/generate_views.dart --phase P4 --check',
    )
    ..writeln('```')
    ..writeln()
    ..writeln(
      'Handwritten sequence, state, C4, lifecycle, and data-flow diagrams remain',
    )
    ..writeln(
      'semantic diagrams and are not replaced by the generated topology views.',
    )
    ..writeln()
    ..writeln('Current generated outputs:')
    ..writeln();

  for (final diagram in generated) {
    buffer.writeln('- `${diagram.plannedPath}`');
  }

  for (final diagram in semantic) {
    buffer
      ..writeln()
      ..writeln('## ${diagram.id}')
      ..writeln()
      ..writeln('- Kind: `${diagram.kind}`')
      ..writeln('- Planned path: `${diagram.plannedPath}`')
      ..writeln('- Related phases: ${_codeList(diagram.relatedPhases)}')
      ..writeln('- Related sections: ${_codeList(diagram.relatedSections)}');
  }

  return buffer.toString();
}

YamlList _loadYamlList(String path, List<String> errors) {
  final file = File(path);
  if (!file.existsSync()) {
    errors.add('missing required file $path');
    return loadYaml('[]') as YamlList;
  }
  final value = loadYaml(file.readAsStringSync());
  if (value is YamlList) {
    return value;
  }
  errors.add('$path must contain a YAML list');
  return loadYaml('[]') as YamlList;
}

String _stringField(
  YamlMap map,
  String field,
  String owner,
  List<String> errors,
) {
  final value = map[field];
  if (value is String) {
    return value;
  }
  errors.add('$owner must have string field $field');
  return '';
}

List<String> _stringListField(
  YamlMap map,
  String field,
  String owner,
  List<String> errors,
) {
  final value = map[field];
  if (value is! YamlList) {
    errors.add('$owner must have list field $field');
    return const [];
  }

  final values = <String>[];
  for (final item in value) {
    if (item is String) {
      values.add(item);
    } else {
      errors.add('$owner field $field must contain only strings');
    }
  }
  return values;
}

String _codeList(List<String> values) {
  return values.map((value) => '`$value`').join(', ');
}
