// Structural documentation checker only.
//
// This tool verifies documentation entrypoints, registries, navigation links,
// diagram catalog membership, and phase/read-first references. Do not add
// checks that match free-form Markdown wording, Mermaid edge text, or runtime
// architecture invariants. Those constraints belong in structured registries,
// generated documentation, analyzer/lint rules, Dart tests, or benchmarks.

import 'dart:io';

import 'package:yaml/yaml.dart';

const _sectionsRegistryPath = 'docs/_registry/sections.yaml';
const _donorsRegistryPath = 'docs/_registry/donors.yaml';
const _diagramCatalogPath = 'docs/diagrams/README.md';

const _phaseDocs = {
  'P0': 'docs/implementation/p0_package_skeleton_and_hard_boundaries.md',
  'P1': 'docs/implementation/p1_legacy_oracle_lock.md',
  'P1.5': 'docs/implementation/p1_5_v1_scope_gate_before_public_api_freeze.md',
  'P2': 'docs/implementation/p2_public_api_v1_freeze.md',
  'P3': 'docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md',
  'P4': 'docs/implementation/p4_runtime_spine.md',
  'P5': 'docs/implementation/p5_edit_core.md',
  'P6': 'docs/implementation/p6_load_document.md',
  'P7': 'docs/implementation/p7_resources_and_images.md',
  'P8': 'docs/implementation/p8_geometry_and_spatial.md',
  'P9': 'docs/implementation/p9_frame_rendering_and_caches.md',
  'P10': 'docs/implementation/p10_selection_and_move.md',
  'P11': 'docs/implementation/p11_draw_tools.md',
  'P12': 'docs/implementation/p12_eraser_and_text_request.md',
  'P13': 'docs/implementation/p13_flutter_surface.md',
  'P14': 'docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md',
};

const _globalReadFirstSections = {
  'section_22_guardrails_machine_checks',
  'section_23_tests',
  'section_27_final_release_gates',
};

const _donorRelatedSectionCatalogExclusions = {
  'section_23_tests',
  'section_27_final_release_gates',
};

const _allowedDonorDecisions = {
  'copy',
  'copy_adapt',
  'adapt',
  'adapt_rewrite',
  'rewrite_reference',
  'avoid',
};

const _requiredDonorListFields = {
  'source_paths',
  'target_phases',
  'use_for',
  'do_not_copy',
  'required_tests',
  'blocks',
  'related_sections',
};

const _markdownRoots = [
  'docs/architecture',
  'docs/contracts',
  'docs/implementation',
  'docs/verification',
  'docs/donors',
  'docs/diagrams',
  'docs/indexes',
];

final _errors = <String>[];

