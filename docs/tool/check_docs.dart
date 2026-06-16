// Structural documentation checker only.
//
// This tool verifies documentation entrypoints, registries, navigation links,
// diagram catalog membership, and current lookup references. Do not add
// checks that match free-form Markdown wording, Mermaid edge text, or runtime
// architecture invariants. Those constraints belong in structured registries,
// generated documentation, analyzer/lint rules, or Dart tests.

import 'dart:io';

import 'package:yaml/yaml.dart';

const _sectionsRegistryPath = 'docs/_registry/sections.yaml';
const _diagramsRegistryPath = 'docs/_registry/diagrams.yaml';
const _diagramCatalogPath = 'docs/diagrams/catalog.md';
const _retiredDiagramReadmePath = 'docs/diagrams/README.md';
const _diagramCatalogMarker =
    '<!-- GENERATED: docs/tool/sync_generated_docs.dart from docs/_registry/diagrams.yaml -->';
const _generatedIndexMarker =
    '<!-- GENERATED: docs/tool/sync_generated_docs.dart from docs/_registry/sections.yaml -->';
const _markdownRoots = [
  'docs/architecture',
  'docs/contracts',
  'docs/verification',
  'docs/diagrams',
  'docs/indexes',
];

const _generatedIndexPaths = [
  'docs/indexes/by_owner.md',
  'docs/indexes/by_subsystem.md',
  'docs/indexes/by_guardrail.md',
  'docs/indexes/by_test_area.md',
  'docs/indexes/by_diagram.md',
  'docs/indexes/by_release.md',
];

const _retiredDocsRoutes = {
  'docs/indexes/by_phase.md',
  'docs/indexes/donor_to_phase.md',
  'docs/implementation',
  'docs/implementation/',
  'docs/donors',
  'docs/donors/',
};

const _rootReadmeGroups = [
  'Start by task',
  'Source of truth',
  'Checks',
  'Local entrypoints',
];

const _architectureReadmeGroups = [
  'Read path',
  'Work routes',
  'Boundary',
  'Checks',
];

const _rootReadmeTaskRoutes = [
  '- Understand architecture: `docs/architecture/README.md`',
  '- Plan a change: use a per-task Change Contract in the work item, Codex thread, or PR context',
  '- Verify behavior: `docs/verification/`',
  '- Find current owners: `docs/indexes/by_owner.md`',
  '- Check subsystem contracts: `docs/indexes/by_subsystem.md`',
  '- Find guardrail coverage: `docs/indexes/by_guardrail.md`',
  '- Find test coverage: `docs/indexes/by_test_area.md`',
  '- Find diagram coverage: `docs/indexes/by_diagram.md`',
  '- Update diagrams: `docs/diagrams/catalog.md`',
  '- Prepare release work: `docs/indexes/by_release.md` and `docs/verification/release_gates.md`',
  '- Use generated lookup: `docs/indexes/`',
];

const _activeRoutePolicyPaths = [
  'AGENTS.md',
  'docs/README.md',
  'docs/verification/release_gates.md',
];

const _retiredActiveRouteTokens = [
  'docs/indexes/by_phase.md',
  'docs/indexes/donor_to_phase.md',
  'docs/donors',
  'docs/donors/',
  'docs/implementation',
  'docs/implementation/',
  '--phase P14',
  '--phase=P14',
];

final _errors = <String>[];

void main() {
  _checkRequiredEntrypoints();
  _checkActiveRoutePolicyDocs();
  _checkPortalReadmes();
  _checkReadmeInventory();
  _checkGeneratedDocsParity();
  _checkGeneratedIndexes();

  final sections = _loadSections();
  final sectionIds = sections.map((section) => section.id).toSet();
  final diagrams = _loadDiagramCatalog();

  _checkSectionReferences(sections, sectionIds);
  _checkDiagramCatalogRegistrySymmetry(sections, sectionIds, diagrams);
  _checkMarkdownPaths(sectionIds);
  _checkMustReadGraph(sections, sectionIds);

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
    required this.owners,
    required this.subsystems,
    required this.mustRead,
    required this.diagrams,
    required this.guardrails,
    required this.tests,
    required this.doNotAssume,
  });

  final String id;
  final String file;
  final String title;
  final List<String> owners;
  final List<String> subsystems;
  final List<String> mustRead;
  final List<String> diagrams;
  final List<String> guardrails;
  final List<String> tests;
  final List<String> doNotAssume;
}

