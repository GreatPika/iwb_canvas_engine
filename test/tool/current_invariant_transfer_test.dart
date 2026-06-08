@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/guardrails/src/guardrail_registry.dart';

void main() {
  group('current invariant transfer', () {
    test('design transfer rows resolve to current proof owners', () {
      expect(_designTransferRowsWithoutCurrentProof(), isEmpty);
    });
  });
}

Map<String, String> _designTransferRowsWithoutCurrentProof() {
  final sectionsByFile = _loadSectionsByFile();
  final failures = <String, String>{};

  for (final row in _designTransferRows()) {
    final unprovenOwners = _unprovenOwnerTokens(row, sectionsByFile);
    if (unprovenOwners.isNotEmpty) {
      failures[row.label] = unprovenOwners.join(', ');
    }
  }

  return failures;
}

List<String> _unprovenOwnerTokens(
  _DesignTransferRow row,
  Map<String, _SectionOwner> sectionsByFile,
) {
  if (row.currentOwnerCell.startsWith('No current owner')) {
    return const [];
  }

  return [
    for (final ownerToken in _backtickValues(row.currentOwnerCell))
      if (!_ownerTokenHasCurrentProof(ownerToken, sectionsByFile)) ownerToken,
  ];
}

bool _ownerTokenHasCurrentProof(
  String ownerToken,
  Map<String, _SectionOwner> sectionsByFile,
) {
  if (_ownerProofAlias(ownerToken, sectionsByFile)) {
    return true;
  }
  final section = sectionsByFile[ownerToken];
  if (section != null) {
    return !_isRetiredProofSource(section.file) &&
        _sectionHasExecutableProof(section);
  }
  if (_isGlobOwnerToken(ownerToken)) {
    return _globOwnerExists(ownerToken) &&
        _globOwnerHasExecutableProof(ownerToken);
  }
  return false;
}

bool _ownerProofAlias(
  String ownerToken,
  Map<String, _SectionOwner> sectionsByFile,
) {
  return switch (ownerToken) {
    'docs/_registry/public_api_v1.yaml' || 'retired_public_exports' =>
      _sectionByFileHasProof(sectionsByFile, 'docs/contracts/public_api_v1.md'),
    'docs/architecture/architecture_graph.yaml' =>
      File(ownerToken).existsSync() &&
          Directory('test/architecture_graph').existsSync(),
    'example/**' => _sectionHasTest(
      sectionsByFile['docs/contracts/public_api_v1.md'],
      'test.api_contract.example_public_boundary',
    ),
    _ => false,
  };
}

bool _sectionByFileHasProof(
  Map<String, _SectionOwner> sectionsByFile,
  String file,
) {
  final section = sectionsByFile[file];
  return section != null && _sectionHasExecutableProof(section);
}

bool _sectionHasTest(_SectionOwner? section, String testId) {
  return section?.tests.contains(testId) ?? false;
}

bool _isGlobOwnerToken(String ownerToken) {
  return ownerToken.contains('*') ||
      ownerToken.startsWith('tool/') ||
      ownerToken.startsWith('.github/workflows/');
}

bool _globOwnerExists(String ownerToken) {
  final root = ownerToken.replaceAll('/**', '').replaceAll('/*.dart', '');
  return Directory(root).existsSync() || File(root).existsSync();
}

bool _globOwnerHasExecutableProof(String ownerToken) {
  return switch (ownerToken) {
    'test/api_contract/**' => Directory('test/api_contract').existsSync(),
    'test/smoke/**' => Directory('test/smoke').existsSync(),
    'docs/tool/*.dart' => Directory('docs/tool').existsSync(),
    'tool/guardrails/**' => guardrailInventory().isNotEmpty,
    'tool/architecture_graph/**' => Directory(
      'test/architecture_graph',
    ).existsSync(),
    'tool/bench/**' => Directory('test/benchmarks').existsSync(),
    '.github/workflows/**' => _testProofFileExists(
      'test.guardrails.release_readiness',
    ),
    _ => false,
  };
}

bool _sectionHasExecutableProof(_SectionOwner section) {
  return [
    ...section.tests,
    ...section.guardrails,
  ].any(_hasExecutableProofOwner);
}

