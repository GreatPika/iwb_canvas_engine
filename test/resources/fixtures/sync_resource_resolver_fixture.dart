import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import '../../support/vector_preparation_fixture.dart';
import 'surface_resource_session_test_support.dart';

void main() {
  _testSyncResolutionAndRevisionCache();
  _testSyncVectorResolutionAndRevisionCache();
  _testVectorSessionFallbackDoesNotAllocateDiagnostics();
}

void _testVectorSessionFallbackDoesNotAllocateDiagnostics() {
  test('vector session fallback does not allocate diagnostic records', () {
    DiagnosticRecord.allocations.reset();
    final session = SurfaceResourceSession(
      resolver: null,
      mutationGuard: CountingResolverMutationGuard(),
    );

    final result = session.resolveResource(vectorDescriptorRequest(id: 'zero'));

    expect(result, isA<NoResolverResourceAssetPlaceholder>());
    expect(DiagnosticRecord.allocations.count, 0);
  });
}

// The resolver payload, cache hit, and revision miss assertions share one
// resolver call sequence; splitting them would hide the compatibility proof.
// ignore: halstead-volume, source-lines-of-code
void _testSyncResolutionAndRevisionCache() {
  test(
    'surface session resolves synchronously and caches by revision',
    () async {
      final firstImage = await createResourceTestImage(0xff00aa00);
      final secondImage = await createResourceTestImage(0xff0000aa);
      final guard = CountingResolverMutationGuard();
      final returnedImages = [firstImage, secondImage];
      final resolver = RecordingResourceResolver((_) {
        return returnedImages.removeAt(0);
      });
      final session = SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: guard,
      );
      final request = descriptorRequest(
        id: 'resource-a',
        appKey: 'asset-a',
        mimeType: 'image/png',
        contentHash: 'sha256:resource-a',
        byteLength: 2048,
        metadata: CanvasMetadata.fromMap({'role': 'fixture'}),
      );

      final first = session.resolveResource(request);
      final cached = session.resolveResource(request);
      final revisionMiss = session.resolveResource(
        descriptorRequest(id: 'resource-a', resourceRevision: 1),
      );
      final resolvedResource = resolver.resources.first;
      final resolvedSource =
          resolvedResource.source as CanvasAppKeyResourceSource;

      expect(first, isA<ResolvedResourceAsset>());
      expect(identical(resolvedImage(first), firstImage), isTrue);
      expect(identical(resolvedImage(cached), firstImage), isTrue);
      expect(identical(resolvedImage(revisionMiss), secondImage), isTrue);
      expect(resolver.callCount, 2);
      expect(guard.callbackCount, 2);
      expect(resolvedResource.id, CanvasResourceId('resource-a'));
      expect(resolvedSource.key, 'asset-a');
      expect(resolvedResource.mimeType, 'image/png');
      expect(resolvedResource.contentHash, 'sha256:resource-a');
      expect(resolvedResource.byteLength, 2048);
      expect(
        resolvedResource.metadata,
        CanvasMetadata.fromMap({'role': 'fixture'}),
      );

      firstImage.dispose();
      secondImage.dispose();
    },
  );
}

// The prepared wrapper returned by the app is borrowed synchronously; cache
// reuse must not invoke preparation or expose any pending resolver state.
// Keeping cache hit and revision miss in one resolver sequence is clearer than
// splitting a single synchronous vector-resolution contract for a metric.
// ignore: halstead-volume, source-lines-of-code
void _testSyncVectorResolutionAndRevisionCache() {
  test(
    'surface session resolves prepared vectors synchronously and caches them',
    () async {
      final firstPrepared = await prepareVector(basicVectorBytes());
      final secondPrepared = await prepareVector(basicVectorBytes());
      final resolver = _VectorRecordingResolver([
        firstPrepared,
        secondPrepared,
      ]);
      final session = SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: CountingResolverMutationGuard(),
      );
      final resource = CanvasVectorResource(
        id: CanvasResourceId('vector-a'),
        source: CanvasResourceSource.appKey('vector-a'),
        contentHash: 'sha256:vector-a',
        byteLength: 42,
        metadata: CanvasMetadata.fromMap({'role': 'vector'}),
      );
      final request = ResourceAssetResolveRequest.descriptor(
        resource: resource,
        resourceRevision: 0,
        placeholderBounds: const ui.Rect.fromLTWH(1, 2, 30, 40),
      );

      final first = session.resolveResource(request);
      final cached = session.resolveResource(request);
      final revisionMiss = session.resolveResource(
        ResourceAssetResolveRequest.descriptor(
          resource: resource,
          resourceRevision: 1,
          placeholderBounds: request.placeholderBounds,
        ),
      );

      expect(_resolvedVector(first), same(firstPrepared));
      expect(_resolvedVector(cached), same(firstPrepared));
      expect(_resolvedVector(revisionMiss), same(secondPrepared));
      expect(resolver.callCount, 2);

      firstPrepared.dispose();
      secondPrepared.dispose();
    },
  );
}

CanvasPreparedVector _resolvedVector(ResourceAssetResolveResult result) {
  final asset = (result as ResolvedResourceAsset).asset;
  if (asset is! VectorResourceAsset) {
    throw StateError('Expected a vector resource asset.');
  }

  return asset.prepared;
}

final class _VectorRecordingResolver implements CanvasResourceResolver {
  _VectorRecordingResolver(this._prepared);

  final List<CanvasPreparedVector> _prepared;
  int callCount = 0;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) => null;

  @override
  CanvasPreparedVector? resolveVector(CanvasVectorResource resource) {
    callCount += 1;

    return _prepared.removeAt(0);
  }
}
