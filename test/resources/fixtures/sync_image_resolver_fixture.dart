import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import 'surface_resource_session_test_support.dart';

void main() {
  _testSyncResolutionAndRevisionCache();
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
