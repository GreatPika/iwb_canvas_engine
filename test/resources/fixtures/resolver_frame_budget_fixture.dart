import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import 'surface_resource_session_test_support.dart';

void main() {
  _testResolverFrameBudget();
}

// The budget proof keeps cache hits, missing descriptors, exhaustion, and retry
// in one ordered frame sequence so call accounting stays auditable.
// ignore: halstead-volume, source-lines-of-code
void _testResolverFrameBudget() {
  test(
    'resolver calls are capped per frame and retried on the next pass',
    () async {
      final image = await createResourceTestImage();
      final resolver = RecordingResourceResolver((_) => image);
      final session = SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: CountingResolverMutationGuard(),
      );

      session.resolveResource(descriptorRequest(id: 'cached'));
      session.beginFrameResourcePass();
      session.resolveResource(descriptorRequest(id: 'cached'));
      for (var index = 0; index < 16; index += 1) {
        session.resolveResource(missingRequest(id: 'missing-$index'));
      }
      expect(resolver.callCount, 1);

      for (var index = 0; index < 128; index += 1) {
        expect(
          session.resolveResource(descriptorRequest(id: 'resource-$index')),
          isA<ResolvedResourceAsset>(),
        );
      }
      expect(resolver.callCount, 129);

      final throttledRequest = descriptorRequest(id: 'resource-128');
      expect(
        session.resolveResource(throttledRequest),
        isA<BudgetExceededResourceAssetPlaceholder>(),
      );
      expect(
        session.resolveResource(throttledRequest),
        isA<BudgetExceededResourceAssetPlaceholder>(),
      );
      expect(resolver.callCount, 129);
      expect(session.hasPendingBudgetFollowUpRepaint, isTrue);

      session.beginFrameResourcePass();
      expect(session.hasPendingBudgetFollowUpRepaint, isFalse);
      expect(
        session.resolveResource(throttledRequest),
        isA<ResolvedResourceAsset>(),
      );
      expect(resolver.callCount, 130);

      image.dispose();
    },
  );
}