class _DiagramEntry {
  const _DiagramEntry({
    required this.id,
    required this.kind,
    required this.file,
    required this.classification,
    required this.relatedSections,
    required this.relatedOwners,
    required this.graphViewSource,
  });

  final String id;
  final String kind;
  final String file;
  final String classification;
  final Set<String> relatedSections;
  final Set<String> relatedOwners;
  final String graphViewSource;

  bool get isGenerated => classification == 'generated';
}

void _checkRequiredEntrypoints() {
  const requiredFiles = [
    'docs/README.md',
    'docs/architecture/README.md',
    _sectionsRegistryPath,
    _diagramsRegistryPath,
    _diagramCatalogPath,
  ];
  const requiredDirs = [
    'docs/architecture',
    'docs/contracts',
    'docs/verification',
    'docs/diagrams',
    'docs/indexes',
    'docs/_registry',
  ];

  for (final path in requiredFiles) {
    _requireFile(path);
  }
  for (final path in requiredDirs) {
    _requireDirectory(path);
  }
}

void _checkActiveRoutePolicyDocs() {
  for (final path in _activeRoutePolicyPaths) {
    if (!File(path).existsSync()) {
      _fail('$path is required for active route policy checks');
      continue;
    }
    final text = _read(path);
    for (final token in _retiredActiveRouteTokens) {
      if (text.contains(token)) {
        _fail('$path routes active work through retired token $token');
      }
    }
  }
}

// Registry loading validates one source-of-truth row atomically; splitting the
// field checks into metric-only helpers would make row-level failures harder to
// audit beside the loaded entry.
// ignore: halstead-volume
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
      owners: _stringListField(entry, 'owners', id),
      subsystems: _stringListField(entry, 'subsystems', id),
      mustRead: _stringListField(entry, 'must_read', id),
      diagrams: _stringListField(entry, 'diagrams', id),
      guardrails: _stringListField(entry, 'guardrails', id),
      tests: _stringListField(entry, 'tests', id),
      doNotAssume: _stringListField(entry, 'do_not_assume', id),
    );

    _rejectRetiredSectionFields(entry, id);

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

void _rejectRetiredSectionFields(YamlMap entry, String id) {
  for (final field in const ['phases', 'donors', 'benchmarks']) {
    if (entry.containsKey(field)) {
      _fail('$id must not use retired section field $field');
    }
  }
}

