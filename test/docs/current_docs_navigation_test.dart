@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../docs/tool/check_docs.dart' as docs_checker;

void main() {
  group('current docs navigation', () {
    _registerGeneratedIndexesTest();
    _registerEntrypointRouteTest();
    _registerDiagramCatalogOwnerTest();
    _registerDocsRootTest();
    _registerDocsRouteTest();
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
  test('docs entrypoints reject retired phase donor and plan routes', () {
    final entrypointText = [
      File('docs/README.md').readAsStringSync(),
      File('docs/architecture/README.md').readAsStringSync(),
    ].join('\n');

    for (final route in _retiredRoutes) {
      expect(entrypointText, isNot(contains(route)), reason: route);
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

void _registerDocsRootTest() {
  test('docs checker excludes retired historical roots from active roots', () {
    expect(docs_checker.isRetiredDocsRoot('docs/implementation'), isTrue);
    expect(
      docs_checker.isRetiredDocsRoot('docs/implementation/current'),
      isTrue,
    );
    expect(docs_checker.isRetiredDocsRoot('docs/donors'), isTrue);
    expect(docs_checker.isRetiredDocsRoot('docs/donors/current'), isTrue);
    expect(docs_checker.isRetiredDocsRoot('docs/contracts'), isFalse);
  });
}

void _registerDocsRouteTest() {
  test('docs checker rejects retired route roots with or without slash', () {
    expect(docs_checker.isRetiredDocsRoute('docs/implementation'), isTrue);
    expect(
      docs_checker.isRetiredDocsRoute('docs/implementation/current'),
      isTrue,
    );
    expect(docs_checker.isRetiredDocsRoute('docs/donors'), isTrue);
    expect(docs_checker.isRetiredDocsRoute('docs/donors/current'), isTrue);
    expect(docs_checker.isRetiredDocsRoute('docs/indexes/by_phase.md'), isTrue);
    expect(
      docs_checker.isRetiredDocsRoute('docs/indexes/by_owner.md'),
      isFalse,
    );
  });
}

const _currentIndexPaths = {
  'docs/indexes/by_owner.md',
  'docs/indexes/by_subsystem.md',
  'docs/indexes/by_guardrail.md',
  'docs/indexes/by_test_area.md',
  'docs/indexes/by_benchmark.md',
  'docs/indexes/by_diagram.md',
  'docs/indexes/by_release.md',
};

const _retiredRoutes = {
  'docs/indexes/by_phase.md',
  'docs/indexes/donor_to_phase.md',
  'docs/implementation/',
  'docs/donors/',
  'PLAN.md',
  'plan/',
};
