import 'dart:io';

import 'package:yaml/yaml.dart';

const _sectionsRegistryPath = 'docs/_registry/sections.yaml';
const _donorsRegistryPath = 'docs/_registry/donors.yaml';
const _diagramRegistryPath = 'docs/_registry/diagrams.yaml';
const _diagramCatalogPath = 'docs/diagrams/catalog.md';
const _retiredDiagramReadmePath = 'docs/diagrams/README.md';
const _contextCoveragePath = 'docs/indexes/context_coverage.md';
const _diagramGeneratedMarker =
    '<!-- GENERATED: docs/tool/sync_generated_docs.dart from docs/_registry/diagrams.yaml -->';
const _indexGeneratedMarker =
    '<!-- GENERATED: docs/tool/sync_generated_docs.dart from docs/_registry/sections.yaml and docs/_registry/donors.yaml -->';
const _selectedArchitectureGraphPhase = 'P9';

const _generatedIndexPaths = [
  'docs/indexes/by_phase.md',
  'docs/indexes/by_subsystem.md',
  'docs/indexes/by_guardrail.md',
  'docs/indexes/by_test_area.md',
  'docs/indexes/donor_to_phase.md',
];

const _phaseOrder = [
  'P0',
  'P1',
  'P2',
  'P3',
  'P4',
  'P5',
  'P6',
  'P7',
  'P8',
  'P9',
  'P10',
  'P11',
  'P12',
  'P13',
  'P14',
];

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
    required this.file,
    required this.classification,
    required this.relatedPhases,
    required this.relatedSections,
    required this.graphViewSource,
  });

  final String id;
  final String kind;
  final String file;
  final String classification;
  final List<String> relatedPhases;
  final List<String> relatedSections;
  final String graphViewSource;

  bool get isGenerated => classification == 'generated';
}

class _SectionEntry {
  const _SectionEntry({
    required this.id,
    required this.title,
    required this.phases,
    required this.subsystems,
    required this.mustRead,
    required this.donors,
    required this.diagrams,
    required this.guardrails,
    required this.tests,
  });

  final String id;
  final String title;
  final List<String> phases;
  final List<String> subsystems;
  final List<String> mustRead;
  final List<String> donors;
  final List<String> diagrams;
  final List<String> guardrails;
  final List<String> tests;
}

class _DonorEntry {
  const _DonorEntry({
    required this.id,
    required this.decision,
    required this.targetPhases,
    required this.targetOwner,
  });

