import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import 'surface_resource_session_test_support.dart';

void main() {
  _testFrameScopedNullSuppressionAndPlaceholders();
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