// Section registry integrity is one row-level invariant; keeping the traversal
// together makes row failures report from the same owner.
// ignore: cyclomatic-complexity, halstead-volume
void _checkSectionReferences(
  List<_SectionEntry> sections,
  Set<String> sectionIds,
) {
  for (final section in sections) {
    _checkNoneSentinel(section.id, 'must_read', section.mustRead);
    _checkNoneSentinel(section.id, 'owners', section.owners);
    _checkNoneSentinel(section.id, 'subsystems', section.subsystems);
    _checkNoneSentinel(section.id, 'diagrams', section.diagrams);
    _checkNoneSentinel(section.id, 'guardrails', section.guardrails);
    _checkNoneSentinel(section.id, 'tests', section.tests);
    _checkNoneSentinel(section.id, 'do_not_assume', section.doNotAssume);

    if (section.owners.isEmpty) {
      _fail('${section.id} has no owners');
    }
    _checkExplicitCoverage(section);
    for (final owner in section.owners) {
      if (RegExp(r'^P([0-9]|1[0-4])$').hasMatch(owner)) {
        _fail('${section.id} uses retired phase value $owner as owner');
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
  }
}

void _checkGeneratedIndexes() {
  final allowed = _generatedIndexPaths.toSet();
  final directory = Directory('docs/indexes');
  if (directory.existsSync()) {
    for (final file in directory.listSync().whereType<File>()) {
      if (!file.path.endsWith('.md')) {
        continue;
      }
      if (!allowed.contains(file.path)) {
        _fail('${file.path} is not a locked generated index');
      }
    }
  }

  for (final path in _generatedIndexPaths) {
    _requireFile(path);
    if (!File(path).existsSync()) {
      continue;
    }
    final text = _read(path);
    if (!text.startsWith(_generatedIndexMarker)) {
      _fail('$path must start with the generated index marker');
    }
  }
  if (File('docs/indexes/context_coverage.md').existsSync()) {
    _fail('docs/indexes/context_coverage.md must not remain as an entrypoint');
  }
}

void _checkReadmeInventory() {
  const allowed = {'docs/README.md', 'docs/architecture/README.md'};
  final docsDirectory = Directory('docs');
  if (!docsDirectory.existsSync()) {
    return;
  }

  for (final file
      in docsDirectory.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('/README.md')) {
      continue;
    }
    if (!allowed.contains(file.path)) {
      _fail('${file.path} is not an approved docs README');
    }
  }
}

void _checkGeneratedDocsParity() {
  final result = Process.runSync(Platform.resolvedExecutable, [
    'run',
    'docs/tool/sync_generated_docs.dart',
    '--check',
  ]);
  if (result.exitCode != 0) {
    _fail(
      'generated docs are stale; run '
      '`dart run docs/tool/sync_generated_docs.dart`',
    );
  }
}

void _checkPortalReadmes() {
  _checkReadmeShape(
    path: 'docs/README.md',
    expectedTitle: 'iwb_canvas_engine documentation',
    expectedGroups: _rootReadmeGroups,
  );
  _checkRootReadmeTaskRoutes();
  _checkReadmeShape(
    path: 'docs/architecture/README.md',
    expectedTitle: 'Architecture entrypoint',
    expectedGroups: _architectureReadmeGroups,
  );
}

void _checkRootReadmeTaskRoutes() {
  final text = _read('docs/README.md');
  for (final route in _rootReadmeTaskRoutes) {
    if (!text.contains(route)) {
      _fail('docs/README.md Start by task must contain route: $route');
    }
  }
}

// Portal README shape is intentionally checked as one document contract, so a
// failed heading/group/intro rule points to the same entrypoint owner.
// ignore: halstead-volume, source-lines-of-code
void _checkReadmeShape({
  required String path,
  required String expectedTitle,
  required List<String> expectedGroups,
}) {
  final text = _read(path);
  final titleMatches = RegExp(
    r'^#\s+(.+)$',
    multiLine: true,
  ).allMatches(text).toList();
  final titleMatch = titleMatches.isEmpty ? null : titleMatches.first;
  if (titleMatch == null || titleMatch.start != 0) {
    _fail('$path must start with one H1 title');
    return;
  }
  if (titleMatches.length != 1) {
    _fail('$path must contain exactly one H1 title');
  }
  final title = _matchGroup(titleMatch, 1, '$path title');
  if (title != expectedTitle) {
    _fail('$path title must be "$expectedTitle"');
  }

  final groups = RegExp(r'^##\s+(.+)$', multiLine: true)
      .allMatches(text)
      .map((match) => _matchGroup(match, 1, '$path group'))
      .toList();
  if (!_sameStringList(groups, expectedGroups)) {
    _fail('$path groups must be exactly ${expectedGroups.join(', ')}');
  }

  final firstGroup = RegExp(r'^##\s+', multiLine: true).firstMatch(text);
  if (firstGroup == null) {
    _fail('$path must contain portal groups');
  } else {
    _checkIntroParagraph(
      path,
      _codeUnitSlice(text, titleMatch.end, firstGroup.start),
    );
  }
  _checkReadmeNestedHeadings(path, text);

  for (final retiredPath in const [
    _retiredDiagramReadmePath,
    'docs/indexes/context_coverage.md',
  ]) {
    if (text.contains(retiredPath)) {
      _fail('$path links to retired path $retiredPath');
    }
  }
  _checkRetiredRoutes(path, text);
}

void _checkRetiredRoutes(String sourcePath, String text) {
  for (final retiredRoute in _retiredDocsRoutes) {
    if (text.contains(retiredRoute)) {
      _fail('$sourcePath links to retired route $retiredRoute');
    }
  }
  for (final match in RegExp(r'`([^`]+)`').allMatches(text)) {
    final route = _matchGroup(match, 1, '$sourcePath route');
    if (_retiredDocsRoutes.contains(route)) {
      _fail('$sourcePath links to retired route $route');
    }
  }
}

void _checkReadmeNestedHeadings(String path, String text) {
  for (final match in RegExp(
    r'^(#{3,6})\s+(.+)$',
    multiLine: true,
  ).allMatches(text)) {
    final heading = _matchGroup(match, 2, '$path nested heading');
    _fail('$path must not contain nested heading "$heading"');
  }

  for (final match in RegExp(
    r'^#+\s+(.+)$',
    multiLine: true,
  ).allMatches(text)) {
    final heading = _matchGroup(match, 1, '$path heading').toLowerCase();
    if (heading.contains('catalog') ||
        heading.contains('reverse lookup') ||
        heading.contains('manual')) {
      _fail('$path must not contain manual catalog or reverse-lookup headings');
    }
  }
}

void _checkIntroParagraph(String path, String intro) {
  final blocks = intro
      .trim()
      .split(RegExp(r'\n\s*\n'))
      .where((block) => block.trim().isNotEmpty)
      .toList();
  if (blocks.length != 1) {
    _fail('$path must have exactly one intro paragraph before portal groups');
    return;
  }

  final block = blocks.single;
  if (block.length > 280) {
    _fail('$path intro paragraph must stay short');
  }
  if (RegExp(r'^\s*(#|-|\d+\.|```)', multiLine: true).hasMatch(block)) {
    _fail(
      '$path intro must be a paragraph, not a list, heading, or code block',
    );
  }
}

void _checkExplicitCoverage(_SectionEntry section) {
  final coverage = {
    'owners': section.owners,
    'must_read': section.mustRead,
    'subsystems': section.subsystems,
    'diagrams': section.diagrams,
    'tests': section.tests,
    'guardrails': section.guardrails,
  };

  for (final entry in coverage.entries) {
    if (entry.value.isEmpty) {
      _fail('${section.id} has no explicit ${entry.key} coverage');
    }
  }
}

bool _sameStringList(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) {
    return false;
  }
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) {
      return false;
    }
  }
  return true;
}

