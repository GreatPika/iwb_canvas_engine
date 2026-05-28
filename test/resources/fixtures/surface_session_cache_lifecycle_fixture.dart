import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import 'surface_resource_session_test_support.dart';

void main() {
  _testTargetAndAllInvalidation();
  _testLeastRecentlyUsedEviction();
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
