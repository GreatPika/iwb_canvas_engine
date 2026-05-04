import 'dart:io';

import 'package:yaml/yaml.dart';

final _errors = <String>[];
final _sectionIds = <String>{};

void main() {
  _checkRequiredEntrypoints();
  _checkSectionsRegistry();
  _checkMarkdownPaths();
  _checkNoRetiredActiveReferences();

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
    'docs/verification',
    'docs/planning',
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
    if (file.contains('docs/implementation')) {
      _fail('$id still points to retired implementation bucket');
    }
    _requireFile(file);
  }

  for (final section in sections) {
    final id = _stringField(section, 'id', 'section registry entry');
    _checkReferenceList(section, 'must_read', id);
  }
}

void _checkMarkdownPaths() {
  final roots = [
    Directory('docs/architecture'),
    Directory('docs/contracts'),
    Directory('docs/verification'),
    Directory('docs/planning'),
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

void _checkNoRetiredActiveReferences() {
  final retired = [
    'canonical truth remains',
    'docs/implementation',
    'iwb_canvas_engine_next_full_implementation_plan_v2',
    'iwb_canvas_engine_next_donor_inventory',
  ];
  final activeRoots = [
    Directory('docs/architecture'),
    Directory('docs/contracts'),
    Directory('docs/verification'),
    Directory('docs/planning'),
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