void main() {
  _checkRequiredEntrypoints();

  final sections = _loadSections();
  final donors = _loadDonors();
  final sectionIds = sections.map((section) => section.id).toSet();
  final donorIds = donors.map((donor) => donor.id).toSet();
  final diagrams = _loadDiagramCatalog();

  _checkSectionReferences(sections, sectionIds, donorIds);
  _checkDonorReferences(sections, donors, sectionIds);
  _checkDiagramCatalogRegistrySymmetry(sections, sectionIds, diagrams);
  _checkImplementationDiagramPhaseReferences(diagrams);
  _checkMarkdownPaths(sectionIds);
  _checkMustReadGraph(sections, sectionIds);
  _checkPhaseReadFirstReferences(sections, sectionIds);

  if (_errors.isNotEmpty) {
    stderr.writeln('Docs check failed:');
    for (final error in _errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Docs check passed.');
}

class _SectionEntry {
  const _SectionEntry({
    required this.id,
    required this.file,
    required this.title,
    required this.phases,
    required this.mustRead,
    required this.donors,
    required this.diagrams,
    required this.guardrails,
    required this.tests,
    required this.doNotAssume,
  });

  final String id;
  final String file;
  final String title;
  final List<String> phases;
  final List<String> mustRead;
  final List<String> donors;
  final List<String> diagrams;
  final List<String> guardrails;
  final List<String> tests;
  final List<String> doNotAssume;
}

class _DonorEntry {
  const _DonorEntry({
    required this.id,
    required this.decision,
    required this.targetPhases,
    required this.blocks,
    required this.relatedSections,
  });

  final String id;
  final String decision;
  final List<String> targetPhases;
  final List<String> blocks;
  final List<String> relatedSections;
}

class _DiagramEntry {
  const _DiagramEntry({
    required this.id,
    required this.plannedPath,
    required this.relatedSections,
    required this.relatedPhases,
  });

  final String id;
  final String plannedPath;
  final Set<String> relatedSections;
  final Set<String> relatedPhases;
}

void _checkRequiredEntrypoints() {
  const requiredFiles = [
    'docs/README.md',
    'docs/architecture/README.md',
    _sectionsRegistryPath,
    _donorsRegistryPath,
    _diagramCatalogPath,
  ];
  const requiredDirs = [
    'docs/architecture',
    'docs/contracts',
    'docs/implementation',
    'docs/verification',
    'docs/donors',
    'docs/diagrams',
    'docs/indexes',
    'docs/_registry',
    'plan',
  ];

  for (final path in requiredFiles) {
    _requireFile(path);
  }
  for (final path in requiredDirs) {
    _requireDirectory(path);
  }
}

List<_SectionEntry> _loadSections() {
  final sections = <_SectionEntry>[];
  final seenIds = <String>{};

  for (final entry in _loadYamlMapList(_sectionsRegistryPath)) {
    final id = _stringField(entry, 'id', 'section registry entry');
    final file = _stringField(entry, 'file', id);
    final title = _stringField(entry, 'title', id);
    final section = _SectionEntry(
      id: id,
      file: file,
      title: title,
      phases: _stringListField(entry, 'phases', id),
      mustRead: _stringListField(entry, 'must_read', id),
      donors: _stringListField(entry, 'donors', id),
      diagrams: _stringListField(entry, 'diagrams', id),
      guardrails: _stringListField(entry, 'guardrails', id),
      tests: _stringListField(entry, 'tests', id),
      doNotAssume: _stringListField(entry, 'do_not_assume', id),
    );

    if (!seenIds.add(id)) {
      _fail('duplicate section id: $id');
      continue;
    }
    if (file.isNotEmpty) {
      _requireFile(file, source: _sectionsRegistryPath);
    }
    if (title.isEmpty) {
      _fail('$id has an empty title');
    }

    sections.add(section);
  }

  return sections;
}

List<_DonorEntry> _loadDonors() {
  final donors = <_DonorEntry>[];
  final seenIds = <String>{};

  for (final entry in _loadYamlMapList(_donorsRegistryPath)) {
    final id = _stringField(entry, 'id', 'donor registry entry');
    final decision = _stringField(entry, 'decision', id);
    _stringField(entry, 'target_owner', id);
    _stringField(entry, 'notes', id);

    for (final field in _requiredDonorListFields) {
      final values = _stringListField(entry, field, id);
      if (values.isEmpty) {
        _fail('donor $id has empty $field');
      }
    }

    final donor = _DonorEntry(
      id: id,
      decision: decision,
      targetPhases: _stringListField(entry, 'target_phases', id),
      blocks: _stringListField(entry, 'blocks', id),
      relatedSections: _stringListField(entry, 'related_sections', id),
    );

    if (!seenIds.add(id)) {
      _fail('duplicate donor id: $id');
      continue;
    }
    if (!_allowedDonorDecisions.contains(decision)) {
      _fail('donor $id has unsupported decision $decision');
    }

    donors.add(donor);
  }

  return donors;
}

void _checkSectionReferences(
  List<_SectionEntry> sections,
  Set<String> sectionIds,
  Set<String> donorIds,
) {
  for (final section in sections) {
    _checkNoneSentinel(section.id, 'must_read', section.mustRead);
    _checkNoneSentinel(section.id, 'donors', section.donors);
    _checkNoneSentinel(section.id, 'diagrams', section.diagrams);
    _checkNoneSentinel(section.id, 'guardrails', section.guardrails);
    _checkNoneSentinel(section.id, 'tests', section.tests);
    _checkNoneSentinel(section.id, 'do_not_assume', section.doNotAssume);

    if (section.phases.isEmpty) {
      _fail('${section.id} has no phases');
    }
    for (final phase in section.phases) {
      if (!_phaseDocs.containsKey(phase)) {
        _fail('${section.id} references unknown phase $phase');
      }
    }

    for (final reference in section.mustRead) {
      if (reference == 'none') {
        continue;
      }
      if (reference.startsWith('section_')) {
        if (!sectionIds.contains(reference)) {
          _fail('${section.id} references unknown section id $reference');
        }
      } else if (reference.startsWith('docs/')) {
        _requirePath(reference, source: _sectionsRegistryPath);
      } else {
        _fail('${section.id} has unsupported must_read reference $reference');
      }
    }

    for (final donorId in section.donors) {
      if (donorId == 'none') {
        continue;
      }
      if (!donorIds.contains(donorId)) {
        _fail('${section.id} references unknown donor id $donorId');
      }
    }
  }
}

void _checkDonorReferences(
  List<_SectionEntry> sections,
  List<_DonorEntry> donors,
  Set<String> sectionIds,
) {
  final donorsById = {for (final donor in donors) donor.id: donor};
  final registryDonorSections = <String, Set<String>>{};

  for (final donor in donors) {
    _checkNoneSentinel(donor.id, 'related_sections', donor.relatedSections);
    for (final sectionId in donor.relatedSections) {
      if (!sectionIds.contains(sectionId)) {
        _fail('donor ${donor.id} references unknown section id $sectionId');
      }
    }

    if (donor.decision == 'avoid') {
      if (donor.targetPhases.length != 1 ||
          donor.targetPhases.single != 'avoid') {
        _fail('avoid donor ${donor.id} must use target_phases: avoid');
      }
    } else {
      for (final phase in donor.targetPhases) {
        if (!_phaseDocs.containsKey(phase)) {
          _fail('donor ${donor.id} has unknown target phase $phase');
        }
      }
      for (final block in donor.blocks) {
        if (!_phaseDocs.containsKey(block)) {
          _fail('donor ${donor.id} has non-phase block $block');
        }
      }
    }
  }

  for (final section in sections) {
    for (final donorId in section.donors) {
      if (donorId == 'none' || !donorsById.containsKey(donorId)) {
        continue;
      }
      if (!_donorRelatedSectionCatalogExclusions.contains(section.id)) {
        registryDonorSections
            .putIfAbsent(donorId, () => <String>{})
            .add(section.id);
      }
    }
  }

  for (final entry in registryDonorSections.entries) {
    final donor = donorsById[entry.key];
    if (donor == null) {
      continue;
    }
    final relatedSections = donor.relatedSections.toSet();
    for (final sectionId in entry.value) {
      if (!relatedSections.contains(sectionId)) {
        _fail(
          'donor ${donor.id} is used by $sectionId in $_sectionsRegistryPath, '
          'but $_donorsRegistryPath does not list $sectionId as related',
        );
      }
    }
  }
}

Map<String, _DiagramEntry> _loadDiagramCatalog() {
  final catalog = <String, _DiagramEntry>{};
  final text = _read(_diagramCatalogPath);
  final blocks = text.split(RegExp(r'^##\s+', multiLine: true));

  for (final block in blocks.skip(1)) {
    final lines = block.split('\n');
    if (lines.isEmpty) {
      continue;
    }
    final diagramId = lines.first.trim();
    if (diagramId.isEmpty) {
      _fail('$_diagramCatalogPath contains an empty diagram heading');
      continue;
    }
    if (catalog.containsKey(diagramId)) {
      _fail('$_diagramCatalogPath contains duplicate diagram entry $diagramId');
      continue;
    }

    String? plannedPath;
    final phases = <String>{};
    final sections = <String>{};

    for (final line in lines.skip(1)) {
      final plannedPathMatch = RegExp(
        r'^- Planned path: `(docs/diagrams/[^`]+\.mmd)`$',
      ).firstMatch(line);
      if (plannedPathMatch != null) {
        plannedPath = _matchGroup(
          plannedPathMatch,
          1,
          '$_diagramCatalogPath planned path',
        );
        continue;
      }

      final phasesMatch = RegExp(r'^- Related phases: (.+)$').firstMatch(line);
      if (phasesMatch != null) {
        phases.addAll(
          _backtickedValues(
            _matchGroup(phasesMatch, 1, '$_diagramCatalogPath phases'),
          ),
        );
        continue;
      }

      final sectionsMatch = RegExp(
        r'^- Related sections: (.+)$',
      ).firstMatch(line);
      if (sectionsMatch != null) {
        sections.addAll(
          _backtickedValues(
            _matchGroup(sectionsMatch, 1, '$_diagramCatalogPath sections'),
          ),
        );
      }
    }

    final expectedPath = 'docs/diagrams/$diagramId.mmd';
    if (plannedPath == null) {
      _fail(
        '$_diagramCatalogPath catalog entry $diagramId has no planned path',
      );
      plannedPath = expectedPath;
    } else if (plannedPath != expectedPath) {
      _fail(
        '$_diagramCatalogPath catalog entry $diagramId planned path must be '
        '$expectedPath, not $plannedPath',
      );
    }
    _requireFile(expectedPath, source: _diagramCatalogPath);

    if (sections.isEmpty) {
      _fail(
        '$_diagramCatalogPath catalog entry $diagramId has no related sections',
      );
    }
    for (final phase in phases) {
      if (!_phaseDocs.containsKey(phase)) {
        _fail(
          '$_diagramCatalogPath catalog entry $diagramId has unknown phase $phase',
        );
      }
    }

    catalog[diagramId] = _DiagramEntry(
      id: diagramId,
      plannedPath: plannedPath,
      relatedSections: sections,
      relatedPhases: phases,
    );
  }

  return catalog;
}

void _checkDiagramCatalogRegistrySymmetry(
  List<_SectionEntry> sections,
  Set<String> sectionIds,
  Map<String, _DiagramEntry> catalog,
) {
  final registry = <String, Set<String>>{};

  for (final section in sections) {
    for (final diagramId in section.diagrams) {
      if (diagramId == 'none') {
        continue;
      }
      registry.putIfAbsent(diagramId, () => <String>{}).add(section.id);
      if (!catalog.containsKey(diagramId)) {
        _fail(
          '${section.id} references diagram $diagramId, '
          'but $_diagramCatalogPath does not catalog it',
        );
      }
    }
  }

  for (final diagram in catalog.values) {
    final registrySections = registry[diagram.id] ?? const <String>{};

    for (final sectionId in diagram.relatedSections) {
      if (!sectionIds.contains(sectionId)) {
        _fail('$_diagramCatalogPath references unknown section id $sectionId');
        continue;
      }
      if (!registrySections.contains(sectionId)) {
        _fail(
          'diagram ${diagram.id} is related to $sectionId in '
          '$_diagramCatalogPath, but $sectionId does not list ${diagram.id} '
          'in $_sectionsRegistryPath',
        );
      }
    }

    for (final sectionId in registrySections) {
      if (!diagram.relatedSections.contains(sectionId)) {
        _fail(
          '$sectionId lists diagram ${diagram.id} in $_sectionsRegistryPath, '
          'but $_diagramCatalogPath does not list $sectionId under ${diagram.id}',
        );
      }
    }
  }

  final catalogedFiles = catalog.values
      .map((diagram) => diagram.plannedPath)
      .toSet();
  final diagramDir = Directory('docs/diagrams');
  if (!diagramDir.existsSync()) {
    return;
  }
  for (final file in diagramDir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.mmd')) {
      continue;
    }
    if (!catalogedFiles.contains(file.path)) {
      _fail('${file.path} exists but is not cataloged in $_diagramCatalogPath');
    }
  }
}

void _checkImplementationDiagramPhaseReferences(
  Map<String, _DiagramEntry> catalog,
) {
  final phaseReferences = <String, Set<String>>{};

  for (final entry in _phaseDocs.entries) {
    final phase = entry.key;
    final path = entry.value;
    final references = phaseReferences.putIfAbsent(phase, () => <String>{});
    final section = _markdownSection(path, 'Diagrams to read or update');
    if (section == null) {
      continue;
    }

    for (final match in RegExp(
      r'^- `([^`]+)` -> `(docs/diagrams/[^`]+\.mmd)`$',
      multiLine: true,
    ).allMatches(section)) {
      final diagramId = _matchGroup(match, 1, '$path diagram id');
      final diagramPath = _matchGroup(match, 2, '$path diagram path');
      references.add(diagramId);

      final diagram = catalog[diagramId];
      if (diagram == null) {
        _fail('$path references uncataloged diagram $diagramId');
        continue;
      }
      if (diagram.plannedPath != diagramPath) {
        _fail(
          '$path references $diagramId at $diagramPath, '
          'but $_diagramCatalogPath plans ${diagram.plannedPath}',
        );
      }
      if (!diagram.relatedPhases.contains(phase)) {
        _fail(
          '$path references diagram $diagramId, but $_diagramCatalogPath '
          'does not list $phase under $diagramId',
        );
      }
    }
  }

  final p14References = phaseReferences['P14'] ?? const <String>{};
  for (final diagram in catalog.values) {
    if (!diagram.relatedPhases.contains('P14')) {
      continue;
    }
    if (!p14References.contains(diagram.id)) {
      _fail('${_phaseDocs['P14']} must list P14 catalog diagram ${diagram.id}');
    }
  }
}

void _checkMarkdownPaths(Set<String> sectionIds) {
  for (final rootPath in _markdownRoots) {
    final root = Directory(rootPath);
    if (!root.existsSync()) {
      continue;
    }
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.md')) {
        continue;
      }
      final text = file.readAsStringSync();
      _checkSectionIdsInText(file.path, text, sectionIds);
      _checkDocumentPathsInText(file.path, text);
    }
  }

  final readme = 'docs/README.md';
  final text = _read(readme);
  _checkSectionIdsInText(readme, text, sectionIds);
  _checkDocumentPathsInText(readme, text);
}

