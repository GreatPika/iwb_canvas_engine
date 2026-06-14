import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/resources/resource_cache.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import 'surface_resource_session_test_support.dart';

void main() {
  _testTargetAndAllInvalidation();
  _testDocumentReplacementReset();
  _testLeastRecentlyUsedEviction();
  _testOversizedResolveReturnsWithoutRetaining();
  _testDroppedSessionDoesNotResolveAgain();
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

      session.resolveImage(requestA);
      session.resolveImage(requestB);
      session.resolveImage(requestA);
      session.resolveImage(requestB);
      expect(resolver.callCount, 2);

      session.invalidateResourceImage(CanvasResourceId('resource-a'));
      session.resolveImage(requestA);
      session.resolveImage(requestB);
      expect(resolver.callCount, 3);

      session.invalidateAllResourceImages();
      session.resolveImage(requestA);
      session.resolveImage(requestB);
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
  session.resolveImage(descriptorRequest(id: 'resource-a'));
  session.resolveImage(descriptorRequest(id: 'resource-a'));
  expect(resolver.callCount, 1);

  session.resolveImage(descriptorRequest(id: 'missing-resource'));
  session.resolveImage(descriptorRequest(id: 'missing-resource'));
  expect(resolver.callCount, 2);
}

void _exhaustResolverBudget(SurfaceResourceSession session) {
  for (var index = 0; index < 128; index += 1) {
    session.resolveImage(descriptorRequest(id: 'budget-$index'));
  }
  expect(
    session.resolveImage(descriptorRequest(id: 'budget-over')),
    isA<BudgetExceededResourceImagePlaceholder>(),
  );
  expect(session.hasPendingBudgetFollowUpRepaint, isTrue);
}

void _expectReplacementResetClearedSessionState(
  SurfaceResourceSession session,
  RecordingResourceResolver resolver,
  int callCountBeforeReset,
) {
  expect(session.hasPendingBudgetFollowUpRepaint, isFalse);
  session.resolveImage(descriptorRequest(id: 'resource-a'));
  session.resolveImage(descriptorRequest(id: 'missing-resource'));
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
      session.resolveImage(descriptorRequest(id: 'resource-$index'));
    }
    expect(resolver.callCount, 1024);

    session.resolveImage(descriptorRequest(id: 'resource-0'));
    expect(resolver.callCount, 1024);

    session.beginFrameResourcePass();
    session.resolveImage(descriptorRequest(id: 'resource-1024'));
    expect(resolver.callCount, 1025);

    session.resolveImage(descriptorRequest(id: 'resource-0'));
    expect(resolver.callCount, 1025);

    session.resolveImage(descriptorRequest(id: 'resource-1'));
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
      cache: ImageResolveCache(maximumSizeBytes: 16),
    );
    final request = descriptorRequest(id: 'oversized-resource');

    expect(session.resolveImage(request), isA<ResolvedResourceImage>());
    expect(resolver.callCount, 1);

    expect(session.resolveImage(request), isA<ResolvedResourceImage>());
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

    expect(session.resolveImage(request), isA<ResolvedResourceImage>());
    expect(resolver.callCount, 1);

    session.drop();
    expect(
      session.resolveImage(request),
      isA<NoResolverResourceImagePlaceholder>(),
    );
    expect(resolver.callCount, 1);

    session.replaceResolver(resolver);
    session.beginFrameResourcePass();
    expect(
      session.resolveImage(request),
      isA<NoResolverResourceImagePlaceholder>(),
    );
    expect(resolver.callCount, 1);

    session.dispose();
    expect(
      session.resolveImage(request),
      isA<NoResolverResourceImagePlaceholder>(),
    );
    expect(resolver.callCount, 1);

    image.dispose();
  });
}
