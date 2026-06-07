import 'dart:io';

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
    final importSource = File(
      'lib/src/store/schema_v1_store_import.dart',
    ).readAsStringSync();
    final resourceSource = File(
      'lib/src/store/resource_table.dart',
    ).readAsStringSync();

    expect(importSource, isNot(contains('CanvasImageResource')));
    expect(importSource, isNot(contains('CanvasDocument(')));
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
  });
}