void _checkMustReadGraph(List<_SectionEntry> sections, Set<String> sectionIds) {
  final graph = <String, List<String>>{};
  for (final section in sections) {
    final references = <String>[];
    for (final reference in section.mustRead) {
      if (reference == 'none' || !reference.startsWith('section_')) {
        continue;
      }
      if (sectionIds.contains(reference)) {
        references.add(reference);
      }
    }
    graph[section.id] = references;
  }

  final visiting = <String>{};
  final visited = <String>{};
  final path = <String>[];

  void visit(String id) {
    if (visited.contains(id)) {
      return;
    }
    if (visiting.contains(id)) {
      final start = path.indexOf(id);
      final cycle = [...path.sublist(start), id].join(' -> ');
      _fail('must_read graph contains a cycle: $cycle');
      return;
    }
    visiting.add(id);
    path.add(id);
    for (final next in graph[id] ?? const <String>[]) {
      visit(next);
    }
    path.removeLast();
    visiting.remove(id);
    visited.add(id);
  }

  for (final id in graph.keys) {
    visit(id);
  }
}

void _checkPhaseReadFirstReferences(
  List<_SectionEntry> sections,
  Set<String> sectionIds,
) {
  final registryPhases = <String, Set<String>>{};
  for (final section in sections) {
    for (final phase in section.phases) {
      registryPhases.putIfAbsent(phase, () => <String>{}).add(section.id);
    }
  }

  for (final phase in registryPhases.keys) {
    final phaseDoc = _phaseDocs[phase];
    if (phaseDoc == null) {
      _fail('phase $phase has no implementation phase document mapping');
    } else {
      _requireFile(phaseDoc, source: _sectionsRegistryPath);
    }
  }

  for (final entry in _phaseDocs.entries) {
    final phase = entry.key;
    final phaseDoc = entry.value;
    final readFirst = _readFirstSectionIds(phaseDoc);
    final registrySections = registryPhases[phase] ?? const <String>{};
    for (final sectionId in readFirst) {
      if (!sectionIds.contains(sectionId)) {
        _fail('$phaseDoc Read first references unknown section $sectionId');
        continue;
      }
      if (!registrySections.contains(sectionId) &&
          !_globalReadFirstSections.contains(sectionId)) {
        _fail(
          '$phaseDoc Read first lists $sectionId, but $sectionId does not feed phase $phase',
        );
      }
    }
  }
}

