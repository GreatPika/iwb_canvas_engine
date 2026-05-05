import 'dart:io';

import 'package:yaml/yaml.dart';

final _errors = <String>[];
final _sectionIds = <String>{};

void main() {
  _checkRequiredEntrypoints();
  _checkSectionsRegistry();
  _checkDiagramCatalogRegistrySymmetry();
  _checkMarkdownPaths();
  _checkNoRetiredActiveReferences();
  _checkDiagramContractAlignment();

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

void _checkRequiredEntrypoints() {
  const requiredFiles = [
    'docs/README.md',
    'docs/architecture/README.md',
    'docs/_registry/sections.yaml',
  ];
  const requiredDirs = [
    'docs/architecture',
    'docs/contracts',
    'docs/implementation',
    'docs/verification',
    'docs/donors',
    'docs/indexes',
    '../../plan',
  ];

  for (final path in requiredFiles) {
    _requireFile(path);
  }
  for (final path in requiredDirs) {
    _requireDirectory(path);
  }
}

void _checkSectionsRegistry() {
  final sections = _loadYamlMapList('docs/_registry/sections.yaml');
  for (final section in sections) {
    final id = _stringField(section, 'id', 'section registry entry');
    final file = _stringField(section, 'file', id);
    if (!_sectionIds.add(id)) {
      _fail('duplicate section id: $id');
    }
    _requireFile(file);
  }

  for (final section in sections) {
    final id = _stringField(section, 'id', 'section registry entry');
    _checkReferenceList(section, 'must_read', id);
  }
}

void _checkDiagramCatalogRegistrySymmetry() {
  final sections = _loadYamlMapList('docs/_registry/sections.yaml');
  final catalog = _loadDiagramCatalog('docs/diagrams/README.md');
  final registry = <String, Set<String>>{};

  for (final section in sections) {
    final sectionId = _stringField(section, 'id', 'section registry entry');
    final diagrams = section['diagrams'];
    if (diagrams == null || diagrams is! YamlList) {
      _fail('$sectionId has no list field diagrams');
      continue;
    }
    for (final item in diagrams) {
      final diagramId = item.toString();
      if (diagramId == 'none') {
        continue;
      }
      registry.putIfAbsent(diagramId, () => <String>{}).add(sectionId);
      if (!catalog.containsKey(diagramId)) {
        _fail(
          '$sectionId references diagram $diagramId, '
          'but docs/diagrams/README.md does not catalog it',
        );
      }
    }
  }

  for (final entry in catalog.entries) {
    final diagramId = entry.key;
    final catalogSections = entry.value;
    if (catalogSections.isEmpty) {
      _fail('docs/diagrams/README.md catalog entry $diagramId has no sections');
    }
    final registrySections = registry[diagramId] ?? const <String>{};

    for (final sectionId in catalogSections) {
      if (!_sectionIds.contains(sectionId)) {
        _fail(
          'docs/diagrams/README.md references unknown section id $sectionId',
        );
        continue;
      }
      if (!registrySections.contains(sectionId)) {
        _fail(
          'diagram $diagramId is related to $sectionId in '
          'docs/diagrams/README.md, but $sectionId does not list $diagramId '
          'in docs/_registry/sections.yaml',
        );
      }
    }

    for (final sectionId in registrySections) {
      if (!catalogSections.contains(sectionId)) {
        _fail(
          '$sectionId lists diagram $diagramId in docs/_registry/sections.yaml, '
          'but docs/diagrams/README.md does not list $sectionId under '
          '$diagramId',
        );
      }
    }
  }

  final catalogedFiles = catalog.keys
      .map((diagramId) => 'docs/diagrams/$diagramId.mmd')
      .toSet();
  final diagramDir = Directory('docs/diagrams');
  if (diagramDir.existsSync()) {
    for (final file in diagramDir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.mmd')) {
        continue;
      }
      if (!catalogedFiles.contains(file.path)) {
        _fail(
          '${file.path} exists but is not cataloged in docs/diagrams/README.md',
        );
      }
    }
  }
}

