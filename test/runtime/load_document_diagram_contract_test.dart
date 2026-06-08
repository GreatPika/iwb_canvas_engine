import 'dart:io';

import 'package:test/test.dart';

void main() {
  _testLoadDiagramRetiredRouteAbsence();
  _testLoadDiagramRequiredClaims();
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
