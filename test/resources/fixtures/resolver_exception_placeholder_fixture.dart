import 'dart:ui' show Rect;

import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import 'surface_resource_session_test_support.dart';

void main() {
  _testOrdinaryStateErrorBecomesBoundedPlaceholder();
  _testOrdinaryNonStateErrorBecomesBoundedPlaceholder();
  _testResolverGuardRejectionsBubble();
  _testResolverExceptionsAreRetried();
  _testResolverExceptionsDoNotEnterNullSuppression();
  _testResolverExceptionsConsumeBudget();
}

void _testOrdinaryStateErrorBecomesBoundedPlaceholder() {
  test('ordinary resolver StateError returns exception placeholder', () async {
    final image = await createResourceTestImage();
    final resolver = RecordingResourceResolver((resource) {
      if (resource.id == CanvasResourceId('throwing-resource')) {
        throw StateError('app resolver failed');
      }

      return image;
    });
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: CountingResolverMutationGuard(),
    );
    final throwingRequest = descriptorRequest(
      id: 'throwing-resource',
      placeholderBounds: const Rect.fromLTWH(10, 20, 30, 40),
    );

    _expectResolverExceptionPlaceholder(
      session.resolveResource(throwingRequest),
      throwingRequest.placeholderBounds,
    );
    expect(
      resolvedImage(session.resolveResource(descriptorRequest(id: 'healthy'))),
      same(image),
    );
    expect(resolver.callCount, 2);

    image.dispose();
  });
}

void _testOrdinaryNonStateErrorBecomesBoundedPlaceholder() {
  test('ordinary non-StateError resolver exception returns placeholder', () {
    final resolver = RecordingResourceResolver((_) {
      throw const FormatException('bad image key');
    });
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: CountingResolverMutationGuard(),
    );
    final request = descriptorRequest(id: 'format-error');

    _expectResolverExceptionPlaceholder(
      session.resolveResource(request),
      request.placeholderBounds,
    );
    expect(resolver.callCount, 1);
  });
}

void _testResolverGuardRejectionsBubble() {
  test('runtime guard rejections are not converted to placeholders', () async {
    final image = await createResourceTestImage();
    final nestedRoot = _runtime();
    final mutationRoot = _runtime();
    final nestedSession = SurfaceResourceSession(
      resolver: RecordingResourceResolver(
        (_) => nestedRoot.runResolverCallback(() => image),
      ),
      mutationGuard: nestedRoot,
    );
    final mutationSession = SurfaceResourceSession(
      resolver: RecordingResourceResolver((_) {
        mutationRoot.generateElementId();

        return image;
      }),
      mutationGuard: mutationRoot,
    );

    expect(
      () => nestedSession.resolveResource(descriptorRequest(id: 'resource-a')),
      throwsStateError,
    );
    expect(
      () =>
          mutationSession.resolveResource(descriptorRequest(id: 'resource-a')),
      throwsStateError,
    );
    expect(mutationRoot.generateElementId(), CanvasElementId('e0'));

    image.dispose();
    nestedRoot.dispose();
    mutationRoot.dispose();
  });
}

void _testResolverExceptionsAreRetried() {
  test('resolver exception placeholders are not cached across frames', () {
    var throwingCalls = 0;
    final resolver = RecordingResourceResolver((_) {
      throwingCalls += 1;
      throw StateError('still unavailable');
    });
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: CountingResolverMutationGuard(),
    );
    final request = descriptorRequest(id: 'retry-resource');

    expect(
      session.resolveResource(request),
      isA<ResolverExceptionResourceAssetPlaceholder>(),
    );
    session.beginFrameResourcePass();
    expect(
      session.resolveResource(request),
      isA<ResolverExceptionResourceAssetPlaceholder>(),
    );
    expect(throwingCalls, 2);
    expect(resolver.callCount, 2);
  });
}

void _testResolverExceptionsDoNotEnterNullSuppression() {
  test('resolver exceptions do not create null-result suppression', () {
    var attempts = 0;
    final resolver = RecordingResourceResolver((_) {
      attempts += 1;
      if (attempts == 1) {
        throw StateError('temporary failure');
      }

      return null;
    });
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: CountingResolverMutationGuard(),
    );
    final request = descriptorRequest(id: 'null-after-exception');

    expect(
      session.resolveResource(request),
      isA<ResolverExceptionResourceAssetPlaceholder>(),
    );
    expect(
      session.resolveResource(request),
      isA<NullResourceAssetPlaceholder>(),
    );
    expect(
      session.resolveResource(request),
      isA<NullResourceAssetPlaceholder>(),
    );
    expect(resolver.callCount, 2);
  });
}

void _testResolverExceptionsConsumeBudget() {
  test('resolver exception attempts count toward frame budget', () {
    final resolver = RecordingResourceResolver((_) {
      throw StateError('budgeted failure');
    });
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: CountingResolverMutationGuard(),
    );

    for (var index = 0; index < 128; index += 1) {
      expect(
        session.resolveResource(descriptorRequest(id: 'throwing-$index')),
        isA<ResolverExceptionResourceAssetPlaceholder>(),
      );
    }
    expect(
      session.resolveResource(descriptorRequest(id: 'over-budget')),
      isA<BudgetExceededResourceAssetPlaceholder>(),
    );
    expect(resolver.callCount, 128);
  });
}

void _expectResolverExceptionPlaceholder(
  ResourceAssetResolveResult result,
  Rect placeholderBounds,
) {
  final placeholder = result as ResolverExceptionResourceAssetPlaceholder;

  expect(placeholder.placeholderBounds, placeholderBounds);
}

RuntimeRoot _runtime() {
  return runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(
      resources: [
        CanvasImageResource(
          id: CanvasResourceId('resource-a'),
          source: CanvasResourceSource.appKey('asset-a'),
        ),
      ],
    ),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
  );
}

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;