List<_DesignTransferRow> _designTransferRows() {
  final text = File(_legacyPhaseCleanupDesignPath).readAsStringSync();
  return [
    ..._transferRowsFromTable(text, 'Current-invariant transfer map:'),
    ..._transferRowsFromTable(text, 'Legacy inventory transfer:'),
    ..._transferRowsFromTable(text, 'Accepted-differences transfer:'),
  ];
}

List<_DesignTransferRow> _transferRowsFromTable(String text, String title) {
  final parts = text.split(title);
  if (parts.length < 2) {
    throw StateError('missing design transfer table $title');
  }
  final tableLines = parts[1]
      .split('\n')
      .skipWhile((line) => !line.startsWith('|'))
      .takeWhile((line) => line.startsWith('|'))
      .toList();
  final header = _markdownCells(tableLines.first);
  final ownerIndex = header.indexOf('Current owner after cleanup');
  if (ownerIndex < 0) {
    throw StateError('missing current-owner column in $title');
  }

  return [
    for (final line in tableLines.skip(2))
      _DesignTransferRow(
        label: _markdownCells(line).first,
        currentOwnerCell: _markdownCells(line)[ownerIndex],
      ),
  ];
}

List<String> _markdownCells(String line) {
  final cells = line.trim().split('|');
  return cells
      .skip(1)
      .take(cells.length - 2)
      .map((cell) => cell.trim())
      .toList();
}

List<String> _backtickValues(String text) {
  return [
    for (final match in RegExp(r'`([^`]+)`').allMatches(text)) ?match.group(1),
  ];
}

Map<String, _SectionOwner> _loadSectionsByFile() {
  return {
    for (final section in _loadYamlList(
      'docs/_registry/sections.yaml',
    ).cast<YamlMap>())
      section['file'] as String: _SectionOwner(
        file: section['file'] as String,
        tests: _stringList(section, 'tests').where(_notNone).toSet(),
        guardrails: _stringList(section, 'guardrails').where(_notNone).toSet(),
      ),
  };
}

List<Object?> _loadYamlList(String path) {
  final parsed = loadYaml(File(path).readAsStringSync());
  return (parsed as YamlList).nodes.map((node) => node.value).toList();
}

List<String> _stringList(YamlMap map, String field) {
  final value = map[field] as YamlList;
  return value.nodes.map((node) => node.value as String).toList();
}

bool _hasExecutableProofOwner(String value) {
  return _testProofFileExists(value) || guardrailInventory().containsKey(value);
}

bool _testProofFileExists(String value) {
  if (!value.startsWith('test.')) {
    return false;
  }
  return _testProofPathCandidates(value).any((path) => File(path).existsSync());
}

List<String> _testProofPathCandidates(String value) {
  final override = _testProofPathOverrides[value];
  final parts = value.replaceFirst('test.', '').split('.');
  final conventionalPath =
      'test/${parts.take(parts.length - 1).join('/')}/${parts.last}_test.dart';
  return [?override, conventionalPath];
}

bool _isRetiredProofSource(String value) {
  return value == 'docs/_registry/donors.yaml' ||
      value == 'docs/architecture/04_decisions_and_differences.md' ||
      value == 'docs/verification/legacy_capability_inventory.md' ||
      value.startsWith('docs/donors/') ||
      value.startsWith('docs/implementation/');
}

bool _notNone(String value) => value != 'none';

final class _SectionOwner {
  const _SectionOwner({
    required this.file,
    required this.tests,
    required this.guardrails,
  });

  final String file;
  final Set<String> tests;
  final Set<String> guardrails;
}

final class _DesignTransferRow {
  const _DesignTransferRow({
    required this.label,
    required this.currentOwnerCell,
  });

  final String label;
  final String currentOwnerCell;
}

const _testProofPathOverrides = {
  'test.guardrails.release_readiness':
      'test/guardrails/release_readiness_guardrail_test.dart',
};

const _legacyPhaseCleanupDesignPath =
    '.design/2026-06-08-legacy-phase-cleanup.md';
