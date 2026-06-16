@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('current docs navigation', () {
    _registerGeneratedIndexesTest();
    _registerEntrypointRouteTest();
    _registerSectionRegistryRetiredFieldTest();
    _registerDiagramCatalogOwnerTest();
  });
}

void _registerGeneratedIndexesTest() {
  test('generated indexes expose current lookup routes only', () {
    final indexes = Directory(
      'docs/indexes',
    ).listSync().whereType<File>().map((file) => file.path).toSet();

    expect(indexes, containsAll(_currentIndexPaths));
    expect(indexes, isNot(contains('docs/indexes/by_phase.md')));
    expect(indexes, isNot(contains('docs/indexes/donor_to_phase.md')));
  });
}

void _registerEntrypointRouteTest() {
  test('docs entrypoints reject retired phase and donor routes', () {
    final entrypointText = [
      File('docs/README.md').readAsStringSync(),
      File('docs/architecture/README.md').readAsStringSync(),
    ].join('\n');

    for (final route in _retiredRoutes) {
      expect(entrypointText, isNot(contains(route)), reason: route);
    }
  });
}

void _registerSectionRegistryRetiredFieldTest() {
  test('section registry rejects retired route metadata fields', () {
    final registryText = File(
      'docs/_registry/sections.yaml',
    ).readAsStringSync();

    for (final field in _retiredSectionFields) {
      expect(registryText, isNot(contains('\n  $field:')), reason: field);
    }
  });
}

void _registerDiagramCatalogOwnerTest() {
  test('generated diagram catalog uses current owner metadata', () {
    final catalog = File('docs/diagrams/catalog.md').readAsStringSync();

    expect(catalog, contains('Related owners:'));
    expect(catalog, isNot(contains('Related phases:')));
  });
}

const _currentIndexPaths = {
  'docs/indexes/by_owner.md',
  'docs/indexes/by_subsystem.md',
  'docs/indexes/by_guardrail.md',
  'docs/indexes/by_test_area.md',
  'docs/indexes/by_diagram.md',
  'docs/indexes/by_release.md',
};

const _retiredRoutes = {
  'docs/indexes/by_phase.md',
  'docs/indexes/donor_to_phase.md',
  'docs/implementation/',
  'docs/donors/',
};

const _retiredSectionFields = {'phases', 'donors', 'benchmarks'};