Set<String> _readFirstSectionIds(String path) {
  final section = _markdownSection(path, 'Read first');
  if (section == null) {
    return const {};
  }
  return RegExp(r'`(section_[^`]+)`')
      .allMatches(section)
      .map((match) => _matchGroup(match, 1, '$path Read first reference'))
      .toSet();
}

String? _markdownSection(String path, String heading) {
  _requireFile(path);
  if (!File(path).existsSync()) {
    return null;
  }
  final text = _read(path);
  final headingMatch = RegExp(
    '^## ${RegExp.escape(heading)}\\s*\$',
    multiLine: true,
  ).firstMatch(text);
  if (headingMatch == null) {
    _fail('$path has no "$heading" section');
    return null;
  }
  final rest = text.substring(headingMatch.end);
  final nextHeading = RegExp(r'^##\s+', multiLine: true).firstMatch(rest);
  return nextHeading == null ? rest : rest.substring(0, nextHeading.start);
}

void _checkNoneSentinel(String owner, String field, List<String> values) {
  if (values.contains('none') && values.length > 1) {
    _fail('$owner $field cannot mix "none" with concrete values');
  }
}

void _checkSectionIdsInText(
  String sourcePath,
  String text,
  Set<String> sectionIds,
) {
  for (final match in RegExp(r'`(section_[^`]+)`').allMatches(text)) {
    final id = match.group(1);
    if (id == null) {
      _fail('$sourcePath contains a malformed section reference');
      continue;
    }
    if (!sectionIds.contains(id)) {
      _fail('$sourcePath references unknown section id $id');
    }
  }
}

