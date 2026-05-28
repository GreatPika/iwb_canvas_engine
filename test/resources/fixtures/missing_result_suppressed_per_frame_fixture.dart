import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import 'surface_resource_session_test_support.dart';

void main() {
  _testFrameScopedPlaceholderSuppression();
}

// The frame-scoped suppression proof is clearest as one ordered scenario that
// compares null, missing, and absent-resolver outcomes against the same session.
// ignore: halstead-volume, source-lines-of-code
void _testFrameScopedPlaceholderSuppression() {
  test(
    'missing, null, and absent resolver placeholders are frame-scoped',
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
        session.resolveImage(request),
        isA<NullResourceImagePlaceholder>(),
      );
      expect(
        session.resolveImage(request),
        isA<NullResourceImagePlaceholder>(),
      );
      expect(nullResolver.callCount, 1);
      expect(guard.callbackCount, 1);

      session.beginFrameResourcePass();
      expect(
        session.resolveImage(request),
        isA<NullResourceImagePlaceholder>(),
      );
      expect(nullResolver.callCount, 2);

      final missing = missingRequest(id: 'missing');
      expect(
        session.resolveImage(missing),
        isA<MissingDescriptorResourceImagePlaceholder>(),
      );
      expect(
        session.resolveImage(missing).placeholderBounds,
        missing.placeholderBounds,
      );
      expect(nullResolver.callCount, 2);

      session.replaceResolver(null);
      expect(
        session.resolveImage(request),
        isA<NoResolverResourceImagePlaceholder>(),
      );
      expect(
        session.resolveImage(request),
        isA<NoResolverResourceImagePlaceholder>(),
      );
      expect(guard.callbackCount, 2);

      final imageResolver = RecordingResourceResolver((_) => image);
      session.replaceResolver(imageResolver);
      expect(session.resolveImage(request), isA<ResolvedResourceImage>());
      expect(imageResolver.callCount, 1);

      image.dispose();
    },
  );
}
