import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/resources/resource_cache.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';

import '../../preparation/fixtures/vector_preparation_fixture.dart';
import 'surface_resource_session_test_support.dart';

void main() {
  _testByteCapEvictsLeastRecentlyUsedEntries();
  _testOversizedImagesAreNotRetained();
  _testEntryCapAndReadPromotion();
  _testReplacementAccounting();
  _testOversizedReplacementDropsOldEntry();
  _testInvalidationAndClearAccounting();
  _testDescriptorByteLengthDoesNotDriveCachePressure();
  _testVectorBorrowUsesAggregateEntryBudgetOnly();
  _testAggregate1024EntryCrossFamilyLru();
}

void _testByteCapEvictsLeastRecentlyUsedEntries() {
  test('cache keeps retained decoded bytes within maximum size', () async {
    final imageA = await createSizedResourceTestImage(width: 2, height: 2);
    final imageB = await createSizedResourceTestImage(width: 2, height: 2);
    final cache = ResourceAssetCache(maximumSizeBytes: 16);

    _writeCache(cache, id: CanvasResourceId('resource-a'), image: imageA);
    _writeCache(cache, id: CanvasResourceId('resource-b'), image: imageB);

    expect(cache.currentSizeBytes, 16);
    _expectCacheMiss(cache, CanvasResourceId('resource-a'));
    _expectCacheHit(cache, CanvasResourceId('resource-b'), imageB);

    imageA.dispose();
    imageB.dispose();
  });
}

void _testOversizedImagesAreNotRetained() {
  test('single oversized image misses immediately after write', () async {
    final image = await createSizedResourceTestImage(width: 3, height: 2);
    final cache = ResourceAssetCache(maximumSizeBytes: 16);

    _writeCache(cache, id: CanvasResourceId('oversized'), image: image);

    expect(cache.length, 0);
    expect(cache.currentSizeBytes, 0);
    _expectCacheMiss(cache, CanvasResourceId('oversized'));

    image.dispose();
  });
}

void _testEntryCapAndReadPromotion() {
  test('entry cap eviction still honors read promotion', () async {
    final imageA = await createResourceTestImage();
    final imageB = await createResourceTestImage();
    final imageC = await createResourceTestImage();
    final cache = ResourceAssetCache(capacity: 2);

    _writeCache(cache, id: CanvasResourceId('resource-a'), image: imageA);
    _writeCache(cache, id: CanvasResourceId('resource-b'), image: imageB);
    _expectCacheHit(cache, CanvasResourceId('resource-a'), imageA);
    expect(cache.currentSizeBytes, 8);

    _writeCache(cache, id: CanvasResourceId('resource-c'), image: imageC);

    expect(cache.length, 2);
    expect(cache.currentSizeBytes, 8);
    _expectCacheMiss(cache, CanvasResourceId('resource-b'));
    _expectCacheHit(cache, CanvasResourceId('resource-a'), imageA);

    imageA.dispose();
    imageB.dispose();
    imageC.dispose();
  });
}

void _testReplacementAccounting() {
  test('replacement subtracts the old decoded size before admission', () async {
    final first = await createSizedResourceTestImage(width: 2, height: 2);
    final replacement = await createSizedResourceTestImage(width: 3, height: 3);
    final cache = ResourceAssetCache(maximumSizeBytes: 40);
    final id = CanvasResourceId('replaced');

    _writeCache(cache, id: id, image: first);
    expect(cache.currentSizeBytes, 16);

    _writeCache(cache, id: id, image: replacement);
    expect(cache.currentSizeBytes, 36);
    _expectCacheHit(cache, id, replacement);

    first.dispose();
    replacement.dispose();
  });
}

void _testOversizedReplacementDropsOldEntry() {
  test('oversized replacement removes the previous retained entry', () async {
    final first = await createSizedResourceTestImage(width: 2, height: 2);
    final oversized = await createSizedResourceTestImage(width: 3, height: 2);
    final cache = ResourceAssetCache(maximumSizeBytes: 16);
    final id = CanvasResourceId('oversized-replacement');

    _writeCache(cache, id: id, image: first);
    expect(cache.currentSizeBytes, 16);

    _writeCache(cache, id: id, image: oversized);
    expect(cache.currentSizeBytes, 0);
    _expectCacheMiss(cache, id);

    first.dispose();
    oversized.dispose();
  });
}

void _testInvalidationAndClearAccounting() {
  test(
    'target invalidation and clear subtract retained decoded bytes',
    () async {
      final first = await createSizedResourceTestImage(width: 3, height: 3);
      final other = await createResourceTestImage();
      final cache = ResourceAssetCache(maximumSizeBytes: 40);
      final firstId = CanvasResourceId('first');
      final otherId = CanvasResourceId('other');

      _writeCache(cache, id: firstId, image: first);
      _writeCache(cache, id: otherId, image: other);
      expect(cache.currentSizeBytes, 40);

      cache.invalidateResource(firstId);
      expect(cache.currentSizeBytes, 4);
      _expectCacheHit(cache, otherId, other);

      cache.clear();
      expect(cache.length, 0);
      expect(cache.currentSizeBytes, 0);

      first.dispose();
      other.dispose();
    },
  );
}