void _checkDocumentPathsInText(String sourcePath, String text) {
  final patterns = [RegExp(r'`(docs/[^`]+)`'), RegExp(r'\]\((docs/[^)]+)\)')];
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(text)) {
      final path = match.group(1);
      if (path == null) {
        _fail('$sourcePath contains a malformed document path reference');
        continue;
      }
      if (path.contains(' and ')) {
        continue;
      }
      _requirePath(path, source: sourcePath);
    }
  }
}

List<String> _backtickedValues(String text) {
  return RegExp(r'`([^`]+)`')
      .allMatches(text)
      .map((match) => _matchGroup(match, 1, 'backticked value'))
      .toList();
}

String _matchGroup(Match match, int group, String context) {
  final value = match.group(group);
  if (value == null) {
    _fail('$context has no regex group $group');
    return '';
  }
  return value;
}

List<YamlMap> _loadYamlMapList(String path) {
  _requireFile(path);
  if (!File(path).existsSync()) {
    return const [];
  }

  final value = loadYaml(_read(path));
  if (value is! YamlList) {
    _fail('$path must contain a YAML list');
    return const [];
  }

  final items = <YamlMap>[];
  for (final item in value) {
    if (item is YamlMap) {
      items.add(item);
    } else {
      _fail('$path must contain only YAML map entries');
    }
  }
  return items;
}

String _stringField(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is String) {
    return value;
  }
  _fail('$owner must have string field $field');
  return '';
}

List<String> _stringListField(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is! YamlList) {
    _fail('$owner must have list field $field');
    return const [];
  }
  final items = <String>[];
  for (final item in value) {
    if (item is String) {
      items.add(item);
    } else {
      _fail('$owner field $field must contain only strings');
    }
  }
  return items;
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    _fail('required path references missing file $path');
    return '';
  }
  return file.readAsStringSync();
}

void _requirePath(String path, {String? source}) {
  final normalized = path.split('#').first.split(RegExp(r'\s')).first;
  if (normalized.endsWith('/')) {
    _requireDirectory(normalized, source: source);
  } else {
    _requireFile(normalized, source: source);
  }
}

void _requireFile(String path, {String? source}) {
  if (!File(path).existsSync()) {
    _fail('${source ?? 'required path'} references missing file $path');
  }
}

void _requireDirectory(String path, {String? source}) {
  if (!Directory(path).existsSync()) {
    _fail('${source ?? 'required path'} references missing directory $path');
  }
}

void _fail(String message) {
  _errors.add(message);
}
