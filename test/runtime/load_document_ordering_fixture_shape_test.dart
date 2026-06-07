import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

void main() {
  _testRecordingLoadBoundaryShape();
  _testLoadDiagramRetiredRouteAbsence();
  _testLoadDiagramRequiredClaims();
}

void _testRecordingLoadBoundaryShape() {
  test('recording load boundary exposes no deferred cleanup surface', () {
    final declaration = _classDeclaration(
      _loadOrderingFixtureUnit(),
      '_RecordingLoadBoundary',
    );

    expect(_fieldTypesByName(declaration), {
      'events': 'List<String>',
      'onPrepareCleanup': 'void Function()?',
    });
    expect(_methodNames(declaration), ['prepareLoadCleanup']);
  });
}

void _testLoadDiagramRetiredRouteAbsence() {
  test('registered load diagrams show canonical JSON store-row flow', () {
    for (final path in _loadDiagramPaths) {
      final source = File(path).readAsStringSync();

      expect(source, contains('loadDocumentFromJson'));
      expect(source, contains(RegExp('schema-v1', caseSensitive: false)));
      expect(source, contains(RegExp('store', caseSensitive: false)));
      expect(source, contains(RegExp('projection', caseSensitive: false)));
      expect(source, isNot(contains('decodeCanvasDocument')));
      expect(source, isNot(contains('loadDocument(document)')));
      expect(source, isNot(contains('CanvasDocument DTO')));
    }
  });
}

void _testLoadDiagramRequiredClaims() {
  test('load diagrams preserve import, store, and no-projection claims', () {
    final success = File(
      'docs/diagrams/seq_load_document_success.mmd',
    ).readAsStringSync();
    final failure = File(
      'docs/diagrams/seq_load_document_failure.mmd',
    ).readAsStringSync();
    final dataFlow = File(
      'docs/diagrams/dfd_load_document_success_failure.mmd',
    ).readAsStringSync();

    expect(success, contains('Schema v1 import events'));
    expect(success, contains('PreparedStoreDocumentImport'));
    expect(
      success,
      contains('does not build the first CanvasDocument projection'),
    );
    expect(failure, contains('Failure stops before prepared store install'));
    expect(failure, contains('No CanvasRuntimeState publication'));
    expect(dataFlow, contains('resource descriptor rows'));
    expect(dataFlow, contains('no CanvasActionCommitted'));
  });
}

const _loadDiagramPaths = [
  'docs/diagrams/seq_load_document_success.mmd',
  'docs/diagrams/seq_load_document_failure.mmd',
  'docs/diagrams/dfd_load_document_success_failure.mmd',
];

CompilationUnit _loadOrderingFixtureUnit() {
  return parseFile(
    path:
        '${Directory.current.path}/test/runtime/fixtures/load_document_ordering_fixture.dart',
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}

ClassDeclaration _classDeclaration(CompilationUnit unit, String className) {
  return unit.declarations.whereType<ClassDeclaration>().singleWhere(
    (declaration) => declaration.namePart.typeName.lexeme == className,
  );
}

Map<String, String> _fieldTypesByName(ClassDeclaration declaration) {
  return {
    for (final field in declaration.body.members.whereType<FieldDeclaration>())
      for (final variable in field.fields.variables)
        variable.name.lexeme: field.fields.type?.toSource() ?? '',
  };
}

List<String> _methodNames(ClassDeclaration declaration) {
  return [
    for (final method
        in declaration.body.members.whereType<MethodDeclaration>())
      method.name.lexeme,
  ];
}
