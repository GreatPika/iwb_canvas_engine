import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import 'surface_resource_session_test_support.dart';

void main() {
  _testResolverReplacementStartsFresh();
}

// Resolver replacement must prove cache and suppression reset together, so the
// assertions stay in one chronological lifecycle test.
// ignore: halstead-volume, source-lines-of-code
void _testResolverReplacementStartsFresh() {
  test(
    'resolver replacement clears cache and same-frame suppression',
    () async {
      final firstImage = await createResourceTestImage(0xff00aa00);
      final secondImage = await createResourceTestImage(0xff0000aa);
      final guard = CountingResolverMutationGuard();
      final firstResolver = RecordingResourceResolver((_) => firstImage);
      final secondResolver = RecordingResourceResolver((_) => secondImage);
      final session = SurfaceResourceSession(
        resolver: firstResolver,
        mutationGuard: guard,
      );
      final request = descriptorRequest(id: 'resource-a');

      expect(
        identical(resolvedImage(session.resolveResource(request)), firstImage),
        isTrue,
      );
      expect(
        identical(resolvedImage(session.resolveResource(request)), firstImage),
        isTrue,
      );
      expect(firstResolver.callCount, 1);

      session.replaceResolver(secondResolver);
      expect(
        identical(resolvedImage(session.resolveResource(request)), secondImage),
        isTrue,
      );
      expect(secondResolver.callCount, 1);

      final nullResolver = RecordingResourceResolver((_) => null);
      session.replaceResolver(nullResolver);
      expect(
        session.resolveResource(request),
        isA<NullResourceAssetPlaceholder>(),
      );
      expect(
        session.resolveResource(request),
        isA<NullResourceAssetPlaceholder>(),
      );
      expect(nullResolver.callCount, 1);

      session.replaceResolver(firstResolver);
      expect(
        identical(resolvedImage(session.resolveResource(request)), firstImage),
        isTrue,
      );
      expect(firstResolver.callCount, 2);

      firstImage.dispose();
      secondImage.dispose();
    },
  );
}
