import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import 'surface_resource_session_test_support.dart';

void main() {
  _testAppOwnedImagesStayAlive();
}

// Keeping each lifecycle operation in one test makes the no-dispose invariant
// observable across eviction, invalidation, resolver replacement, drop, and dispose.
// ignore: halstead-volume
void _testAppOwnedImagesStayAlive() {
  test('surface session never disposes app-owned images', () async {
    final image = await createResourceTestImage();
    final guard = CountingResolverMutationGuard();
    final resolver = RecordingResourceResolver((_) => image);
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: guard,
    );

    for (var index = 0; index < 1025; index += 1) {
      if (index % 128 == 0) {
        session.beginFrameResourcePass();
      }
      session.resolveImage(descriptorRequest(id: 'resource-$index'));
    }
    expect(image.debugDisposed, isFalse);

    session.invalidateResourceImage(CanvasResourceId('resource-1024'));
    expect(image.debugDisposed, isFalse);

    session.invalidateAllResourceImages();
    expect(image.debugDisposed, isFalse);

    session.resolveImage(descriptorRequest(id: 'resource-a'));
    session.replaceResolver(null);
    expect(image.debugDisposed, isFalse);

    session.drop();
    expect(image.debugDisposed, isFalse);

    session.dispose();
    expect(image.debugDisposed, isFalse);

    image.dispose();
  });
}