void _testDescriptorByteLengthDoesNotDriveCachePressure() {
  test('descriptor byte length is not part of cache pressure', () async {
    final imageA = await createResourceTestImage();
    final imageB = await createSizedResourceTestImage(width: 2, height: 2);
    final cache = ResourceAssetCache(maximumSizeBytes: 16);
    final requestA = descriptorRequest(id: 'resource-a', byteLength: 1 << 20);
    final requestB = descriptorRequest(id: 'resource-b', byteLength: 1);

    _writeCache(
      cache,
      id: requestA.id,
      revision: requestA.resourceRevision,
      image: imageA,
    );
    _writeCache(
      cache,
      id: requestB.id,
      revision: requestB.resourceRevision,
      image: imageB,
    );

    expect(cache.currentSizeBytes, 16);
    _expectCacheMiss(cache, requestA.id, revision: requestA.resourceRevision);
    _expectCacheHit(
      cache,
      requestB.id,
      imageB,
      revision: requestB.resourceRevision,
    );

    imageA.dispose();
    imageB.dispose();
  });
}

void _testVectorBorrowUsesAggregateEntryBudgetOnly() {
  test(
    'vector borrows evict images by aggregate entry cap but add no bytes',
    () async {
      final image = await createResourceTestImage();
      final prepared = await prepareVector(basicVectorBytes());
      final cache = ResourceAssetCache(capacity: 1, maximumSizeBytes: 4);
      final imageId = CanvasResourceId('image-a');
      final vectorId = CanvasResourceId('vector-a');

      _writeCache(cache, id: imageId, image: image);
      cache.write(
        resolverGeneration: 0,
        resourceId: vectorId,
        resourceRevision: 0,
        asset: VectorResourceAsset(prepared),
      );

      expect(cache.length, 1);
      expect(cache.currentSizeBytes, 0);
      _expectCacheMiss(cache, imageId);
      expect(
        cache.read(
          resolverGeneration: 0,
          resourceId: vectorId,
          resourceRevision: 0,
        ),
        isA<VectorResourceAsset>(),
      );

      image.dispose();
      prepared.dispose();
    },
  );
}

// This uses the production 1024-entry default rather than a small proxy so
// cross-family eviction and the image-only byte ledger are observed together.
// ignore: halstead-volume, source-lines-of-code
void _testAggregate1024EntryCrossFamilyLru() {
  test(
    '1024 aggregate entries evict across image and vector families',
    () async {
      final image = await createResourceTestImage();
      final prepared = await prepareVector(basicVectorBytes());
      final cache = ResourceAssetCache();

      for (var index = 0; index < 512; index += 1) {
        _writeCache(cache, id: CanvasResourceId('image-$index'), image: image);
      }
      for (var index = 0; index < 512; index += 1) {
        cache.write(
          resolverGeneration: 0,
          resourceId: CanvasResourceId('vector-$index'),
          resourceRevision: 0,
          asset: VectorResourceAsset(prepared),
        );
      }

      expect(cache.length, 1024);
      expect(cache.currentSizeBytes, 512 * 4);

      cache.write(
        resolverGeneration: 0,
        resourceId: CanvasResourceId('vector-512'),
        resourceRevision: 0,
        asset: VectorResourceAsset(prepared),
      );
      expect(cache.length, 1024);
      expect(cache.currentSizeBytes, 511 * 4);
      _expectCacheMiss(cache, CanvasResourceId('image-0'));

      for (var index = 1; index < 512; index += 1) {
        _expectCacheHit(cache, CanvasResourceId('image-$index'), image);
      }
      cache.write(
        resolverGeneration: 0,
        resourceId: CanvasResourceId('image-512'),
        resourceRevision: 0,
        asset: ImageResourceAsset(image),
      );

      expect(cache.length, 1024);
      expect(cache.currentSizeBytes, 512 * 4);
      expect(
        cache.read(
          resolverGeneration: 0,
          resourceId: CanvasResourceId('vector-0'),
          resourceRevision: 0,
        ),
        isNull,
      );
      expect(
        cache.read(
          resolverGeneration: 0,
          resourceId: CanvasResourceId('vector-512'),
          resourceRevision: 0,
        ),
        isA<VectorResourceAsset>(),
      );

      image.dispose();
      prepared.dispose();
    },
  );
}

void _writeCache(
  ResourceAssetCache cache, {
  required CanvasResourceId id,
  required ui.Image image,
  int revision = 0,
}) {
  cache.write(
    resolverGeneration: 0,
    resourceId: id,
    resourceRevision: revision,
    asset: ImageResourceAsset(image),
  );
}

void _expectCacheHit(
  ResourceAssetCache cache,
  CanvasResourceId id,
  ui.Image image, {
  int revision = 0,
}) {
  expect(_readCache(cache, id, revision: revision), same(image));
}

void _expectCacheMiss(
  ResourceAssetCache cache,
  CanvasResourceId id, {
  int revision = 0,
}) {
  expect(_readCache(cache, id, revision: revision), isNull);
}

ui.Image? _readCache(
  ResourceAssetCache cache,
  CanvasResourceId id, {
  int revision = 0,
}) {
  final asset = cache.read(
    resolverGeneration: 0,
    resourceId: id,
    resourceRevision: revision,
  );

  return asset is ImageResourceAsset ? asset.image : null;
}
