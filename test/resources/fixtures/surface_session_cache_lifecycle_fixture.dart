import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_prepared_vector.dart';
import 'package:iwb_canvas_engine/src/resources/resource_cache.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import 'surface_resource_session_test_support.dart';
import '../../preparation/fixtures/vector_preparation_fixture.dart';

void main() {
  _testTargetAndAllInvalidation();
  _testTargetReleaseClearsNullSuppression();
  _testDocumentReplacementReset();
  _testLeastRecentlyUsedEviction();
  _testOversizedResolveReturnsWithoutRetaining();
  _testDroppedSessionDoesNotResolveAgain();
  _testVectorLifecycleReleasesSessionAndRetainedBorrows();
}

// Removing target suppression release would keep the next externally requested
// resolve suppressed even though synchronous resource release already returned.
void _testTargetReleaseClearsNullSuppression() {
  test('target release clears matching null suppression without resolving', () {
    final resolver = RecordingResourceResolver((_) => null);
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: CountingResolverMutationGuard(),
    );
    final request = descriptorRequest(id: 'resource-a');

    session.resolveResource(request);
    session.resolveResource(request);
    expect(resolver.callCount, 1);

    session.releaseResource(CanvasResourceId('resource-a'));
    expect(resolver.callCount, 1);

    session.resolveResource(request);
    expect(resolver.callCount, 2);
  });
}

void _testTargetAndAllInvalidation() {
  test(
    'target and all invalidation control only session cache entries',
    () async {
      final image = await createResourceTestImage();
      final resolver = RecordingResourceResolver((_) => image);
      final session = SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: CountingResolverMutationGuard(),
      );
      final requestA = descriptorRequest(id: 'resource-a');
      final requestB = descriptorRequest(id: 'resource-b');

      session.resolveResource(requestA);
      session.resolveResource(requestB);
      session.resolveResource(requestA);
      session.resolveResource(requestB);
      expect(resolver.callCount, 2);

      session.releaseResource(CanvasResourceId('resource-a'));
      session.resolveResource(requestA);
      session.resolveResource(requestB);
      expect(resolver.callCount, 3);

      session.releaseAllResources();
      session.resolveResource(requestA);
      session.resolveResource(requestB);
      expect(resolver.callCount, 5);

      image.dispose();
    },
  );
}

void _testDocumentReplacementReset() {
  test(
    'document replacement reset clears cache, null suppression, and budget',
    () async {
      final image = await createResourceTestImage();
      final resolver = RecordingResourceResolver(
        (resource) => resource.id.value == 'missing-resource' ? null : image,
      );
      final session = SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: CountingResolverMutationGuard(),
      );
      _populateCacheAndNullSuppression(session, resolver);
      _exhaustResolverBudget(session);
      final callCountBeforeReset = resolver.callCount;

      session.resetForDocumentReplacement();

      _expectReplacementResetClearedSessionState(
        session,
        resolver,
        callCountBeforeReset,
      );
      expect(resolver.callCount, greaterThan(callCountBeforeReset));

      image.dispose();
    },
  );
}

void _populateCacheAndNullSuppression(
  SurfaceResourceSession session,
  RecordingResourceResolver resolver,
) {
  session.resolveResource(descriptorRequest(id: 'resource-a'));
  session.resolveResource(descriptorRequest(id: 'resource-a'));
  expect(resolver.callCount, 1);

  session.resolveResource(descriptorRequest(id: 'missing-resource'));
  session.resolveResource(descriptorRequest(id: 'missing-resource'));
  expect(resolver.callCount, 2);
}

void _exhaustResolverBudget(SurfaceResourceSession session) {
  for (var index = 0; index < 128; index += 1) {
    session.resolveResource(descriptorRequest(id: 'budget-$index'));
  }
  expect(
    session.resolveResource(descriptorRequest(id: 'budget-over')),
    isA<BudgetExceededResourceAssetPlaceholder>(),
  );
  expect(session.hasPendingBudgetFollowUpRepaint, isTrue);
}

void _expectReplacementResetClearedSessionState(
  SurfaceResourceSession session,
  RecordingResourceResolver resolver,
  int callCountBeforeReset,
) {
  expect(session.hasPendingBudgetFollowUpRepaint, isFalse);
  session.resolveResource(descriptorRequest(id: 'resource-a'));
  session.resolveResource(descriptorRequest(id: 'missing-resource'));
  expect(resolver.callCount, callCountBeforeReset + 2);
}

