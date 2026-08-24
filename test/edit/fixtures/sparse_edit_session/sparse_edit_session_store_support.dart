import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/resource_table.dart';

import '../../../support/document_store_with_document.dart';

DocumentStoreKernel sparseTraceDocumentStore(CanvasDocument document) {
  return documentStoreWithDocument(document);
}

// One exhaustive descriptor matcher keeps every resource variant visible.
// ignore: halstead-volume
void expectInstalledSparseTraceDescriptor(
  StoreResourceDescriptorFacts? actual,
  CanvasResource expected, {
  required int expectedResourceRevision,
}) {
  if (actual == null) {
    fail('installed trace descriptor is absent for ${expected.id}.');
  }
  final descriptor = actual;
  expect(descriptor.id, expected.id);
  expect(descriptor.resourceRevision, expectedResourceRevision);
  switch (expected) {
    case CanvasImageResource(
      :final source,
      :final mimeType,
      :final contentHash,
      :final byteLength,
      :final metadata,
    ):
      expect(descriptor, isA<StoreImageResourceDescriptorFacts>());
      final image = descriptor as StoreImageResourceDescriptorFacts;
      expect(image.appKey, (source as CanvasAppKeyResourceSource).key);
      expect(image.mimeType, mimeType);
      expect(image.contentHash, contentHash);
      expect(image.byteLength, byteLength);
      expect(image.metadata, metadata);
    case CanvasVectorResource(
      :final source,
      :final contentHash,
      :final byteLength,
      :final metadata,
    ):
      expect(descriptor, isA<StoreVectorResourceDescriptorFacts>());
      final vector = descriptor as StoreVectorResourceDescriptorFacts;
      expect(vector.appKey, (source as CanvasAppKeyResourceSource).key);
      expect(vector.contentHash, contentHash);
      expect(vector.byteLength, byteLength);
      expect(vector.metadata, metadata);
  }
}
