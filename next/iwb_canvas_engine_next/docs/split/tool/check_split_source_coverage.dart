import 'dart:io';

import 'package:yaml/yaml.dart';

final _errors = <String>[];

void main() {
  _checkSectionCoverage();
  _checkDonorCoverage();
  _checkNoRetiredSourceReferences();

  if (_errors.isNotEmpty) {
    stderr.writeln('Split source coverage check failed:');
    for (final error in _errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Split source coverage check passed.');
}

void _checkSectionCoverage() {
  final sections = _loadYamlList('docs/split/_registry/sections.yaml');
  final expectedIds = {
    for (var index = 0; index <= 28; index++)
      'section_${index.toString().padLeft(2, '0')}',
  };
  final seenIds = <String>{};

  for (final item in sections) {
    if (item is! YamlMap) {
      _fail('sections registry entries must be maps');
      continue;
    }
    final id = _string(item, 'id', 'section entry');
    final file = _string(item, 'file', id);
    seenIds.add(_sectionPrefix(id));
    if (file.contains('docs/split/implementation')) {
      _fail('$id still points to retired implementation bucket');
    }
    _requireFile(file);
    final text = File(file).readAsStringSync();
    if (!text.contains('<!-- ORIGINAL-SECTION:BEGIN -->') ||
        !text.contains('<!-- ORIGINAL-SECTION:END -->')) {
      _fail('$file does not preserve an ORIGINAL-SECTION block');
    }
  }

  for (final expectedId in expectedIds) {
    if (!seenIds.contains(expectedId)) {
      _fail('missing split section coverage for $expectedId');
    }
  }
}

void _checkDonorCoverage() {
  _requireFile('docs/split/_registry/donors.yaml');
  final donorFiles =
      Directory('docs/split/donors')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (donorFiles.length < 9) {
    _fail('expected split donor documents are missing');
  }

  for (final file in donorFiles) {
    final text = file.readAsStringSync();
    if (!text.contains('<!-- ORIGINAL-SECTION:BEGIN -->') ||
        !text.contains('<!-- ORIGINAL-SECTION:END -->')) {
      _fail('${file.path} does not preserve an ORIGINAL-SECTION block');
    }
    if (!text.contains('docs/split/_registry/donors.yaml')) {
      _fail('${file.path} does not point to the donor registry');
    }
  }
}

void _checkNoRetiredSourceReferences() {
  final retired = [
    'iwb_canvas_engine_next_full_implementation_plan_v2',
    'iwb_canvas_engine_next_donor_inventory',
    'Canonical original:',
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
          _fail('${file.path} contains retired source reference: $token');
        }
      }
    }
  }
}

YamlList _loadYamlList(String path) {
  _requireFile(path);
  final value = loadYaml(File(path).readAsStringSync());
  if (value is YamlList) {
    return value;
  }
  _fail('$path must contain a YAML list');
  return loadYaml('[]') as YamlList;
}

String _string(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is String) {
    return value;
  }
  _fail('$owner must have string field $field');
  return '';
}

String _sectionPrefix(String id) {
  final match = RegExp(r'^(section_\d{2})_').firstMatch(id);
  return match?.group(1) ?? id;
}

void _requireFile(String path) {
  if (!File(path).existsSync()) {
    _fail('missing required file $path');
  }
}

void _fail(String message) {
  _errors.add(message);
}