void _testLeastRecentlyUsedEviction() {
  test('session cache evicts least recently used entries', () async {
    final image = await createResourceTestImage();
    final resolver = RecordingResourceResolver((_) => image);
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: CountingResolverMutationGuard(),
    );

    for (var index = 0; index < 1024; index += 1) {
      if (index % 128 == 0) {
        session.beginFrameResourcePass();
      }
      session.resolveResource(descriptorRequest(id: 'resource-$index'));
    }
    expect(resolver.callCount, 1024);

    session.resolveResource(descriptorRequest(id: 'resource-0'));
    expect(resolver.callCount, 1024);

    session.beginFrameResourcePass();
    session.resolveResource(descriptorRequest(id: 'resource-1024'));
    expect(resolver.callCount, 1025);

    session.resolveResource(descriptorRequest(id: 'resource-0'));
    expect(resolver.callCount, 1025);

    session.resolveResource(descriptorRequest(id: 'resource-1'));
    expect(resolver.callCount, 1026);

    image.dispose();
  });
}

void _testOversizedResolveReturnsWithoutRetaining() {
  test('oversized resolver result returns but is not retained', () async {
    final image = await createSizedResourceTestImage(width: 3, height: 2);
    final resolver = RecordingResourceResolver((_) => image);
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: CountingResolverMutationGuard(),
      cache: ResourceAssetCache(maximumSizeBytes: 16),
    );
    final request = descriptorRequest(id: 'oversized-resource');

    expect(session.resolveResource(request), isA<ResolvedResourceAsset>());
    expect(resolver.callCount, 1);

    expect(session.resolveResource(request), isA<ResolvedResourceAsset>());
    expect(resolver.callCount, 2);

    image.dispose();
  });
}

void _testDroppedSessionDoesNotResolveAgain() {
  test('dropped session cannot revive resolver or cache entries', () async {
    final image = await createResourceTestImage();
    final resolver = RecordingResourceResolver((_) => image);
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: CountingResolverMutationGuard(),
    );
    final request = descriptorRequest(id: 'resource-a');

    expect(session.resolveResource(request), isA<ResolvedResourceAsset>());
    expect(resolver.callCount, 1);

    session.drop();
    expect(
      session.resolveResource(request),
      isA<NoResolverResourceAssetPlaceholder>(),
    );
    expect(resolver.callCount, 1);

    session.replaceResolver(resolver);
    session.beginFrameResourcePass();
    expect(
      session.resolveResource(request),
      isA<NoResolverResourceAssetPlaceholder>(),
    );
    expect(resolver.callCount, 1);

    session.dispose();
    expect(
      session.resolveResource(request),
      isA<NoResolverResourceAssetPlaceholder>(),
    );
    expect(resolver.callCount, 1);

    image.dispose();
  });
}

// Every lifecycle branch is one chronological release contract: the session
// borrow must disappear before its matching retained-output callback returns.
// ignore: halstead-volume, source-lines-of-code
void _testVectorLifecycleReleasesSessionAndRetainedBorrows() {
  test(
    'vector target/all and lifecycle release session and retained borrows',
    () async {
      final prepared = await prepareVector(basicVectorBytes());
      final picture = liveCanvasPreparedVectorPicture(prepared);
      final disposedPictures = <ui.Picture>[];
      final previousOnDispose = ui.Picture.onDispose;
      ui.Picture.onDispose = disposedPictures.add;
      addTearDown(() {
        ui.Picture.onDispose = previousOnDispose;
      });
      final releasedTargets = <CanvasResourceId>[];
      var releasedAllCount = 0;
      final resolver = RecordingResourceResolver(
        (_) => null,
        resolvePreparedVector: (_) => prepared,
      );
      final session = SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: CountingResolverMutationGuard(),
        releaseRetainedResource: releasedTargets.add,
        releaseAllRetainedResources: () {
          releasedAllCount += 1;
        },
      );
      final first = vectorDescriptorRequest(id: 'vector-a');
      final second = vectorDescriptorRequest(id: 'vector-b');

      expect(session.resolveResource(first), isA<ResolvedResourceAsset>());
      session.releaseResource(first.id);
      expect(releasedTargets, [first.id]);
      expect(session.resolveResource(first), isA<ResolvedResourceAsset>());
      expect(resolver.vectorCallCount, 2);

      expect(session.resolveResource(second), isA<ResolvedResourceAsset>());
      session.releaseAllResources();
      expect(releasedAllCount, 1);
      expect(session.resolveResource(second), isA<ResolvedResourceAsset>());

      session.replaceResolver(resolver);
      expect(releasedAllCount, 2);
      expect(session.resolveResource(second), isA<ResolvedResourceAsset>());

      session.resetForDocumentReplacement();
      expect(releasedAllCount, 3);
      expect(session.resolveResource(second), isA<ResolvedResourceAsset>());

      session.drop();
      expect(releasedAllCount, 4);
      expect(
        session.resolveResource(second),
        isA<NoResolverResourceAssetPlaceholder>(),
      );
      expect(disposedPictures, isEmpty);

      prepared.dispose();
      expect(disposedPictures, [picture]);
    },
  );
}
