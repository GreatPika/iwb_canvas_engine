import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/pointer_input.dart';
import 'package:iwb_canvas_engine/src/view/scene_view_pointer_router.dart';

void main() {
  test(
    'SceneViewPointerRouter distinguishes down, known, and stray routing',
    () {
      final router = SceneViewPointerRouter();

      final strayMove = router.route(rawPointer: 91, phase: PointerPhase.move);
      expect(strayMove.isStray, isTrue);

      final down = router.route(rawPointer: 91, phase: PointerPhase.down);
      expect(down.kind, SceneViewPointerRouteKind.routedDown);
      expect(down.pointerId, 1);
      expect(router.liveRawPointerCount, 1);

      final knownMove = router.route(rawPointer: 91, phase: PointerPhase.move);
      expect(knownMove.kind, SceneViewPointerRouteKind.routedKnown);
      expect(knownMove.pointerId, 1);
    },
  );

  test('SceneViewPointerRouter reuses the minimum free slot id', () {
    // INV:INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE
    final router = SceneViewPointerRouter();

    expect(router.route(rawPointer: 10, phase: PointerPhase.down).pointerId, 1);
    expect(router.route(rawPointer: 11, phase: PointerPhase.down).pointerId, 2);
    expect(router.route(rawPointer: 12, phase: PointerPhase.down).pointerId, 3);
    expect(router.liveRawPointerCount, 3);

    router.release(12);
    router.release(10);
    expect(router.liveRawPointerCount, 1);

    final reused = router.route(rawPointer: 13, phase: PointerPhase.down);
    expect(reused.pointerId, 1);

    final released = router.release(13);
    expect(released.didRelease, isTrue);
    expect(const SceneViewPointerReleaseResult.noop().didRelease, isFalse);
  });

  test('SceneViewPointerRouter blocks signal tracking until idle', () {
    // INV:INV-ENG-VIEW-ACTIVE-POINTER-GATE
    final router = SceneViewPointerRouter();

    final first = router.route(rawPointer: 21, phase: PointerPhase.down);
    final second = router.route(rawPointer: 22, phase: PointerPhase.down);
    final firstPointerId =
        first.pointerId ??
        (throw StateError('Expected routed pointer id for first down event.'));
    final secondPointerId =
        second.pointerId ??
        (throw StateError('Expected routed pointer id for second down event.'));
    expect(
      router.shouldTrackSignals(
        pointerId: firstPointerId,
        phase: PointerPhase.down,
      ),
      isTrue,
    );
    expect(
      router.shouldTrackSignals(
        pointerId: secondPointerId,
        phase: PointerPhase.down,
      ),
      isFalse,
    );

    final firstRelease = router.release(21);
    expect(firstRelease.releasedTrackedPointer, isTrue);
    expect(firstRelease.isIdleAfterRelease, isFalse);

    expect(
      router.shouldTrackSignals(
        pointerId: secondPointerId,
        phase: PointerPhase.move,
      ),
      isFalse,
    );

    final third = router.route(rawPointer: 23, phase: PointerPhase.down);
    final thirdPointerId =
        third.pointerId ??
        (throw StateError('Expected routed pointer id for third down event.'));
    expect(
      router.shouldTrackSignals(
        pointerId: thirdPointerId,
        phase: PointerPhase.down,
      ),
      isFalse,
    );

    final secondRelease = router.release(22);
    expect(secondRelease.isIdleAfterRelease, isFalse);
    expect(router.hasLiveRawPointers, isTrue);

    final thirdRelease = router.release(23);
    expect(thirdRelease.isIdleAfterRelease, isTrue);
    expect(router.isIdle, isTrue);

    final fourth = router.route(rawPointer: 24, phase: PointerPhase.down);
    final fourthPointerId =
        fourth.pointerId ??
        (throw StateError('Expected routed pointer id for fourth down event.'));
    expect(
      router.shouldTrackSignals(
        pointerId: fourthPointerId,
        phase: PointerPhase.down,
      ),
      isTrue,
    );
  });

  test(
    'SceneViewPointerRouter keeps raw pointer ownership stable across slot reuse',
    () {
      final router = SceneViewPointerRouter();

      final first = router.route(rawPointer: 1001, phase: PointerPhase.down);
      final second = router.route(rawPointer: 2002, phase: PointerPhase.down);
      expect(first.pointerId, 1);
      expect(second.pointerId, 2);

      final firstRelease = router.release(1001);
      expect(firstRelease.pointerId, 1);
      expect(firstRelease.isIdleAfterRelease, isFalse);

      final stillKnown = router.route(
        rawPointer: 2002,
        phase: PointerPhase.move,
      );
      expect(stillKnown.kind, SceneViewPointerRouteKind.routedKnown);
      expect(stillKnown.pointerId, 2);

      final reused = router.route(rawPointer: 3003, phase: PointerPhase.down);
      expect(reused.pointerId, 1);
      expect(router.liveRawPointerCount, 2);

      final secondStillKnown = router.route(
        rawPointer: 2002,
        phase: PointerPhase.up,
      );
      expect(secondStillKnown.kind, SceneViewPointerRouteKind.routedKnown);
      expect(secondStillKnown.pointerId, 2);
    },
  );
}