void _checkMarkdownPaths() {
  final roots = [
    Directory('docs/architecture'),
    Directory('docs/contracts'),
    Directory('docs/implementation'),
    Directory('docs/verification'),
    Directory('docs/donors'),
    Directory('docs/indexes'),
    Directory('docs/_registry'),
  ];

  for (final root in roots) {
    if (!root.existsSync()) {
      continue;
    }
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.md')) {
        continue;
      }
      final text = file.readAsStringSync();
      _checkSectionIdsInText(file.path, text);
      _checkDocumentPathsInText(file.path, text);
    }
  }

  for (final path in ['docs/README.md']) {
    final text = _read(path);
    _checkSectionIdsInText(path, text);
    _checkDocumentPathsInText(path, text);
  }
}

Map<String, Set<String>> _loadDiagramCatalog(String path) {
  _requireFile(path);
  final text = _read(path);
  final catalog = <String, Set<String>>{};
  final blocks = text.split(RegExp(r'^##\s+', multiLine: true));

  for (final block in blocks.skip(1)) {
    final lines = block.split('\n');
    if (lines.isEmpty) {
      continue;
    }
    final diagramId = lines.first.trim();
    if (diagramId.isEmpty) {
      _fail('$path contains an empty diagram heading');
      continue;
    }
    if (catalog.containsKey(diagramId)) {
      _fail('$path contains duplicate diagram entry $diagramId');
      continue;
    }

    String? plannedPath;
    final sections = <String>{};
    for (final line in lines.skip(1)) {
      final plannedPathMatch = RegExp(
        r'^- Planned path: `(docs/diagrams/[^`]+\.mmd)`$',
      ).firstMatch(line);
      if (plannedPathMatch != null) {
        plannedPath = plannedPathMatch.group(1);
        continue;
      }
      final sectionsMatch = RegExp(
        r'^- Related sections: (.+)$',
      ).firstMatch(line);
      if (sectionsMatch != null) {
        for (final match in RegExp(
          r'`(section_[^`]+)`',
        ).allMatches(sectionsMatch.group(1)!)) {
          sections.add(match.group(1)!);
        }
      }
    }

    final expectedPath = 'docs/diagrams/$diagramId.mmd';
    if (plannedPath == null) {
      _fail('$path catalog entry $diagramId has no planned path');
    } else if (plannedPath != expectedPath) {
      _fail(
        '$path catalog entry $diagramId planned path must be $expectedPath, '
        'not $plannedPath',
      );
    }
    _requireFile(expectedPath, source: path);

    catalog[diagramId] = sections;
  }

  return catalog;
}

void _checkNoRetiredActiveReferences() {
  final retired = [
    'canonical truth remains',
    'iwb_canvas_engine_next_full_implementation_plan_v2',
    'iwb_canvas_engine_next_donor_inventory',
  ];
  final activeRoots = [
    Directory('docs/architecture'),
    Directory('docs/contracts'),
    Directory('docs/implementation'),
    Directory('docs/verification'),
    Directory('docs/donors'),
    Directory('docs/indexes'),
    Directory('docs/_registry'),
  ];

  for (final root in activeRoots) {
    if (!root.existsSync()) {
      continue;
    }
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      final text = file.readAsStringSync();
      for (final token in retired) {
        if (text.contains(token)) {
          _fail('${file.path} contains retired reference: $token');
        }
      }
    }
  }
}