  final String id;
  final String decision;
  final List<String> targetPhases;
  final String targetOwner;
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
  final sections = _loadSections(errors);
  final donors = _loadDonors(errors);
  if (errors.isEmpty) {
    _syncDiagramCatalog(
      diagrams,
      checkOnly: checkOnly,
      errors: errors,
      changedFiles: changedFiles,
    );
    _syncGeneratedIndexes(
      sections,
      donors,
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
    _selectedArchitectureGraphPhase,
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
    if (entry.id.isEmpty) {
      errors.add(
        '$_diagramRegistryPath contains a diagram entry with empty id',
      );
      continue;
    }
    if (entry.file.isEmpty) {
      errors.add('${entry.id} must have a file');
      continue;
    }
    if (!seenIds.add(entry.id)) {
      errors.add('duplicate diagram id ${entry.id}');
      continue;
    }
    if (!seenPaths.add(entry.file)) {
      errors.add('duplicate diagram path ${entry.file}');
    }
    if (!File(entry.file).existsSync()) {
      errors.add('${entry.id} references missing file ${entry.file}');
    }
    if (entry.relatedPhases.isEmpty) {
      errors.add('${entry.id} must have at least one related phase');
    }
    if (entry.relatedSections.isEmpty) {
      errors.add('${entry.id} must have at least one related section');
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

List<_SectionEntry> _loadSections(List<String> errors) {
  final entries = <_SectionEntry>[];
  final seenIds = <String>{};
  final yaml = _loadYamlList(_sectionsRegistryPath, errors);

  for (final item in yaml) {
    if (item is! YamlMap) {
      errors.add('$_sectionsRegistryPath must contain only YAML map entries');
      continue;
    }
    final entry = _sectionEntry(item, errors);
    if (entry.id.isEmpty) {
      continue;
    }
    if (!seenIds.add(entry.id)) {
      errors.add('duplicate section id ${entry.id}');
      continue;
    }
    _checkExplicitCoverage(entry, errors);
    entries.add(entry);
  }

  return entries;
}

List<_DonorEntry> _loadDonors(List<String> errors) {
  final entries = <_DonorEntry>[];
  final seenIds = <String>{};
  final yaml = _loadYamlList(_donorsRegistryPath, errors);

  for (final item in yaml) {
    if (item is! YamlMap) {
      errors.add('$_donorsRegistryPath must contain only YAML map entries');
      continue;
    }
    final entry = _donorEntry(item, errors);
    if (entry.id.isEmpty) {
      continue;
    }
    if (!seenIds.add(entry.id)) {
      errors.add('duplicate donor id ${entry.id}');
      continue;
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
    file: _stringField(map, 'file', id, errors),
    classification: _stringField(map, 'classification', id, errors),
    relatedPhases: _stringListField(map, 'related_phases', id, errors),
    relatedSections: _stringListField(map, 'related_sections', id, errors),
    graphViewSource: _stringField(map, 'graph_view_source', id, errors),
  );
}

_SectionEntry _sectionEntry(YamlMap map, List<String> errors) {
  final id = _stringField(map, 'id', 'section entry', errors);
  return _SectionEntry(
    id: id,
    title: _stringField(map, 'title', id, errors),
    phases: _stringListField(map, 'phases', id, errors),
    subsystems: _stringListField(map, 'subsystems', id, errors),
    mustRead: _stringListField(map, 'must_read', id, errors),
    donors: _stringListField(map, 'donors', id, errors),
    diagrams: _stringListField(map, 'diagrams', id, errors),
    guardrails: _stringListField(map, 'guardrails', id, errors),
    tests: _stringListField(map, 'tests', id, errors),
  );
}

_DonorEntry _donorEntry(YamlMap map, List<String> errors) {
  final id = _stringField(map, 'id', 'donor entry', errors);
  return _DonorEntry(
    id: id,
    decision: _stringField(map, 'decision', id, errors),
    targetPhases: _stringListField(map, 'target_phases', id, errors),
    targetOwner: _stringField(map, 'target_owner', id, errors),
  );
}

void _checkExplicitCoverage(_SectionEntry section, List<String> errors) {
  final coverageFields = {
    'must_read': section.mustRead,
    'donors': section.donors,
    'diagrams': section.diagrams,
    'guardrails': section.guardrails,
    'tests': section.tests,
  };

  for (final entry in coverageFields.entries) {
    if (entry.value.isEmpty) {
      errors.add('${section.id} must have explicit ${entry.key} coverage');
    }
  }
  if (section.subsystems.isEmpty) {
    errors.add('${section.id} must have explicit subsystems coverage');
  }
}

void _syncDiagramCatalog(
  List<_DiagramEntry> diagrams, {
  required bool checkOnly,
  required List<String> errors,
  required List<String> changedFiles,
}) {
  if (File(_retiredDiagramReadmePath).existsSync()) {
    if (checkOnly) {
      errors.add('$_retiredDiagramReadmePath must not remain as an entrypoint');
    } else {
      File(_retiredDiagramReadmePath).deleteSync();
      changedFiles.add(_retiredDiagramReadmePath);
    }
  }

  final expected = _renderDiagramCatalog(diagrams);
  _syncGeneratedFile(
    _diagramCatalogPath,
    expected,
    checkOnly: checkOnly,
    errors: errors,
    changedFiles: changedFiles,
  );
}

void _syncGeneratedIndexes(
  List<_SectionEntry> sections,
  List<_DonorEntry> donors, {
  required bool checkOnly,
  required List<String> errors,
  required List<String> changedFiles,
}) {
  if (File(_contextCoveragePath).existsSync()) {
    if (checkOnly) {
      errors.add('$_contextCoveragePath must not remain as an entrypoint');
    } else {
      File(_contextCoveragePath).deleteSync();
      changedFiles.add(_contextCoveragePath);
    }
  }

  _checkIndexInventory(errors);

  final outputs = {
    'docs/indexes/by_phase.md': _renderByPhaseIndex(sections),
    'docs/indexes/by_subsystem.md': _renderBySubsystemIndex(sections),
    'docs/indexes/by_guardrail.md': _renderByGuardrailIndex(sections),
    'docs/indexes/by_test_area.md': _renderByTestAreaIndex(sections),
    'docs/indexes/donor_to_phase.md': _renderDonorToPhaseIndex(donors),
  };

  for (final entry in outputs.entries) {
    _syncGeneratedFile(
      entry.key,
      entry.value,
      checkOnly: checkOnly,
      errors: errors,
      changedFiles: changedFiles,
    );
  }
}

void _checkIndexInventory(List<String> errors) {
  final allowed = _generatedIndexPaths.toSet();
  final directory = Directory('docs/indexes');
  if (!directory.existsSync()) {
    return;
  }

  for (final file in directory.listSync().whereType<File>()) {
    if (!file.path.endsWith('.md')) {
      continue;
    }
    if (!allowed.contains(file.path)) {
      errors.add('${file.path} is not a locked generated index');
    }
  }
}

void _syncGeneratedFile(
  String path,
  String expected, {
  required bool checkOnly,
  required List<String> errors,
  required List<String> changedFiles,
}) {
  final file = File(path);
  final actual = file.existsSync() ? file.readAsStringSync() : '';
  if (actual == expected) {
    return;
  }
  if (checkOnly) {
    errors.add('$path is not generated from registry data');
    return;
  }
  file.writeAsStringSync(expected);
  changedFiles.add(path);
}

String _renderDiagramCatalog(List<_DiagramEntry> diagrams) {
  final generated = diagrams.where((diagram) => diagram.isGenerated).toList();
  final semantic = diagrams.where((diagram) => !diagram.isGenerated).toList();
  final buffer = StringBuffer()
    ..writeln(_diagramGeneratedMarker)
    ..writeln('# Diagram catalog')
    ..writeln()
    ..writeln(
      'Every item below is a required Mermaid deliverable. The catalog links docs to',
    )
    ..writeln('the Mermaid files under `docs/diagrams/`.')
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
    ..writeln(
      'dart run tool/architecture_graph/generate_views.dart --phase $_selectedArchitectureGraphPhase',
    )
    ..writeln(
      'dart run tool/architecture_graph/generate_views.dart --phase $_selectedArchitectureGraphPhase --check',
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
    buffer
      ..writeln('- `${diagram.id}`')
      ..writeln('  - File: `${diagram.file}`')
      ..writeln('  - Kind: `${diagram.kind}`')
      ..writeln('  - Classification: `${diagram.classification}`')
      ..writeln('  - Related phases: ${_codeList(diagram.relatedPhases)}')
      ..writeln('  - Related sections: ${_codeList(diagram.relatedSections)}')
      ..writeln('  - Graph view source: `${diagram.graphViewSource}`');
  }

  for (final diagram in semantic) {
    buffer
      ..writeln()
      ..writeln('## ${diagram.id}')
      ..writeln()
      ..writeln('- Kind: `${diagram.kind}`')
      ..writeln('- Classification: `${diagram.classification}`')
      ..writeln('- File: `${diagram.file}`')
      ..writeln('- Related phases: ${_codeList(diagram.relatedPhases)}')
      ..writeln('- Related sections: ${_codeList(diagram.relatedSections)}')
      ..writeln('- Graph view source: `${diagram.graphViewSource}`');
  }

  return buffer.toString();
}

String _renderByPhaseIndex(List<_SectionEntry> sections) {
  final buffer = _indexBuffer(
    'By phase',
    'Sections grouped by implementation phase from `$_sectionsRegistryPath`.',
  );
  for (final phase in _phaseOrder) {
    final entries = sections
        .where((section) => section.phases.contains(phase))
        .toList();
    if (entries.isEmpty) {
      continue;
    }
    _writeHeading(buffer, phase);
    _writeSectionBullets(buffer, entries);
  }
  return buffer.toString();
}

String _renderBySubsystemIndex(List<_SectionEntry> sections) {
  final subsystems = <String, List<_SectionEntry>>{};
  for (final section in sections) {
    for (final subsystem in section.subsystems) {
      if (subsystem == 'none') {
        continue;
      }
      subsystems.putIfAbsent(subsystem, () => []).add(section);
    }
  }

  final buffer = _indexBuffer(
    'By subsystem',
    'Sections grouped by subsystem from `$_sectionsRegistryPath`.',
  );
  for (final subsystem in subsystems.keys.toList()..sort()) {
    _writeHeading(buffer, subsystem);
    _writeSectionBullets(buffer, subsystems[subsystem] ?? const []);
  }
  return buffer.toString();
}

String _renderByGuardrailIndex(List<_SectionEntry> sections) {
  final guardrails = <String, List<_SectionEntry>>{};
  for (final section in sections) {
    for (final guardrail in section.guardrails) {
      if (guardrail == 'none') {
        continue;
      }
      guardrails.putIfAbsent(guardrail, () => []).add(section);
    }
  }

  final buffer = _indexBuffer(
    'By guardrail',
    'Guardrail coverage generated from `$_sectionsRegistryPath`.',
  );
  for (final guardrail in guardrails.keys.toList()..sort()) {
    final entries = guardrails[guardrail] ?? const <_SectionEntry>[];
    _writeHeading(buffer, guardrail);
    buffer
      ..writeln('- Sections: ${_sectionCodeList(entries)}')
      ..writeln();
  }
  return buffer.toString();
}

String _renderByTestAreaIndex(List<_SectionEntry> sections) {
  final tests = <String, List<_SectionEntry>>{};
  for (final section in sections) {
    for (final test in section.tests) {
      if (test == 'none') {
        continue;
      }
      tests.putIfAbsent(test, () => []).add(section);
    }
  }

  final buffer = _indexBuffer(
    'By test area',
    'Test coverage generated from `$_sectionsRegistryPath`.',
  );
  for (final test in tests.keys.toList()..sort()) {
    final entries = tests[test] ?? const <_SectionEntry>[];
    _writeHeading(buffer, test);
    buffer
      ..writeln('- Sections: ${_sectionCodeList(entries)}')
      ..writeln();
  }
  return buffer.toString();
}

String _renderDonorToPhaseIndex(List<_DonorEntry> donors) {
  final buffer = _indexBuffer(
    'Donor to phase',
    'Donor targets generated from `$_donorsRegistryPath`.',
  );
  for (final donor in donors) {
    _writeHeading(buffer, donor.id);
    buffer
      ..writeln('- Decision: `${donor.decision}`')
      ..writeln('- Target phases: ${_codeList(donor.targetPhases)}')
      ..writeln('- Target owner: ${donor.targetOwner}')
      ..writeln();
  }
  return buffer.toString();
}

StringBuffer _indexBuffer(String title, String description) {
  return StringBuffer()
    ..writeln(_indexGeneratedMarker)
    ..writeln('# $title')
    ..writeln()
    ..writeln(description)
    ..writeln();
}

void _writeHeading(StringBuffer buffer, String heading) {
  buffer
    ..writeln('## $heading')
    ..writeln();
}

void _writeSectionBullets(StringBuffer buffer, List<_SectionEntry> sections) {
  for (final section in sections) {
    buffer.writeln('- `${section.id}` - ${section.title}');
  }
  buffer.writeln();
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
    if (value.isEmpty) {
      errors.add('$owner must have non-empty string field $field');
    }
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
  final seen = <String>{};
  for (final item in value) {
    if (item is String) {
      if (item.isEmpty) {
        errors.add('$owner field $field contains an empty value');
        continue;
      }
      if (!seen.add(item)) {
        errors.add('$owner field $field contains duplicate value $item');
      }
      values.add(item);
    } else {
      errors.add('$owner field $field must contain only strings');
    }
  }
  return values;
}

String _codeList(List<String> values) {
  if (values.isEmpty) {
    return '`none`';
  }
  return values.map((value) => '`$value`').join(', ');
}

String _sectionCodeList(List<_SectionEntry> sections) {
  return _codeList(sections.map((section) => section.id).toList());
}