// Diagram catalog loading validates identity, file, owner, and generated-source
// metadata in one pass so catalog rows cannot be partially accepted.
// ignore: cyclomatic-complexity, halstead-volume, maintainability-index, source-lines-of-code
Map<String, _DiagramEntry> _loadDiagramCatalog() {
  final catalog = <String, _DiagramEntry>{};
  final seenPaths = <String>{};

  if (File(_retiredDiagramReadmePath).existsSync()) {
    _fail('$_retiredDiagramReadmePath must not remain as an entrypoint');
  }
  final catalogText = _read(_diagramCatalogPath);
  if (!catalogText.startsWith(_diagramCatalogMarker)) {
    _fail('$_diagramCatalogPath must start with the generated catalog marker');
  }

  for (final entry in _loadYamlMapList(_diagramsRegistryPath)) {
    final diagramId = _stringField(entry, 'id', 'diagram registry entry');
    final kind = _stringField(entry, 'kind', diagramId);
    final file = _stringField(entry, 'file', diagramId);
    final classification = _stringField(entry, 'classification', diagramId);
    final owners = _stringListField(entry, 'related_owners', diagramId).toSet();
    final sections = _stringListField(
      entry,
      'related_sections',
      diagramId,
    ).toSet();
    final graphViewSource = _stringField(entry, 'graph_view_source', diagramId);
    if (diagramId.isEmpty) {
      _fail('$_diagramsRegistryPath contains a diagram entry with empty id');
      continue;
    }
    if (catalog.containsKey(diagramId)) {
      _fail('$_diagramsRegistryPath contains duplicate diagram id $diagramId');
      continue;
    }
    if (!seenPaths.add(file)) {
      _fail('$_diagramsRegistryPath contains duplicate path $file');
    }
    if (!file.startsWith('docs/diagrams/') || !file.endsWith('.mmd')) {
      _fail('$diagramId file must be a docs/diagrams/*.mmd path');
    }
    _requireFile(file, source: _diagramsRegistryPath);

    if (sections.isEmpty) {
      _fail('$_diagramsRegistryPath entry $diagramId has no related sections');
    }
    if (owners.isEmpty) {
      _fail('$_diagramsRegistryPath entry $diagramId has no related owners');
    }
    for (final owner in owners) {
      if (RegExp(r'^P([0-9]|1[0-4])$').hasMatch(owner)) {
        _fail(
          '$_diagramsRegistryPath entry $diagramId uses retired phase value $owner',
        );
      }
    }
    if (entry.containsKey('related_phases')) {
      _fail('$_diagramsRegistryPath entry $diagramId uses related_phases');
    }
    if (classification != 'semantic' && classification != 'generated') {
      _fail('$diagramId classification must be semantic or generated');
    }
    if (classification == 'generated' &&
        graphViewSource != 'docs/architecture/architecture_graph.yaml') {
      _fail(
        '$diagramId generated diagram must name graph-view source metadata',
      );
    }
    if (classification == 'semantic' && graphViewSource != 'none') {
      _fail('$diagramId semantic diagram must use graph_view_source: none');
    }
    catalog[diagramId] = _DiagramEntry(
      id: diagramId,
      kind: kind,
      file: file,
      classification: classification,
      relatedSections: sections,
      relatedOwners: owners,
      graphViewSource: graphViewSource,
    );
  }

  return catalog;
}

