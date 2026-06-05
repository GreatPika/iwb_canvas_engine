import 'dart:io';

import 'package:yaml/yaml.dart';

const _sectionsRegistryPath = 'docs/_registry/sections.yaml';

final _contextPattern = RegExp(
  r'<!-- CONTEXT:BEGIN -->[\s\S]*?<!-- CONTEXT:END -->(?:\r?\n)*',
);

void main(List<String> args) {
  final checkOnly = args.contains('--check');
  final result = _syncContextCapsules(checkOnly: checkOnly);

  if (result.errors.isNotEmpty) {
    stderr.writeln(
      checkOnly
          ? 'Context capsule check failed:'
          : 'Context capsule generation failed:',
    );
    for (final error in result.errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  if (checkOnly) {
    stdout.writeln('Context capsule check passed.');
    return;
  }

  if (result.changedFiles.isEmpty) {
    stdout.writeln('Context capsules already up to date.');
    return;
  }

  stdout.writeln('Context capsules generated:');
  for (final file in result.changedFiles) {
    stdout.writeln('- $file');
  }
}

class _ContextCapsuleSyncResult {
  const _ContextCapsuleSyncResult({
    required this.errors,
    required this.changedFiles,
  });

  final List<String> errors;
  final List<String> changedFiles;
}

_ContextCapsuleSyncResult _syncContextCapsules({required bool checkOnly}) {
  final errors = <String>[];
  final changedFiles = <String>[];
  final sections = _loadSections(errors);
  final sectionsById = <String, _SectionEntry>{};

  for (final section in sections) {
    if (sectionsById.containsKey(section.id)) {
      errors.add('duplicate section id ${section.id}');
      continue;
    }
    sectionsById[section.id] = section;
  }

  if (errors.isNotEmpty) {
    return _ContextCapsuleSyncResult(
      errors: errors,
      changedFiles: changedFiles,
    );
  }

  for (final section in sections) {
    final expected = _renderSectionContext(section, sectionsById, errors);
    _syncSectionFile(
      section,
      expected,
      checkOnly: checkOnly,
      errors: errors,
      changedFiles: changedFiles,
    );
  }

  return _ContextCapsuleSyncResult(errors: errors, changedFiles: changedFiles);
}

// Context capsules mirror one registry row, so row decoding stays together to
// keep generated context and validation errors tied to the same source entry.
// ignore: halstead-volume
List<_SectionEntry> _loadSections(List<String> errors) {
  final value = _loadYamlList(_sectionsRegistryPath, errors);
  final sections = <_SectionEntry>[];
  for (final item in value) {
    if (item is! YamlMap) {
      errors.add('$_sectionsRegistryPath must contain only YAML map entries');
      continue;
    }
    final id = _stringField(item, 'id', 'section entry', errors);
    final file = _stringField(item, 'file', id, errors);
    final title = _stringField(item, 'title', id, errors);
    if (id.isEmpty || file.isEmpty || title.isEmpty) {
      continue;
    }
    sections.add(
      _SectionEntry(
        id: id,
        file: file,
        title: title,
        phases: _stringListField(item, 'phases', id, errors),
        mustRead: _stringListField(item, 'must_read', id, errors),
        donors: _stringListField(item, 'donors', id, errors),
        diagrams: _stringListField(item, 'diagrams', id, errors),
        guardrails: _stringListField(item, 'guardrails', id, errors),
        tests: _stringListField(item, 'tests', id, errors),
        doNotAssume: _stringListField(item, 'do_not_assume', id, errors),
      ),
    );
  }
  return sections;
}

String _renderSectionContext(
  _SectionEntry section,
  Map<String, _SectionEntry> sectionsById,
  List<String> errors,
) {
  final buffer = StringBuffer()
    ..writeln('<!-- CONTEXT:BEGIN -->')
    ..writeln('Registry id: `${section.id}`')
    ..writeln('Registry source: `$_sectionsRegistryPath`')
    ..writeln('Document path: `${section.file}`')
    ..writeln('Owns:');
  _writeLiteralList(buffer, [section.title]);
  buffer.writeln('Must read before editing:');
  _writeReferenceList(buffer, section.mustRead, sectionsById, errors);
  buffer.writeln('Feeds phases:');
  _writeCodeList(buffer, section.phases);
  buffer.writeln('Related donors:');
  _writeCodeList(buffer, section.donors);
  buffer.writeln('Related diagrams:');
  _writeCodeList(buffer, section.diagrams);
  buffer.writeln('Required tests:');
  _writeCodeList(buffer, section.tests);
  buffer.writeln('Guardrails:');
  _writeCodeList(buffer, section.guardrails);
  buffer.writeln('Do not assume:');
  _writeLiteralList(buffer, section.doNotAssume);
  buffer
    ..writeln('<!-- CONTEXT:END -->')
    ..writeln();

  return buffer.toString();
}

// Syncing one capsule needs the target section, rendered text, mode, errors,
// and changed-file accumulator together to keep check/apply behavior identical.
// ignore: halstead-volume, number-of-parameters
void _syncSectionFile(
  _SectionEntry section,
  String expected, {
  required bool checkOnly,
  required List<String> errors,
  required List<String> changedFiles,
}) {
  final file = File(section.file);
  if (!file.existsSync()) {
    errors.add('${section.id} references missing file ${section.file}');
    return;
  }

  final text = file.readAsStringSync();
  final matches = _contextPattern.allMatches(text).toList();
  if (matches.isEmpty) {
    errors.add('${section.file} is missing a CONTEXT capsule');
    return;
  }
  if (matches.length > 1) {
    errors.add('${section.file} contains more than one CONTEXT capsule');
    return;
  }

  final match = matches.first;
  if (match.start != 0) {
    errors.add('${section.file} CONTEXT capsule must be the first block');
    return;
  }

  final actual = _codeUnitSlice(text, match.start, match.end);
  if (actual == expected) {
    return;
  }

  if (checkOnly) {
    errors.add(
      '${section.file} CONTEXT capsule is not generated from registry',
    );
    return;
  }

  file.writeAsStringSync(text.replaceRange(match.start, match.end, expected));
  changedFiles.add(section.file);
}

String _codeUnitSlice(String text, int start, int end) {
  // RegExp match indexes are String code-unit offsets; substring preserves the
  // exact source block selected by the parser.
  // ignore: avoid-substring
  return text.substring(start, end);
}

void _writeLiteralList(StringBuffer buffer, List<String> values) {
  for (final value in values) {
    buffer.writeln('- $value');
  }
}

void _writeCodeList(StringBuffer buffer, List<String> values) {
  for (final value in values) {
    buffer.writeln('- `$value`');
  }
}

void _writeReferenceList(
  StringBuffer buffer,
  List<String> values,
  Map<String, _SectionEntry> sectionsById,
  List<String> errors,
) {
  for (final value in values) {
    final section = sectionsById[value];
    if (section != null) {
      buffer.writeln('- `$value` -> `${section.file}`');
      continue;
    }
    if (value.startsWith('section_')) {
      errors.add('unknown section reference $value');
    }
    buffer.writeln('- `$value`');
  }
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

  final items = <String>[];
  for (final item in value) {
    if (item is String) {
      items.add(item);
    } else {
      errors.add('$owner field $field must contain only strings');
    }
  }
  return items;
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