void _checkDiagramContractAlignment() {
  final files = <File>[];
  final diagramDir = Directory('docs/diagrams');
  if (diagramDir.existsSync()) {
    files.addAll(
      diagramDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.mmd')),
    );
  }

  for (final root in [
    Directory('docs/architecture'),
    Directory('docs/contracts'),
    Directory('docs/implementation'),
    Directory('docs/verification'),
    Directory('docs/donors'),
    Directory('docs/indexes'),
  ]) {
    if (!root.existsSync()) {
      continue;
    }
    files.addAll(
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.md')),
    );
  }

  final forbiddenText = <String, RegExp>{
    'use controllerEpoch, not a separate tool epoch': RegExp(
      r'\btool epoch\b',
      caseSensitive: false,
    ),
    'use controllerEpoch, not controller/tool epoch': RegExp(
      r'\bcontroller/tool epoch\b',
      caseSensitive: false,
    ),
    'use explicit controllerEpoch mismatch, not mode/tool epoch mismatch':
        RegExp(r'\bmode/tool epoch mismatch\b', caseSensitive: false),
    'use controllerEpoch wording, not same-epoch': RegExp(
      r'\bsame-epoch\b',
      caseSensitive: false,
    ),
    'use controllerEpoch wording, not same epoch': RegExp(
      r'\bsame epoch\b',
      caseSensitive: false,
    ),
    'use controllerEpoch mismatch, not wrong epoch': RegExp(
      r'\bwrong epoch\b',
      caseSensitive: false,
    ),
    'use controllerEpoch mismatch, not stale epoch': RegExp(
      r'\bstale epoch\b',
      caseSensitive: false,
    ),
    'eraser candidates are deletable non-background, not visible deletable':
        RegExp(r'\bvisible deletable\b', caseSensitive: false),
    'ResourceKernel owns dirty ids/cache entries, not listener/cache references':
        RegExp(r'\blistener/cache references\b', caseSensitive: false),
    'resource disposal clears caches and dirty state, not listeners': RegExp(
      r'\bresource caches and listeners\b',
      caseSensitive: false,
    ),
    'disposed resources must not reopen listeners': RegExp(
      r'\breopen listeners\b',
      caseSensitive: false,
    ),
  };

  for (final file in files) {
    final text = file.readAsStringSync();
    for (final entry in forbiddenText.entries) {
      for (final match in entry.value.allMatches(text)) {
        _fail('${file.path}:${_lineNumber(text, match.start)} ${entry.key}');
      }
    }

    if (file.path.endsWith('.mmd')) {
      _checkStoreDoesNotDispatchRuntimeEffects(file.path, text);
      _checkInteractionDoesNotBypassEditKernel(file.path, text);
    }
  }
}

void _checkStoreDoesNotDispatchRuntimeEffects(String path, String text) {
  final pattern = RegExp(
    r'^\s*Store->>(Frame|Spatial|Events|Resources|Interaction|Signals)\s*:',
    multiLine: true,
  );
  for (final match in pattern.allMatches(text)) {
    final target = match.group(1);
    _fail(
      '$path:${_lineNumber(text, match.start)} '
      'DocumentStoreKernel must not dispatch post-commit effects to $target; '
      'route them through RuntimeRoot or CommitApplier',
    );
  }
}

void _checkInteractionDoesNotBypassEditKernel(String path, String text) {
  final pattern = RegExp(
    r'^\s*(IE|Interaction)->>(Store|Draft|Events)\s*:',
    multiLine: true,
  );
  for (final match in pattern.allMatches(text)) {
    final target = match.group(2);
    _fail(
      '$path:${_lineNumber(text, match.start)} '
      'InteractionEngine must not commit by calling $target directly; '
      'route committed mutations and staged actions through EditKernel',
    );
  }
}

int _lineNumber(String text, int offset) {
  var line = 1;
  for (var i = 0; i < offset; i += 1) {
    if (text.codeUnitAt(i) == 10) {
      line += 1;
    }
  }
  return line;
}

void _checkReferenceList(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value == null || value is! YamlList) {
    _fail('$owner has no list field $field');
    return;
  }
  for (final item in value) {
    final reference = item.toString();
    if (reference == 'none') {
      continue;
    }
    if (reference.startsWith('section_')) {
      if (!_sectionIds.contains(reference)) {
        _fail('$owner references unknown section id $reference');
      }
    } else if (reference.startsWith('docs/')) {
      _requirePath(reference);
    }
  }
}

void _checkSectionIdsInText(String sourcePath, String text) {
  for (final match in RegExp(r'`(section_[^`]+)`').allMatches(text)) {
    final id = match.group(1);
    if (id == null) {
      _fail('$sourcePath contains a malformed section reference');
      continue;
    }
    if (!_sectionIds.contains(id)) {
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

List<YamlMap> _loadYamlMapList(String path) {
  _requireFile(path);
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

String _read(String path) => File(path).readAsStringSync();

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