// Diagram registry/catalog symmetry must report both missing catalog entries and
// stale Mermaid files from the same consistency check.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
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

  final catalogedFiles = catalog.values.map((diagram) => diagram.file).toSet();
  final diagramDir = Directory('docs/diagrams');
  if (!diagramDir.existsSync()) {
    return;
  }
  for (final file in diagramDir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.mmd')) {
      continue;
    }
    if (!catalogedFiles.contains(file.path)) {
      _fail('${file.path} exists but is not cataloged in $_diagramCatalogPath');
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
      _checkRetiredSourceClaims(file.path, text);
    }
  }

  final readme = 'docs/README.md';
  final text = _read(readme);
  _checkSectionIdsInText(readme, text, sectionIds);
  _checkDocumentPathsInText(readme, text);
  _checkRetiredSourceClaims(readme, text);
}

void _checkRetiredSourceClaims(String sourcePath, String text) {
  if (sourcePath == 'docs/diagrams/catalog.md' ||
      _generatedIndexPaths.contains(sourcePath)) {
    return;
  }
  if (text.contains('Feeds indexes')) {
    _fail('$sourcePath contains retired "Feeds indexes" source claim');
  }
  if (text.contains(_retiredDiagramReadmePath)) {
    _fail('$sourcePath links to retired diagram README');
  }
  if (text.contains('docs/indexes/context_coverage.md')) {
    _fail('$sourcePath links to retired context coverage index');
  }
  _checkRetiredRoutes(sourcePath, text);
}

// The must-read graph cycle check keeps graph construction and DFS together so
// reported cycles include the same source graph that was validated.
// ignore: cyclomatic-complexity, halstead-volume
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

String _codeUnitSlice(String text, int start, [int? end]) {
  // RegExp match indexes are String code-unit offsets; substring is the exact
  // operation for slicing around those structural markers.
  // ignore: avoid-substring
  return text.substring(start, end);
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
    if (value.isEmpty) {
      _fail('$owner must have non-empty string field $field');
    }
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
  final seen = <String>{};
  for (final item in value) {
    if (item is String) {
      if (item.isEmpty) {
        _fail('$owner field $field contains an empty value');
        continue;
      }
      if (!seen.add(item)) {
        _fail('$owner field $field contains duplicate value $item');
      }
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
