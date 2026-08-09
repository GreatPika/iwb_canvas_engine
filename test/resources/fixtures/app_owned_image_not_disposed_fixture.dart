import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/resources/resource_cache.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import 'surface_resource_session_test_support.dart';

void main() {
  _testAppOwnedImagesStayAlive();
  _testByteEvictionLeavesAppOwnedImagesAlive();
  _testByteInvalidationLeavesAppOwnedImagesAlive();
  _testByteResetLeavesAppOwnedImagesAlive();
  _testByteDropLeavesAppOwnedImagesAlive();
  _testByteDisposeLeavesAppOwnedImagesAlive();
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

    session.releaseResource(CanvasResourceId('resource-1024'));
    expect(image.debugDisposed, isFalse);

    session.releaseAllResources();
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

void _testByteEvictionLeavesAppOwnedImagesAlive() {
  test('byte eviction never disposes app-owned images', () async {
    final fixture = await _ByteNoDisposeFixture.create();

    fixture.resolve('first');
    expect(fixture.resolver.callCount, 1);
    fixture.resolve('second');
    expect(fixture.resolver.callCount, 2);
    fixture.resolve('first');
    expect(fixture.resolver.callCount, 3);
    expect(fixture.disposedStates, everyElement(isFalse));

    fixture.disposeImages();
  });
}

void _testByteInvalidationLeavesAppOwnedImagesAlive() {
  test('byte cache invalidation never disposes app-owned images', () async {
    final fixture = await _ByteNoDisposeFixture.create();

    fixture.resolve('second');
    fixture.session.releaseResource(CanvasResourceId('second'));
    expect(fixture.disposedStates, everyElement(isFalse));

    fixture.resolve('second');
    fixture.session.releaseAllResources();
    expect(fixture.disposedStates, everyElement(isFalse));

    fixture.resolve('first');
    fixture.session.replaceResolver(null);
    expect(fixture.disposedStates, everyElement(isFalse));

    fixture.disposeImages();
  });
}

void _testByteResetLeavesAppOwnedImagesAlive() {
  test('byte cache reset leaves app-owned images alive', () async {
    final fixture = await _ByteNoDisposeFixture.create();

    fixture.resolve('first');
    fixture.session.resetForDocumentReplacement();
    expect(fixture.disposedStates, everyElement(isFalse));

    fixture.disposeImages();
  });
}

void _testByteDropLeavesAppOwnedImagesAlive() {
  test('byte cache drop leaves app-owned images alive', () async {
    final fixture = await _ByteNoDisposeFixture.create();

    fixture.resolve('first');
    fixture.session.drop();
    expect(fixture.disposedStates, everyElement(isFalse));

    fixture.disposeImages();
  });
}

void _testByteDisposeLeavesAppOwnedImagesAlive() {
  test('byte cache dispose leaves app-owned images alive', () async {
    final fixture = await _ByteNoDisposeFixture.create();

    fixture.resolve('first');
    fixture.session.dispose();
    expect(fixture.disposedStates, everyElement(isFalse));

    fixture.disposeImages();
  });
}

final class _ByteNoDisposeFixture {
  _ByteNoDisposeFixture({
    required this.first,
    required this.second,
    required this.resolver,
    required this.session,
  });

  final ui.Image first;
  final ui.Image second;
  final RecordingResourceResolver resolver;
  final SurfaceResourceSession session;

  List<bool> get disposedStates => [first.debugDisposed, second.debugDisposed];

  static Future<_ByteNoDisposeFixture> create() async {
    final first = await createSizedResourceTestImage(width: 2, height: 2);
    final second = await createSizedResourceTestImage(width: 2, height: 2);
    final images = <String, ui.Image>{'first': first, 'second': second};
    final resolver = RecordingResourceResolver((resource) {
      return images[resource.id.value];
    });

    return _ByteNoDisposeFixture(
      first: first,
      second: second,
      resolver: resolver,
      session: SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: CountingResolverMutationGuard(),
        cache: ImageResolveCache(maximumSizeBytes: 16),
      ),
    );
  }

  void resolve(String id) {
    session.resolveImage(descriptorRequest(id: id));
  }

  void disposeImages() {
    first.dispose();
    second.dispose();
  }
}
