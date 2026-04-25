import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/core/node_geometry.dart';
import 'package:iwb_canvas_engine/src/core/snapshot_paint_admission_bounds.dart';

// INV:INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reuses unchanged text and path base paint bounds', () {
    final cache = SnapshotPaintAdmissionBoundsCache();
    final text = TextNodeSnapshot(
      id: 'cached-text',
      text: 'cached admission',
      fontSize: 18,
      color: const Color(0xFF000000),
      textDirection: TextDirection.ltr,
      maxWidth: 120,
      transform: Transform2D.translation(const Offset(40, 20)),
    );
    final path = PathNodeSnapshot(
      id: 'cached-path',
      svgPathData: 'M0 0 H40 V20 H0 Z',
      fillColor: const Color(0xFF000000),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 2,
      transform: Transform2D.translation(const Offset(20, 30)),
    );

    expect(
      cache.resolveBasePaintBounds(text),
      nodeSnapshotPaintBoundsWorld(text),
    );
    expect(
      cache.resolveBasePaintBounds(path),
      nodeSnapshotPaintBoundsWorld(path),
    );
    expect(cache.debugBuildCount, 2);
    expect(cache.debugHitCount, 0);

    expect(
      cache.resolveBasePaintBounds(text),
      nodeSnapshotPaintBoundsWorld(text),
    );
    expect(
      cache.resolveBasePaintBounds(path),
      nodeSnapshotPaintBoundsWorld(path),
    );
    expect(cache.debugBuildCount, 2);
    expect(cache.debugHitCount, 2);
  });

  test(
    'invalidates when geometry payload changes with the same id and revision',
    () {
      final cache = SnapshotPaintAdmissionBoundsCache();
      final first = TextNodeSnapshot(
        id: 'text-same-instance',
        instanceRevision: 7,
        text: 'short',
        fontSize: 18,
        color: const Color(0xFF000000),
        textDirection: TextDirection.ltr,
        maxWidth: 120,
      );
      final second = TextNodeSnapshot(
        id: 'text-same-instance',
        instanceRevision: 7,
        text: 'a much longer text payload',
        fontSize: 18,
        color: const Color(0xFF000000),
        textDirection: TextDirection.ltr,
        maxWidth: 120,
      );

      final firstBounds = cache.resolveBasePaintBounds(first);
      final secondBounds = cache.resolveBasePaintBounds(second);

      expect(firstBounds, isNot(secondBounds));
      expect(cache.debugBuildCount, 2);
      expect(cache.debugHitCount, 0);
    },
  );

  test('bounds cache is bounded and reports evictions', () {
    final cache = SnapshotPaintAdmissionBoundsCache(maxEntries: 1);

    cache.resolveBasePaintBounds(
      RectNodeSnapshot(
        id: 'first',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      ),
    );
    cache.resolveBasePaintBounds(
      RectNodeSnapshot(
        id: 'second',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      ),
    );

    expect(cache.debugSize, 1);
    expect(cache.debugBuildCount, 2);
    expect(cache.debugEvictCount, 1);
    expect(cache.captureProbe(), (buildCount: 2, hitCount: 0, evictCount: 1));
    cache.clear();
    expect(cache.debugSize, 0);
  });

  test('rejects invalid cache size and unsupported snapshot subtypes', () {
    expect(
      () => SnapshotPaintAdmissionBoundsCache(maxEntries: 0),
      throwsArgumentError,
    );
    const unsupported = _UnsupportedNodeSnapshot(id: 'unsupported');

    expect(
      () => requireSnapshotPaintAdmissionBoundsSupport(unsupported),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Unsupported NodeSnapshot subtype at admission'),
        ),
      ),
    );
    expect(
      () => buildSnapshotPaintAdmissionBoundsValidityKey(unsupported),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Unsupported NodeSnapshot subtype at admission'),
        ),
      ),
    );
  });
}

class _UnsupportedNodeSnapshot extends NodeSnapshot {
  const _UnsupportedNodeSnapshot({required super.id})
    : super(
        instanceRevision: 0,
        transform: Transform2D.identity,
        opacity: 1,
        hitPadding: 0,
        isVisible: true,
        isSelectable: true,
        isLocked: false,
        isDeletable: true,
        isTransformable: true,
      );
}
