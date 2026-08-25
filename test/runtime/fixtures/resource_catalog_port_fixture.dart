import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resource_catalog_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  test('catalog reads return copied committed resources', () {
    final root = runtimeRootWithCommittedDocumentSeed(_document());

    expect(() {
      final catalog = root.resourceCatalogPort;
      _expectCatalogPortShape(catalog);
      _expectCatalogCopies(catalog, root);
      _expectMissingLookup(catalog);
      _expectReturnedListCannotMutateStore(catalog);
    }, returnsNormally);

    root.dispose();
  });
}

void _expectCatalogPortShape(ResourceCatalogPort catalog) {
  expect(catalog, isA<ResourceCatalogPort>());
  expect(catalog.resourceCount, 1);
}

void _expectCatalogCopies(ResourceCatalogPort catalog, RuntimeRoot root) {
  final firstRead = catalog.resources;
  final secondRead = catalog.resources;
  final lookup = catalog.resourceById(CanvasResourceId('resource-a'));
  final committed = root.readDocument().resources.single;

  expect(firstRead, hasLength(1));
  expect(firstRead.single.id, CanvasResourceId('resource-a'));
  expect(
    (firstRead.single.source as CanvasAppKeyResourceSource).key,
    'asset-a',
  );
  expect(firstRead.single.metadata, CanvasMetadata.fromMap({'role': 'hero'}));
  expect(lookup, isNotNull);
  expect(lookup, isNot(same(committed)));
  expect(firstRead.single, isNot(same(committed)));
  expect(firstRead.single, isNot(same(secondRead.single)));
}

void _expectMissingLookup(ResourceCatalogPort catalog) {
  expect(catalog.resourceById(CanvasResourceId('missing')), isNull);
}

void _expectReturnedListCannotMutateStore(ResourceCatalogPort catalog) {
  final resources = catalog.resources;

  expect(
    () => resources.add(
      CanvasImageResource(
        id: CanvasResourceId('resource-b'),
        source: CanvasResourceSource.appKey('asset-b'),
      ),
    ),
    throwsUnsupportedError,
  );
  expect(catalog.resources.map((resource) => resource.id), [
    CanvasResourceId('resource-a'),
  ]);
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('asset-a'),
        metadata: CanvasMetadata.fromMap({'role': 'hero'}),
      ),
    ],
  );
}
