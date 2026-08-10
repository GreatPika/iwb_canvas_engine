import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import '../../support/vector_preparation_fixture.dart';
import 'surface_resource_session_test_support.dart';

void main() {
  _testFrameScopedNullSuppressionAndPlaceholders();
  _testDisposedPreparedVectorIsSuppressedThenRetried();
  _testDisposedCachedPreparedVectorIsEvictedThenRetried();
}

// The frame-scoped proof is clearest as one ordered scenario that compares
// null-result suppression with missing and absent-resolver placeholder paths.
// ignore: halstead-volume, source-lines-of-code
void _testFrameScopedNullSuppressionAndPlaceholders() {
  test(
    'null results are frame-scoped and unresolved inputs stay bounded',
    () async {
      final image = await createResourceTestImage();
      final guard = CountingResolverMutationGuard();
      final nullResolver = RecordingResourceResolver((_) => null);
      final session = SurfaceResourceSession(
        resolver: nullResolver,
        mutationGuard: guard,
      );
      final request = descriptorRequest(id: 'resource-a');

      expect(
        session.resolveResource(request),
        isA<NullResourceAssetPlaceholder>(),
      );
      expect(
        session.resolveResource(request),
        isA<NullResourceAssetPlaceholder>(),
      );
      expect(nullResolver.callCount, 1);
      expect(guard.callbackCount, 1);

      session.beginFrameResourcePass();
      expect(
        session.resolveResource(request),
        isA<NullResourceAssetPlaceholder>(),
      );
      expect(nullResolver.callCount, 2);

      final missing = missingRequest(id: 'missing');
      expect(
        session.resolveResource(missing),
        isA<MissingDescriptorResourceAssetPlaceholder>(),
      );
      expect(
        session.resolveResource(missing).placeholderBounds,
        missing.placeholderBounds,
      );
      expect(nullResolver.callCount, 2);

      session.replaceResolver(null);
      expect(
        session.resolveResource(request),
        isA<NoResolverResourceAssetPlaceholder>(),
      );
      expect(
        session.resolveResource(request),
        isA<NoResolverResourceAssetPlaceholder>(),
      );
      expect(guard.callbackCount, 2);

      final imageResolver = RecordingResourceResolver((_) => image);
      session.replaceResolver(imageResolver);
      expect(session.resolveResource(request), isA<ResolvedResourceAsset>());
      expect(imageResolver.callCount, 1);

      image.dispose();
    },
  );
}

// Same-frame suppression and next-frame retry are one temporal outcome, so
// their assertions stay together instead of splitting a disposed-value case.
// ignore: halstead-volume
void _testDisposedPreparedVectorIsSuppressedThenRetried() {
  test('disposed prepared vectors never enter the session cache', () async {
    final prepared = await prepareVector(basicVectorBytes());
    prepared.dispose();
    final resolver = _DisposedVectorResolver(prepared);
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: CountingResolverMutationGuard(),
    );
    final request = ResourceAssetResolveRequest.descriptor(
      resource: CanvasVectorResource(
        id: CanvasResourceId('vector-a'),
        source: CanvasResourceSource.appKey('vector-a'),
        contentHash: 'sha256:vector-a',
        byteLength: 42,
        metadata: CanvasMetadata.fromMap({'role': 'vector'}),
      ),
      resourceRevision: 0,
      placeholderBounds: const ui.Rect.fromLTWH(1, 2, 30, 40),
    );

    expect(
      session.resolveResource(request),
      isA<NullResourceAssetPlaceholder>(),
    );
    expect(
      session.resolveResource(request),
      isA<NullResourceAssetPlaceholder>(),
    );
    expect(resolver.callCount, 1);

    session.beginFrameResourcePass();
    expect(
      session.resolveResource(request),
      isA<NullResourceAssetPlaceholder>(),
    );
    expect(resolver.callCount, 2);
  });
}

// One ordered case covers a stale prepared value, its frame-local null result,
// and the later retry; keeping it together makes liveness easier to audit.
// ignore: halstead-volume
void _testDisposedCachedPreparedVectorIsEvictedThenRetried() {
  test(
    'disposed cached prepared vectors become bounded placeholders',
    () async {
      final prepared = await prepareVector(basicVectorBytes());
      final resolver = _DisposedVectorResolver(prepared);
      final session = SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: CountingResolverMutationGuard(),
      );
      final request = ResourceAssetResolveRequest.descriptor(
        resource: CanvasVectorResource(
          id: CanvasResourceId('cached-vector-a'),
          source: CanvasResourceSource.appKey('cached-vector-a'),
          contentHash: 'sha256:cached-vector-a',
          byteLength: 42,
          metadata: CanvasMetadata.fromMap({'role': 'vector'}),
        ),
        resourceRevision: 0,
        placeholderBounds: const ui.Rect.fromLTWH(1, 2, 30, 40),
      );

      expect(session.resolveResource(request), isA<ResolvedResourceAsset>());
      prepared.dispose();

      expect(
        session.resolveResource(request),
        isA<NullResourceAssetPlaceholder>(),
      );
      expect(resolver.callCount, 1);
      expect(
        session.resolveResource(request),
        isA<NullResourceAssetPlaceholder>(),
      );
      expect(resolver.callCount, 1);

      session.beginFrameResourcePass();
      expect(
        session.resolveResource(request),
        isA<NullResourceAssetPlaceholder>(),
      );
      expect(resolver.callCount, 2);
    },
  );
}

final class _DisposedVectorResolver implements CanvasResourceResolver {
  _DisposedVectorResolver(this.prepared);

  final CanvasPreparedVector prepared;
  int callCount = 0;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) => null;

  @override
  CanvasPreparedVector? resolveVector(CanvasVectorResource resource) {
    callCount += 1;

    return prepared;
  }
}
