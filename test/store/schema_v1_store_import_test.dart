import 'dart:io';

import 'package:characters/characters.dart';
import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('schema v1 import events prepare store-owned committed facts', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/schema_v1_store_import_fixture.dart',
      ),
      completes,
    );
  });

  test('schema v1 store import path does not construct public resources', () {
    expect(() {
      _expectSchemaImportAvoidsPublicDocumentProjection();
      _expectResourceProjectionOwnedByResourceTable();
      _expectResourceLookupAvoidsBulkProjection();
    }, returnsNormally);
  });
}

void _expectSchemaImportAvoidsPublicDocumentProjection() {
  final importSource = File(
    'lib/src/store/schema_v1_store_import.dart',
  ).readAsStringSync();

  expect(importSource, isNot(contains('CanvasImageResource')));
  expect(importSource, isNot(contains('CanvasDocument(')));
  expect(importSource, isNot(contains('List<SchemaV1ElementImportEvent>')));
  expect(importSource, isNot(contains('SchemaV1LayerImportEvent event;')));
  _expectFunctionExcludes(
    importSource,
    'prepare',
    forbidden: [
      'SchemaV1ElementImportEvent',
      '_families.add',
      '_resources.addSchemaV1Import',
      'LayerRow(',
    ],
  );
}

void _expectResourceProjectionOwnedByResourceTable() {
  final resourceSource = File(
    'lib/src/store/resource_table.dart',
  ).readAsStringSync();

  expect(
    resourceSource,
    contains('CanvasImageResource _resourceForDescriptor'),
  );
  expect(
    resourceSource.indexOf('CanvasImageResource _resourceForDescriptor'),
    greaterThan(
      resourceSource.indexOf('List<CanvasResource> projectResources'),
    ),
  );
}

void _expectResourceLookupAvoidsBulkProjection() {
  final storeSource = File(
    'lib/src/store/document_store_kernel.dart',
  ).readAsStringSync();

  _expectFunctionExcludes(
    storeSource,
    'resourceById',
    forbidden: ['projectResources'],
  );
}

void _expectFunctionExcludes(
  String source,
  String functionName, {
  required List<String> forbidden,
}) {
  final body = _declarationBody(source, functionName);
  for (final pattern in forbidden) {
    expect(body, isNot(contains(pattern)), reason: functionName);
  }
}

String _declarationBody(String source, String functionName) {
  final start = source.indexOf(functionName);
  expect(start, isNonNegative, reason: functionName);
  final open = source.indexOf('{', start);
  expect(open, isNonNegative, reason: functionName);
  var depth = 0;
  for (var index = open; index < source.length; index += 1) {
    final character = source[index];
    if (character == '{') {
      depth += 1;
    } else if (character == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.characters.skip(open + 1).take(index - open - 1).string;
      }
    }
  }
  fail('could not find $functionName body');
}
