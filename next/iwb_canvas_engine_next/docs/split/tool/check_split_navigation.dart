import 'dart:io';

import 'package:yaml/yaml.dart';

final _errors = <String>[];
final _sectionIds = <String>{};
final _ownerIds = <String>{};

void main() {
  _checkRequiredEntrypoints();
  _checkSectionsRegistry();
  _checkDiagramsRegistry();
  _checkArchitectureManifest();
  _checkMarkdownIndexes();
  _checkNoRetiredActiveReferences();

  if (_errors.isNotEmpty) {
    stderr.writeln('Split navigation check failed:');
    for (final error in _errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Split navigation check passed.');
}

void _checkRequiredEntrypoints() {
  const requiredFiles = [
    'docs/split/README.md',
    'docs/split/architecture/README.md',
    'docs/split/architecture/architecture.yaml',
    'docs/split/_registry/sections.yaml',
    'docs/split/_registry/diagrams.yaml',
    'docs/split/_registry/donors.yaml',
  ];
  const requiredDirs = [
    'docs/split/architecture',
    'docs/split/contracts',
    'docs/split/verification',
    'docs/split/planning',
    '../../plan',
    'docs/split/donors',
  ];

  for (final path in requiredFiles) {
    _requireFile(path);
  }
  for (final path in requiredDirs) {
    _requireDirectory(path);
  }

  final architectureReadme = _read('docs/split/architecture/README.md');
  const requiredRoutes = [
    'docs/split/architecture/architecture.yaml',
    'docs/split/contracts/public_api_v1.md',
    'docs/split/contracts/frame_rendering.md',
    'docs/split/contracts/cache_policy.md',
    'docs/split/verification/tests.md',
    'docs/split/planning/',
    '../../plan/',
    'docs/split/donors/',
  ];
  for (final route in requiredRoutes) {
    if (!architectureReadme.contains(route)) {
      _fail('architecture README does not route to $route');
    }
  }
}

void _checkSectionsRegistry() {
  final sections = _loadYamlMapList('docs/split/_registry/sections.yaml');
  for (final section in sections) {
    final id = _stringField(section, 'id', 'section registry entry');
    final file = _stringField(section, 'file', id);
    _sectionIds.add(id);
    if (file.contains('docs/split/implementation')) {
      _fail('$id still points to retired implementation bucket');
    }
    _requireFile(file);
  }

  for (final section in sections) {
    final id = _stringField(section, 'id', 'section registry entry');
    _checkReferenceList(section, 'must_read', id);
  }
}

void _checkDiagramsRegistry() {
  final diagrams = _loadYamlMapList('docs/split/_registry/diagrams.yaml');
  for (final diagram in diagrams) {
    final id = _stringField(diagram, 'id', 'diagram registry entry');
    _checkReferenceList(diagram, 'related_sections', id);
  }
}

void _checkArchitectureManifest() {
  final manifest = _loadYamlMap('docs/split/architecture/architecture.yaml');
  final owners = _listField(
    manifest,
    'runtime_owners',
    'architecture manifest',
  );
  final actors = _listField(
    manifest,
    'external_actors',
    'architecture manifest',
  );

  for (final item in [...owners, ...actors]) {
    final id = _stringField(item, 'id', 'architecture owner');
    if (!_ownerIds.add(id)) {
      _fail('duplicate architecture owner id: $id');
    }
  }

  final dependencies = _listField(
    manifest,
    'allowed_dependencies',
    'architecture manifest',
  );
  for (final dependency in dependencies) {
    _checkOwnerDependency(dependency, 'allowed dependency');
  }

  final forbidden = _listField(
    manifest,
    'forbidden_dependencies',
    'architecture manifest',
  );
  for (final dependency in forbidden) {
    _checkOwnerDependency(dependency, 'forbidden dependency');
  }

  final targets = _listField(
    manifest,
    'diagram_targets',
    'architecture manifest',
  );
  const expectedTargets = {
    'c4_context': 'docs/split/diagrams/generated/c4_context.mmd',
    'c4_container': 'docs/split/diagrams/generated/c4_container.mmd',
    'c4_component_runtime':
        'docs/split/diagrams/generated/c4_component_runtime.mmd',
  };
  final seen = <String, String>{};
  for (final target in targets) {
    seen[_stringField(target, 'id', 'diagram target')] = _stringField(
      target,
      'planned_path',
      'diagram target',
    );
  }
  for (final entry in expectedTargets.entries) {
    if (seen[entry.key] != entry.value) {
      _fail(
        'architecture manifest target ${entry.key} must point to '
        '${entry.value}',
      );
    }
  }
}

void _checkMarkdownIndexes() {
  final indexDir = Directory('docs/split/indexes');
  if (!indexDir.existsSync()) {
    _fail('docs/split/indexes is missing');
    return;
  }

  for (final entity in indexDir.listSync().whereType<File>()) {
    if (!entity.path.endsWith('.md')) {
      continue;
    }
    final text = entity.readAsStringSync();
    for (final match in RegExp(r'`(section_[^`]+)`').allMatches(text)) {
      final id = match.group(1);
      if (id == null) {
        _fail('${entity.path} contains a malformed section reference');
        continue;
      }
      if (!_sectionIds.contains(id)) {
        _fail('${entity.path} references unknown section id $id');
      }
    }
    _checkDocumentPathsInText(entity.path, text);
  }
}

void _checkNoRetiredActiveReferences() {
  final retired = [
    'canonical truth remains',
    'docs/split/implementation',
    'iwb_canvas_engine_next_full_implementation_plan_v2',
    'iwb_canvas_engine_next_donor_inventory',
  ];
  final activeRoots = [
    Directory('docs/split/architecture'),
    Directory('docs/split/contracts'),
    Directory('docs/split/verification'),
    Directory('docs/split/planning'),
    Directory('docs/split/donors'),
    Directory('docs/split/indexes'),
    Directory('docs/split/_registry'),
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
      _checkDocumentPathsInText(file.path, text);
    }
  }
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
    } else if (reference.startsWith('docs/split/')) {
      _requirePath(reference);
    }
  }
}

void _checkOwnerDependency(YamlMap dependency, String owner) {
  final from = _stringField(dependency, 'from', owner);
  final to = _stringField(dependency, 'to', owner);
  if (!_ownerIds.contains(from) && !from.contains('/')) {
    _fail('$owner uses unknown from owner $from');
  }
  if (!_ownerIds.contains(to) && !to.contains('/')) {
    _fail('$owner uses unknown to owner $to');
  }
}

void _checkDocumentPathsInText(String sourcePath, String text) {
  final patterns = [
    RegExp(r'`(docs/split/[^`]+)`'),
    RegExp(r'\]\((docs/split/[^)]+)\)'),
  ];
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

YamlMap _loadYamlMap(String path) {
  _requireFile(path);
  final value = loadYaml(_read(path));
  if (value is YamlMap) {
    return value;
  }
  _fail('$path must contain a YAML map');
  return loadYaml('{}') as YamlMap;
}

List<YamlMap> _listField(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is! YamlList) {
    _fail('$owner must have list field $field');
    return const [];
  }
  return [
    for (final item in value)
      if (item is YamlMap) item else _invalidYamlMap(field),
  ];
}

YamlMap _invalidYamlMap(String field) {
  _fail('$field must use map entries');
  return loadYaml('{}') as YamlMap;
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
  if (normalized.startsWith('docs/split/diagrams/generated/') &&
      normalized.endsWith('.mmd')) {
    return;
  }
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
